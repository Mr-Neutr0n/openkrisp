import XCTest
import Foundation
import AVFoundation
import CryptoKit
@testable import LabVoice

private func installedFixture(_ role: InstalledNCModelRole = .outbound) -> InstalledNCConfiguration {
    InstalledNCConfiguration(nodePath: "/fixture/node", workerPath: "/fixture/audio_worker.cjs", addonPath: "/fixture/addon",
        modelPath: "/fixture/model", adapterPath: "/fixture/adapter", libraryPath: "/fixture/libraries",
        nodeSHA256: InstalledNCConfiguration.reviewedNodeSHA256, adapterSHA256: String(repeating: "a", count: 64), modelRole: role)
}
final class InstalledNCResolverTests: XCTestCase {
    func testSyntheticResolverExactManifestAndIdentityGates() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Fixture.app"), runtime = root.appendingPathComponent("runtime"), node = root.appendingPathComponent("node")
        let library = app.appendingPathComponent("Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries")
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: node)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: node.path)
        let digest = String(repeating: "a", count: 64)
        let files = Dictionary(uniqueKeysWithValues: InstalledNCResolver.runtimeFiles.map { ($0, digest) })
        let manifest: [String: Any] = ["schemaVersion": 1, "nodeSha256": InstalledNCConfiguration.reviewedNodeSHA256, "files": files]
        let manifestURL = runtime.appendingPathComponent("runtime-manifest.json")
        try JSONSerialization.data(withJSONObject: manifest).write(to: manifestURL)
        let hash: @Sendable (URL) throws -> String = { url in
            XCTAssertFalse(Thread.isMainThread)
            if url.lastPathComponent == "node" { return InstalledNCConfiguration.reviewedNodeSHA256 }
            if url.lastPathComponent == "kr-media-sp.node" { return InstalledNCConfiguration.addonSHA256 }
            if url.pathExtension == "kef" { return InstalledNCConfiguration.modelSHA256 }
            return digest
        }
        let resolver = InstalledNCResolver()
        let admitted = try await resolver.resolve(app: app, node: node, runtime: runtime, hash: hash)
        XCTAssertEqual(admitted.adapterSHA256, digest)
        XCTAssertTrue(admitted.modelPath.hasSuffix("/c8.f.m.528d1f-1.0.1_1.0.kef"))
        XCTAssertEqual(admitted.libraryPath, library.path)
        let inbound = try await resolver.resolve(app: app, node: node, runtime: runtime, role: .inbound, hash: { url in
            if url.pathExtension == "kef" {
                XCTAssertEqual(url.lastPathComponent, "c8.w.m.d15e29_1.0.kef")
                return InstalledNCConfiguration.inboundModelSHA256
            }
            return try hash(url)
        })
        XCTAssertEqual(inbound.modelRole, .inbound)
        XCTAssertEqual(inbound.selectedModelSHA256, InstalledNCConfiguration.inboundModelSHA256)
        do {
            _ = try await resolver.resolve(app: app, node: node, runtime: runtime, role: .inbound, hash: hash)
            XCTFail("Accepted outbound digest for inbound model")
        } catch {}

        for target in ["node", "kr-media-sp.node", "c8.f.m.528d1f-1.0.1_1.0.kef", "native-probe.node", "worker_session.cjs"] {
            do {
                _ = try await resolver.resolve(app: app, node: node, runtime: runtime, hash: { url in
                    if url.lastPathComponent == target { return String(repeating: "f", count: 64) }
                    return try hash(url)
                })
                XCTFail("Accepted changed \(target)")
            } catch {}
        }
        var changed = manifest; changed["nodeSha256"] = digest
        try JSONSerialization.data(withJSONObject: changed).write(to: manifestURL)
        do { _ = try await resolver.resolve(app: app, node: node, runtime: runtime, hash: hash); XCTFail("Accepted another Node reference") } catch {}
        changed = manifest; changed["files"] = ["native-probe.node": digest]
        try JSONSerialization.data(withJSONObject: changed).write(to: manifestURL)
        do { _ = try await resolver.resolve(app: app, node: node, runtime: runtime, hash: hash); XCTFail("Accepted incomplete runtime") } catch {}
    }
    func testActualHashUsesRegularFilesAndRejectsSymlinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("file"), link = root.appendingPathComponent("link")
        let bytes = Data("synthetic fixture".utf8); try bytes.write(to: file)
        XCTAssertEqual(try InstalledNCResolver.hashFile(file), SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try InstalledNCResolver.hashFile(link))
        XCTAssertThrowsError(try InstalledNCResolver.hashFile(root))
        XCTAssertThrowsError(try InstalledNCResolver.hashFile(root.appendingPathComponent("missing")))
    }
}

@MainActor private final class InstalledProviderChild: AudioHelperChild {
    var running = false, arguments: [String] = [], terminations = 0
    var receive: ((String) -> Void)?, exited: ((HelperExit) -> Void)?
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        self.arguments = arguments; receive = line; exited = exit; running = true
    }
    func send(_ line: Data) throws {}
    func terminate() { terminations += 1; running = false; exited?(HelperExit(status: 0, output: Data(), diagnostic: "")) }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { true }
    func ack(_ mutate: (inout [String: Any]) -> Void = { _ in }) throws {
        let config = installedFixture()
        let operation = arguments[arguments.firstIndex(of: "--operation-id")! + 1]
        let microphone = arguments.contains("--microphone-noise-suppression"), speaker = arguments.contains("--speaker-noise-suppression")
        let micInstalled = arguments.contains("--microphone-provider"), speakerInstalled = arguments.contains("--speaker-provider")
        var value: [String: Any] = ["event": "route_started", "operationID": operation, "input_uid": "mic", "output_uid": "speaker",
            "microphone_noise": microphone, "speaker_noise": speaker,
            "microphone_provider": micInstalled ? "installed-krisp" : (microphone ? "rnnoise" : "none"),
            "speaker_provider": speakerInstalled ? "installed-krisp" : (speaker ? "rnnoise" : "none"),
            "microphone": ["muted": false, "gain": 1.0], "speaker": ["muted": false, "gain": 1.0]]
        for (enabled, prefix, role) in [(micInstalled, "provider_", InstalledNCModelRole.outbound), (speakerInstalled, "speaker_provider_", .inbound)] where enabled {
            value[prefix + "model_sha256"] = role.modelSHA256; value[prefix + "addon_sha256"] = InstalledNCConfiguration.addonSHA256
            value[prefix + "adapter_sha256"] = config.adapterSHA256; value[prefix + "node_sha256"] = config.nodeSHA256
            value[prefix + "delay_samples"] = 5760; value[prefix + "maximum_callback_frames"] = 4096
        }
        mutate(&value); receive?(String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self))
    }
}
@MainActor final class InstalledProviderRouteTests: XCTestCase {
    private func inventory() throws -> AudioInventory {
        try JSONDecoder().decode(AudioInventory.self, from: Data("""
        {"devices":[{"uid":"mic","name":"Mic","alive":1,"nominal_rate":48000,"input":{"channels":1},"output":{"channels":0}},{"uid":"speaker","name":"Speaker","alive":1,"nominal_rate":48000,"input":{"channels":0},"output":{"channels":2}}],"companion_devices":[{"uid":"dev.hari.labvoice.feed","present":true},{"uid":"dev.hari.labvoice.monitor","present":true}],"errors":[]}
        """.utf8))
    }
    private func wait(_ predicate: () -> Bool) async throws {
        for _ in 0..<1000 { if predicate() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Lifecycle did not progress")
    }
    private func model(_ child: InstalledProviderChild, microphone: NoiseProvider? = .installedKrisp, speaker: NoiseProvider? = .rnnoise) async throws -> AudioRouteController {
        let inventory = try inventory()
        let model = AudioRouteController(readInventory: { inventory }, authorization: { .authorized }, requestAuthorization: { XCTFail("Unexpected permission request"); return false }, factory: { child }, resolveInstalledProvider: { _, _, role in installedFixture(role) })
        await model.refresh(); model.inputUID = "mic"; model.outputUID = "speaker"
        model.microphoneNoise = microphone != nil; model.speakerNoise = speaker != nil
        model.microphoneProvider = microphone ?? .rnnoise; model.speakerProvider = speaker ?? .rnnoise
        return model
    }
    private func validate(_ model: AudioRouteController) async {
        model.selectInstalledApp(URL(fileURLWithPath: "/synthetic/Fixture.app")); model.selectInstalledNode(URL(fileURLWithPath: "/synthetic/node"))
        await model.validateInstalledProvider()
    }
    func testAdmissionSelectionAndExactArgumentsCapturedBeforeStart() async throws {
        let child = InstalledProviderChild(), model = try await model(child)
        XCTAssertFalse(model.canStart); model.start(); XCTAssertFalse(child.running)
        await validate(model); XCTAssertTrue(model.canStart); XCTAssertFalse(child.running)
        model.start(); try await wait { child.running }
        XCTAssertTrue(child.arguments.contains("--microphone-noise-suppression")); XCTAssertTrue(child.arguments.contains("--speaker-noise-suppression"))
        let start = child.arguments.firstIndex(of: "--microphone-provider")!
        XCTAssertEqual(Array(child.arguments[start..<(start + installedFixture().arguments.count)]), installedFixture().arguments)
        XCTAssertEqual(model.startupWait(for: AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: true, speakerNoise: true, installedProvider: installedFixture())), 40_000_000_000)
        model.microphoneProvider = .rnnoise // ACK must use the captured route, not mutable UI state.
        try child.ack(); XCTAssertEqual(model.phase, .running); XCTAssertEqual(model.activeOptions?.installedProvider, installedFixture())
        let stopped = await model.stop(); XCTAssertTrue(stopped)
    }
    func testMissingOrWrongIdentityAcknowledgmentsStopRoute() async throws {
        for key in ["microphone_provider", "speaker_provider", "provider_model_sha256", "provider_addon_sha256", "provider_adapter_sha256", "provider_node_sha256", "provider_delay_samples", "provider_maximum_callback_frames"] {
            for missing in [true, false] {
                let child = InstalledProviderChild(), model = try await model(child); await validate(model)
                model.start(); try await wait { child.running }
                try child.ack { if missing { $0.removeValue(forKey: key) } else { $0[key] = key.contains("samples") || key.contains("frames") ? 1 : "wrong" } }
                try await wait { child.terminations == 1 }; XCTAssertNil(model.activeOptions); XCTAssertEqual(model.phase, .idle)
            }
        }
    }
    func testSpeakerOnlyAndDualInstalledCaptureIndependentIdentities() async throws {
        for microphone in [NoiseProvider.rnnoise, .installedKrisp] {
            let child = InstalledProviderChild(), model = try await model(child, microphone: microphone, speaker: .installedKrisp)
            XCTAssertFalse(model.canStart); await validate(model); XCTAssertTrue(model.canStart)
            XCTAssertEqual(model.installedSpeakerConfiguration?.modelRole, .inbound)
            XCTAssertEqual(model.installedConfiguration?.modelRole, microphone == .installedKrisp ? .outbound : nil)
            model.start(); try await wait { child.running }
            let start = child.arguments.firstIndex(of: "--speaker-provider")!
            XCTAssertEqual(Array(child.arguments[start..<(start + installedFixture(.inbound).arguments(speaker: true).count)]), installedFixture(.inbound).arguments(speaker: true))
            XCTAssertEqual(child.arguments.contains("--microphone-provider"), microphone == .installedKrisp)
            try child.ack(); XCTAssertEqual(model.phase, .running)
            XCTAssertEqual(model.activeOptions?.installedSpeakerProvider?.modelRole, .inbound)
            XCTAssertEqual(model.startupWait(for: model.activeOptions!), microphone == .installedKrisp ? 70_000_000_000 : 40_000_000_000)
            _ = await model.stop()
        }
    }
    func testSpeakerMissingOrWrongLaneAcknowledgmentsStopWithoutFallback() async throws {
        for key in ["speaker_provider", "speaker_provider_model_sha256", "speaker_provider_addon_sha256", "speaker_provider_adapter_sha256", "speaker_provider_node_sha256", "speaker_provider_delay_samples", "speaker_provider_maximum_callback_frames"] {
            for missing in [true, false] {
                let child = InstalledProviderChild(), model = try await model(child, speaker: .installedKrisp); await validate(model)
                model.start(); try await wait { child.running }
                try child.ack { if missing { $0.removeValue(forKey: key) } else { $0[key] = key.contains("samples") || key.contains("frames") ? 1 : "wrong" } }
                try await wait { child.terminations == 1 }; XCTAssertNil(model.activeOptions)
            }
        }
        let child = InstalledProviderChild(), model = try await model(child, speaker: .installedKrisp); await validate(model)
        model.start(); try await wait { child.running }
        try child.ack { $0["speaker_provider_model_sha256"] = InstalledNCConfiguration.modelSHA256 }
        try await wait { child.terminations == 1 }; XCTAssertNil(model.activeOptions)
    }
    func testInactiveLaneCannotAcknowledgeInstalledMetadataOrWrongRole() async throws {
        let child = InstalledProviderChild(), model = try await model(child, microphone: .rnnoise, speaker: .installedKrisp)
        await validate(model); model.start(); try await wait { child.running }
        try child.ack { $0["provider_model_sha256"] = InstalledNCConfiguration.modelSHA256 }
        try await wait { child.terminations == 1 }; XCTAssertNil(model.activeOptions)
        XCTAssertFalse(AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: true, speakerNoise: true,
                                         installedProvider: installedFixture(.inbound)).validProviderRoles)
        XCTAssertFalse(AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: true, speakerNoise: true,
                                         installedSpeakerProvider: installedFixture(.outbound)).validProviderRoles)
    }
    func testDualValidationFailureDoesNotPublishPartialAdmission() async throws {
        let snapshot = try inventory(); var requested: [InstalledNCModelRole] = []
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { InstalledProviderChild() }, resolveInstalledProvider: { _, _, role in
            requested.append(role)
            if role == .inbound { throw InstalledNCError.invalid("inbound fixture failure") }
            return installedFixture(role)
        })
        await model.refresh(); model.inputUID = "mic"; model.outputUID = "speaker"
        model.microphoneNoise = true; model.speakerNoise = true; model.microphoneProvider = .installedKrisp; model.speakerProvider = .installedKrisp
        await validate(model); XCTAssertEqual(requested, [.outbound, .inbound])
        XCTAssertNil(model.installedConfiguration); XCTAssertNil(model.installedSpeakerConfiguration); XCTAssertFalse(model.canStart)
    }
    func testRequestedRoleChangeRejectsStaleCompletionAndWrongRoleAdmission() async throws {
        let snapshot = try inventory(); var resume: CheckedContinuation<InstalledNCConfiguration, Never>?
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { InstalledProviderChild() }, resolveInstalledProvider: { _, _, role in
            XCTAssertEqual(role, .inbound)
            return await withCheckedContinuation { resume = $0 }
        })
        model.speakerNoise = true; model.speakerProvider = .installedKrisp
        model.selectInstalledApp(URL(fileURLWithPath: "/synthetic/App.app")); model.selectInstalledNode(URL(fileURLWithPath: "/synthetic/node"))
        let validation = Task { await model.validateInstalledProvider() }; try await wait { resume != nil }
        model.speakerProvider = .rnnoise; resume?.resume(returning: installedFixture(.inbound)); await validation.value
        XCTAssertNil(model.installedSpeakerConfiguration); XCTAssertFalse(model.providerValidating)
        let wrong = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { InstalledProviderChild() }, resolveInstalledProvider: { _, _, _ in installedFixture(.outbound) })
        wrong.speakerNoise = true; wrong.speakerProvider = .installedKrisp; await validate(wrong)
        XCTAssertNil(wrong.installedSpeakerConfiguration); XCTAssertTrue(wrong.providerStatus.contains("role"))
    }
    func testStaleValidationCannotAdmitChangedSelection() async throws {
        let snapshot = try inventory(); var resume: CheckedContinuation<InstalledNCConfiguration, Never>?
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { InstalledProviderChild() }, resolveInstalledProvider: { _, _, _ in
            await withCheckedContinuation { resume = $0 }
        })
        model.selectInstalledApp(URL(fileURLWithPath: "/synthetic/Fixture.app")); model.selectInstalledNode(URL(fileURLWithPath: "/synthetic/node"))
        model.microphoneNoise = true; model.microphoneProvider = .installedKrisp
        let validation = Task { await model.validateInstalledProvider() }
        try await wait { resume != nil }
        model.selectInstalledNode(URL(fileURLWithPath: "/replacement/node"))
        resume?.resume(returning: installedFixture()); await validation.value
        XCTAssertNil(model.installedConfiguration); XCTAssertFalse(model.providerValidating)
    }
    func testInstalledPermissionCancellationAndLateReadyNeverEnableRoute() async throws {
        let snapshot = try inventory(); let child = InstalledProviderChild()
        var permission: CheckedContinuation<Bool, Never>?, launches = 0
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .notDetermined }, requestAuthorization: {
            await withCheckedContinuation { permission = $0 }
        }, factory: { launches += 1; return child }, resolveInstalledProvider: { _, _, _ in installedFixture() })
        await model.refresh(); model.inputUID = "mic"; model.outputUID = "speaker"
        model.microphoneNoise = true; model.speakerNoise = true; model.microphoneProvider = .installedKrisp
        await validate(model); model.start(); try await wait { permission != nil }
        _ = await model.stop(); permission?.resume(returning: true)
        try await Task.sleep(nanoseconds: 1_000_000); XCTAssertEqual(launches, 0); XCTAssertEqual(model.phase, .idle)
        let startingChild = InstalledProviderChild(), starting = try await self.model(startingChild)
        await validate(starting); starting.start(); try await wait { startingChild.running }
        _ = await starting.stop(); try startingChild.ack()
        XCTAssertNil(starting.activeOptions); XCTAssertEqual(starting.phase, .idle)
    }
    func testChoiceChangeInvalidatesAdmissionAndDisabledNoiseDoesNotLaunchProvider() async throws {
        let child = InstalledProviderChild(), model = try await model(child); await validate(model)
        model.selectInstalledNode(URL(fileURLWithPath: "/other/node")); XCTAssertNil(model.installedConfiguration); XCTAssertFalse(model.canStart)
        model.microphoneNoise = false; XCTAssertTrue(model.canStart)
        model.start(); try await wait { child.running }; XCTAssertFalse(child.arguments.contains("--microphone-provider"))
        _ = await model.stop()
    }
}
