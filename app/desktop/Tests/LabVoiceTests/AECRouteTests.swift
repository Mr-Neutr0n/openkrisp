import XCTest
import AVFoundation
@testable import LabVoice

@MainActor private final class AECChild: AudioHelperChild {
    var running = false
    var arguments: [String] = []
    var terminations = 0
    var lineHandler: ((String) -> Void)?
    var exitHandler: ((HelperExit) -> Void)?
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        self.arguments = arguments; lineHandler = line; exitHandler = exit; running = true
    }
    func send(_ line: Data) throws {}
    func terminate() { terminations += 1; running = false; exitHandler?(HelperExit(status: 0, output: Data(), diagnostic: "")) }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { !running }
    func ack(mutate: (inout [String: Any]) -> Void = { _ in }) throws {
        let operation = arguments[arguments.firstIndex(of: "--operation-id")! + 1]
        var value: [String: Any] = ["event": "route_started", "operationID": operation,
            "input_uid": "mic", "output_uid": "speaker", "microphone_noise": false, "speaker_noise": arguments.contains("--speaker-noise-suppression"),
            "microphone_provider": "installed-krisp-aec", "speaker_provider": arguments.contains("--speaker-noise-suppression") ? "rnnoise" : "none",
            "microphone": ["muted": false, "gain": 1], "speaker": ["muted": false, "gain": 1],
            "aec_provider": "installed-krisp", "aec_worker_sha256": String(repeating: "a", count: 64),
            "aec_library_sha256": InstalledAECConfiguration.librarySHA256, "aec_delay_samples": 5760,
            "aec_maximum_callback_frames": 4096, "aec_scheduling_budget_frames": 2,
            "aec_forward_rate": 48000, "aec_forward_channels": 1, "aec_reference_rate": 48000, "aec_reference_channels": 2]
        if arguments.contains("--microphone-noise-suppression") {
            let installed = arguments.contains("--microphone-provider")
            value["microphone_noise"] = true
            value["microphone_provider"] = installed ? "installed-krisp" : "rnnoise"
            value["microphone_processing_order"] = "aec-then-nc"
            value["microphone_nc_delay_samples"] = installed ? 5760 : 480
            value["microphone_total_delay_samples"] = installed ? 11520 : 6240
            if installed {
                value["provider_model_role"] = "outbound"
                value["provider_model_sha256"] = InstalledNCConfiguration.modelSHA256
                value["provider_addon_sha256"] = InstalledNCConfiguration.addonSHA256
                value["provider_node_sha256"] = InstalledNCConfiguration.reviewedNodeSHA256
                value["provider_adapter_sha256"] = String(repeating: "b", count: 64)
                value["provider_delay_samples"] = 5760
                value["provider_maximum_callback_frames"] = 4096
            }
        }
        if arguments.contains("--speaker-provider") {
            value["speaker_provider"] = "installed-krisp"
            value["speaker_provider_model_role"] = "inbound"
            value["speaker_provider_model_sha256"] = InstalledNCConfiguration.inboundModelSHA256
            value["speaker_provider_addon_sha256"] = InstalledNCConfiguration.addonSHA256
            value["speaker_provider_node_sha256"] = InstalledNCConfiguration.reviewedNodeSHA256
            value["speaker_provider_adapter_sha256"] = String(repeating: "b", count: 64)
            value["speaker_provider_delay_samples"] = 5760
            value["speaker_provider_maximum_callback_frames"] = 4096
        }
        mutate(&value)
        lineHandler?(String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self))
    }
}
@MainActor final class AECRouteTests: XCTestCase {
    private func configuration() -> InstalledAECConfiguration {
        InstalledAECConfiguration(workerPath: "/fixture/aec-worker", workerSHA256: String(repeating: "a", count: 64), libraryPath: "/fixture/libaec-sdk.dylib")
    }
    private func inventory() throws -> AudioInventory {
        try JSONDecoder().decode(AudioInventory.self, from: Data("""
        {"devices":[{"uid":"mic","name":"Mic","alive":1,"nominal_rate":48000,"input":{"channels":1},"output":{"channels":0}},
        {"uid":"speaker","name":"Speaker","alive":1,"nominal_rate":48000,"input":{"channels":0},"output":{"channels":2}}],
        "companion_devices":[{"uid":"dev.hari.labvoice.feed","present":true},{"uid":"dev.hari.labvoice.monitor","present":true}],"errors":[]}
        """.utf8))
    }
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Expected AEC state did not arrive")
    }
    private func model(_ child: AECChild) async throws -> AudioRouteController {
        let snapshot = try inventory(), config = configuration()
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { XCTFail("Unexpected permission"); return false }, factory: { child }, resolveInstalledAEC: { _ in config })
        await model.refresh(); model.inputUID = "mic"; model.outputUID = "speaker"
        model.selectInstalledApp(URL(fileURLWithPath: "/fixture/Krisp.app"))
        return model
    }
    func testExplicitValidationNoNodeAndDefaultOff() async throws {
        let child = AECChild(), model = try await model(child)
        XCTAssertFalse(model.echoCancellation); XCTAssertNil(model.installedAECConfiguration)
        model.echoCancellation = true; XCTAssertFalse(model.canStart)
        await model.validateInstalledAEC()
        XCTAssertNil(model.installedNode); XCTAssertTrue(model.canStart); XCTAssertFalse(child.running)
        model.speakerNoise = true; model.start(); try await wait { child.running }
        XCTAssertTrue(child.arguments.contains("--aec-provider")); XCTAssertFalse(child.arguments.contains("--microphone-noise-suppression"))
        try child.ack(); XCTAssertEqual(model.phase, .running); XCTAssertEqual(model.activeOptions?.installedAEC, configuration())
        XCTAssertEqual(model.startupWait(for: model.activeOptions!), 40_000_000_000)
        _ = await model.stop(); XCTAssertEqual(model.phase, .idle)
    }
    func testProcessingAndSelectionChangesRequireValidation() async throws {
        let child = AECChild(), model = try await model(child)
        model.echoCancellation = true; await model.validateInstalledAEC(); XCTAssertTrue(model.canStart)
        model.microphoneNoise = true; XCTAssertNil(model.installedAECConfiguration); XCTAssertFalse(model.canStart)
        await model.validateInstalledAEC(); XCTAssertTrue(model.canStart)
        model.microphoneNoise = false; XCTAssertNil(model.installedAECConfiguration)
        await model.validateInstalledAEC(); model.selectInstalledApp(URL(fileURLWithPath: "/replacement.app")); XCTAssertFalse(model.canStart)
        await model.validateInstalledAEC(); model.echoCancellation = false; XCTAssertNil(model.installedAECConfiguration)
        model.start(); try await wait { child.running }; XCTAssertFalse(child.arguments.contains("--aec-provider")); _ = await model.stop()
    }
    func testStaleValidationAndFailureNeverAdmit() async throws {
        let snapshot = try inventory(), config = configuration(); var resume: CheckedContinuation<InstalledAECConfiguration, Never>?
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { AECChild() }, resolveInstalledAEC: { _ in await withCheckedContinuation { resume = $0 } })
        model.selectInstalledApp(URL(fileURLWithPath: "/fixture.app")); model.echoCancellation = true
        let task = Task { await model.validateInstalledAEC() }; try await wait { resume != nil }
        model.echoCancellation = false; resume?.resume(returning: config); await task.value
        XCTAssertNil(model.installedAECConfiguration); XCTAssertFalse(model.aecValidating)
        let failed = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { AECChild() }, resolveInstalledAEC: { _ in throw InstalledNCError.invalid("fixture AEC rejection") })
        failed.selectInstalledApp(URL(fileURLWithPath: "/fixture.app")); failed.echoCancellation = true; await failed.validateInstalledAEC()
        XCTAssertNil(failed.installedAECConfiguration); XCTAssertFalse(failed.aecValidating); XCTAssertTrue(failed.aecStatus.contains("fixture AEC rejection"))
    }
    func testWrongAcknowledgmentStopsAndLateReadyCannotRestore() async throws {
        let child = AECChild(), model = try await model(child)
        model.echoCancellation = true; await model.validateInstalledAEC(); model.start(); try await wait { child.running }
        try child.ack { $0["aec_worker_sha256"] = "wrong" }; try await wait { child.terminations == 1 }
        XCTAssertNil(model.activeOptions); try child.ack(); XCTAssertEqual(model.phase, .idle)
    }
    func testAECWithInstalledSpeakerUsesBothWorkers() async throws {
        let snapshot = try inventory(), config = configuration(), child = AECChild()
        let speaker = InstalledNCConfiguration(nodePath: "/fixture/node", workerPath: "/fixture/nc-worker", addonPath: "/fixture/addon", modelPath: "/fixture/model", adapterPath: "/fixture/adapter", libraryPath: "/fixture/lib", nodeSHA256: InstalledNCConfiguration.reviewedNodeSHA256, adapterSHA256: String(repeating: "b", count: 64), modelRole: .inbound)
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { child }, resolveInstalledProvider: { _, _, role in XCTAssertEqual(role, .inbound); return speaker }, resolveInstalledAEC: { _ in config })
        await model.refresh(); model.inputUID = "mic"; model.outputUID = "speaker"
        model.selectInstalledApp(URL(fileURLWithPath: "/fixture.app")); model.selectInstalledNode(URL(fileURLWithPath: "/fixture/node"))
        model.echoCancellation = true; model.speakerNoise = true; model.speakerProvider = .installedKrisp
        await model.validateInstalledAEC(); XCTAssertFalse(model.canStart)
        await model.validateInstalledProvider(); XCTAssertTrue(model.canStart)
        model.start(); try await wait { child.running }; try child.ack()
        XCTAssertEqual(model.phase, .running); XCTAssertEqual(model.startupWait(for: model.activeOptions!), 70_000_000_000)
        XCTAssertTrue(child.arguments.contains("--aec-provider")); XCTAssertTrue(child.arguments.contains("--speaker-provider"))
        XCTAssertFalse(child.arguments.contains("--microphone-provider")); _ = await model.stop()
    }
    func testAECThenNCProfilesAndBadChainAckStop() async throws {
        for installed in [false, true] { for installedSpeaker in [false, true] {
            let snapshot = try inventory(), config = configuration(), child = AECChild()
            let model = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { child }, resolveInstalledProvider: { _, _, role in
                InstalledNCConfiguration(nodePath: "/fixture/node", workerPath: "/fixture/worker", addonPath: "/fixture/addon", modelPath: "/fixture/model", adapterPath: "/fixture/adapter", libraryPath: "/fixture/lib", nodeSHA256: InstalledNCConfiguration.reviewedNodeSHA256, adapterSHA256: String(repeating: "b", count: 64), modelRole: role)
            }, resolveInstalledAEC: { _ in config })
            await model.refresh(); model.inputUID = "mic"; model.outputUID = "speaker"
            model.selectInstalledApp(URL(fileURLWithPath: "/fixture.app")); model.selectInstalledNode(URL(fileURLWithPath: "/fixture/node"))
            model.echoCancellation = true; model.microphoneNoise = true; model.microphoneProvider = installed ? .installedKrisp : .rnnoise
            model.speakerNoise = true; model.speakerProvider = installedSpeaker ? .installedKrisp : .rnnoise
            await model.validateInstalledAEC(); await model.validateInstalledProvider(); XCTAssertTrue(model.canStart)
            model.start(); try await wait { child.running }; try child.ack()
            XCTAssertEqual(model.phase, .running)
            if let active = model.activeOptions { XCTAssertEqual(model.startupWait(for: active), UInt64(1 + (installed ? 1 : 0) + (installedSpeaker ? 1 : 0)) * 30_000_000_000 + 10_000_000_000) }
            _ = await model.stop()
            model.start(); try await wait { child.running }; try child.ack { $0["microphone_processing_order"] = "nc-then-aec" }
            try await wait { child.terminations == 2 }; XCTAssertNil(model.activeOptions)
        } }
    }
    func testCancellationDuringPermissionDoesNotLaunch() async throws {
        let snapshot = try inventory(), config = configuration(), child = AECChild()
        var permission: CheckedContinuation<Bool, Never>?
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .notDetermined }, requestAuthorization: { await withCheckedContinuation { permission = $0 } }, factory: { child }, resolveInstalledAEC: { _ in config })
        await model.refresh(); model.inputUID = "mic"; model.outputUID = "speaker"; model.selectInstalledApp(URL(fileURLWithPath: "/fixture.app")); model.echoCancellation = true
        await model.validateInstalledAEC(); model.start(); try await wait { permission != nil }
        _ = await model.stop(); permission?.resume(returning: true); await Task.yield()
        XCTAssertFalse(child.running); XCTAssertEqual(model.phase, .idle)
    }
}
