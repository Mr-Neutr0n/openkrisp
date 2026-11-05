import XCTest
import AVFoundation
@testable import LabVoice

private func accentFixture() -> InstalledAccentConfiguration {
    .init(nodePath: "/fixture/node", workerPath: "/fixture/worker", addonPath: "/fixture/addon",
          modelPath: "/fixture/model", adapterPath: "/fixture/adapter", libraryPath: "/fixture/library",
          adapterSHA256: String(repeating: "a", count: 64))
}
final class AccentResolverTests: XCTestCase {
    func testExactModelRoleFilenameAndPackagedIdentity() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Fixture.app"), runtime = root.appendingPathComponent("runtime")
        let node = root.appendingPathComponent("node"), model = root.appendingPathComponent(InstalledAccentConfiguration.modelFilename)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: node)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: node.path)
        let digest = String(repeating: "a", count: 64)
        let manifest: [String: Any] = ["schemaVersion": 1, "nodeSha256": InstalledAccentConfiguration.nodeSHA256,
            "files": Dictionary(uniqueKeysWithValues: InstalledAccentResolver.runtimeFiles.map { ($0, digest) })]
        try JSONSerialization.data(withJSONObject: manifest).write(to: runtime.appendingPathComponent("runtime-manifest.json"))
        let hash: @Sendable (URL) throws -> String = { url in
            XCTAssertFalse(Thread.isMainThread)
            if url == node { return InstalledAccentConfiguration.nodeSHA256 }
            if url.lastPathComponent == "kr-media-sp.node" { return InstalledAccentConfiguration.addonSHA256 }
            if url == model { return InstalledAccentConfiguration.modelSHA256 }
            return digest
        }
        let resolver = InstalledAccentResolver()
        let admitted = try await resolver.resolve(app: app,node: node,model: model,runtime: runtime,hash: hash)
        XCTAssertEqual(admitted.modelPath,model.path); XCTAssertEqual(admitted.adapterSHA256,digest)
        XCTAssertEqual(admitted.selectedNodeSHA256,InstalledNodeRuntime.bundledSHA256)
        let retained = try await resolver.resolve(app: app,node: node,model: model,runtime: runtime,hash: { url in
            url == node ? InstalledNodeRuntime.homebrewSHA256 : try hash(url)
        })
        XCTAssertEqual(retained.selectedNodeSHA256,InstalledNodeRuntime.homebrewSHA256)
        do {
            _ = try await resolver.resolve(app: app,node: node,model: root.appendingPathComponent("renamed.kef"),runtime: runtime,hash: { _ in InstalledAccentConfiguration.modelSHA256 })
            XCTFail("Admitted a filename the worker will reject")
        } catch {}
        for changed in [model.lastPathComponent,"kr-media-sp.node","node","worker.cjs"] {
            do {
                _ = try await resolver.resolve(app: app,node: node,model: model,runtime: runtime,hash: { url in
                    if url.lastPathComponent == changed { return String(repeating: "f",count: 64) }
                    return try hash(url)
                })
                XCTFail("Admitted changed identity: \(changed)")
            } catch {}
        }
    }
}
final class AccentStartupTests: XCTestCase {
    private func acknowledgment() -> [String: Any] {
        ["event": "route_started", "input_uid": "mic", "output_uid": "speaker",
         "microphone_noise": false, "speaker_noise": false, "microphone_provider": "installed-accent", "speaker_provider": "none",
         "accent_direction": "outbound", "accent_target": "us", "accent_backend": "accent-direct",
         "accent_model_sha256": InstalledAccentConfiguration.modelSHA256,
         "accent_addon_sha256": InstalledAccentConfiguration.addonSHA256,
         "accent_node_sha256": InstalledAccentConfiguration.nodeSHA256,
         "accent_adapter_sha256": accentFixture().adapterSHA256,
         "accent_sample_rate": 48000, "accent_frame_samples": 480, "accent_scheduling_budget_frames": 2,
         "accent_maximum_callback_frames": 512, "accent_current_callback_frames": 512, "accent_transport_delay_samples": 2400, "accent_empty_policy": "silence-time-slot"]
    }
    func testSeparateExactAdmissionAndUnexpectedFields() throws {
        let options = AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: false, speakerNoise: false, installedAccent: accentFixture())
        func matches(_ value: [String: Any]) throws -> Bool {
            try JSONDecoder().decode(AudioStartup.self, from: JSONSerialization.data(withJSONObject: value)).matches(options)
        }
        XCTAssertTrue(try matches(acknowledgment()))
        var alternate = accentFixture(); alternate.selectedNodeSHA256 = InstalledNodeRuntime.homebrewSHA256
        let alternateOptions = AudioRouteOptions(inputUID: "mic",outputUID: "speaker",microphoneNoise: false,speakerNoise: false,installedAccent: alternate)
        XCTAssertFalse(try JSONDecoder().decode(AudioStartup.self,from: JSONSerialization.data(withJSONObject: acknowledgment())).matches(alternateOptions))
        var alternateAck = acknowledgment(); alternateAck["accent_node_sha256"] = alternate.selectedNodeSHA256
        XCTAssertTrue(try JSONDecoder().decode(AudioStartup.self,from: JSONSerialization.data(withJSONObject: alternateAck)).matches(alternateOptions))
        alternate.selectedNodeSHA256 = String(repeating: "a",count: 64)
        XCTAssertFalse(AudioRouteOptions(inputUID: "mic",outputUID: "speaker",microphoneNoise: false,speakerNoise: false,installedAccent: alternate).validProviderRoles)
        for (field, value) in [("accent_direction", "inbound"), ("accent_target", "uk"), ("accent_model_sha256", "wrong"),
                               ("accent_empty_policy", "drop"), ("accent_unexpected", "x"), ("provider_model_role", "outbound")] {
            var changed = acknowledgment(); changed[field] = value; XCTAssertFalse(try matches(changed))
        }
        for field in acknowledgment().keys where field.hasPrefix("accent_") {
            var changed = acknowledgment(); changed.removeValue(forKey: field); XCTAssertFalse(try matches(changed))
        }
        var changed = acknowledgment(); changed["accent_transport_delay_samples"] = 1920
        XCTAssertFalse(try matches(changed))
        var nc = options; nc.installedAccent = nil
        XCTAssertFalse(try JSONDecoder().decode(AudioStartup.self, from: JSONSerialization.data(withJSONObject: acknowledgment())).matches(nc))
        let invalid = AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: true, speakerNoise: false, installedAccent: accentFixture())
        XCTAssertFalse(invalid.validProviderRoles)
        XCTAssertFalse(options.arguments.contains("--microphone-provider"))
        XCTAssertTrue(options.arguments.contains("--accent-model"))
    }
}

@MainActor private final class AccentChild: AudioHelperChild {
    var running = false
    var launches = 0
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws { launches += 1; running = true }
    func send(_ line: Data) throws {}
    func terminate() { running = false }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { !running }
}
@MainActor final class AccentAdmissionTests: XCTestCase {
    private func inventory() throws -> AudioInventory {
        try JSONDecoder().decode(AudioInventory.self, from: Data("""
        {"devices":[{"uid":"mic","name":"Mic","alive":1,"nominal_rate":48000,"input":{"channels":1},"output":{"channels":0}},
        {"uid":"speaker","name":"Speaker","alive":1,"nominal_rate":48000,"input":{"channels":0},"output":{"channels":2}}],
        "companion_devices":[{"uid":"dev.hari.labvoice.feed","present":true},{"uid":"dev.hari.labvoice.monitor","present":true}],"errors":[]}
        """.utf8))
    }
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Expected accent state did not arrive")
    }
    func testStaleValidationAndPermissionCannotLaunchSupersededAccent() async throws {
        let snapshot = try inventory(), child = AccentChild()
        var resolve: CheckedContinuation<InstalledAccentConfiguration, Never>?
        var permission: CheckedContinuation<Bool, Never>?
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .notDetermined },
            requestAuthorization: { await withCheckedContinuation { permission = $0 } }, factory: { child },
            resolveInstalledAccent: { _,_,_ in await withCheckedContinuation { resolve = $0 } })
        await model.refresh(); model.inputUID = "mic"; model.outputUID = "speaker"
        model.selectInstalledApp(URL(fileURLWithPath: "/fixture/app")); model.selectInstalledNode(URL(fileURLWithPath: "/fixture/node"))
        XCTAssertFalse(model.accentConversion)
        model.accentConversion = true; model.selectAccentModel(URL(fileURLWithPath: "/fixture/model"))
        let first = Task { await model.validateInstalledAccent() }; try await wait { resolve != nil }
        model.selectAccentModel(URL(fileURLWithPath: "/fixture/replaced")); resolve?.resume(returning: accentFixture()); await first.value
        XCTAssertNil(model.installedAccentConfiguration); XCTAssertFalse(model.canStart)
        resolve = nil
        let second = Task { await model.validateInstalledAccent() }; try await wait { resolve != nil }
        resolve?.resume(returning: accentFixture()); await second.value; XCTAssertTrue(model.canStart)
        model.microphoneNoise = true; XCTAssertFalse(model.canStart); model.microphoneNoise = false
        model.start(); try await wait { permission != nil }
        model.accentConversion = false; permission?.resume(returning: true)
        try await wait { model.phase == .idle }; XCTAssertEqual(child.launches, 0)
    }
}
