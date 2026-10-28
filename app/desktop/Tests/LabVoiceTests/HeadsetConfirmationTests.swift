import XCTest
import AVFoundation
@testable import LabVoice

@MainActor final class HeadsetConfirmationTests: XCTestCase {
    private func cacheStore() -> LocalHeadsetCompatibilityStore {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return .init(directory: directory)
    }
    private func defaults() -> UserDefaults {
        let name = "headset-confirmation-tests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
    func testManualNamesPersistAndRemovalIsExact() {
        let prefs = defaults(), store = HeadsetConfirmationStore(defaults: prefs)
        XCTAssertTrue(store.confirm(name: "Headset"))
        XCTAssertTrue(store.confirm(name: "headset"))
        XCTAssertEqual(HeadsetConfirmationStore(defaults: prefs).entries.map(\.name), ["Headset", "headset"])
        XCTAssertTrue(store.remove(name: "Headset"))
        XCTAssertEqual(store.entries.map(\.name), ["headset"])
        XCTAssertTrue(store.reset()); XCTAssertTrue(store.entries.isEmpty)
    }
    func testManualNamesKeepUTF16IdentityAndIgnoreLegacyUIDRecord() {
        let prefs = defaults()
        prefs.set(Data("{\"schemaVersion\":1,\"entries\":[{\"uid\":\"one\",\"name\":\"Headset\"}]}".utf8), forKey: "headsetConfirmations.v1")
        let store = HeadsetConfirmationStore(defaults: prefs)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(store.confirm(name: "caf\u{00e9}"))
        XCTAssertTrue(store.confirm(name: "cafe\u{0301}"))
        XCTAssertEqual(Set(store.entries.map(\.id)).count, 2)
        XCTAssertEqual(HeadsetConfirmationStore(defaults: prefs).entries.count, 2)
        XCTAssertTrue(store.remove(name: "caf\u{00e9}")); XCTAssertEqual(store.entries.count, 1)
    }
    func testOfflineListMutationRejectsPendingValidationAndBlockWinsManual() async throws {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.json")
        try Data("{\"allow_list\":[{\"name\":\"Same headset\"}],\"block_list\":[{\"name\":\"Same headset\"}]}".utf8).write(to: source)
        let snapshot = try inventory(); var resume: CheckedContinuation<InstalledNCConfiguration, Never>?
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { XCTFail("No permission"); return .authorized }, requestAuthorization: { false }, factory: { HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: defaults()), compatibilityStore: .init(directory: directory.appendingPathComponent("saved")), resolveInstalledProvider: { _, _, _ in await withCheckedContinuation { resume = $0 } })
        await select(model); model.confirmSelectedHeadset()
        let validation = Task { await model.validateInstalledProvider() }; try await wait { resume != nil }
        model.importCompatibilityList(at: source)
        XCTAssertEqual(model.selectedCompatibility, .blocked); XCTAssertEqual(model.selectedMicrophoneRole, .outbound)
        resume?.resume(returning: configuration(.outboundHVC)); await validation.value
        XCTAssertNil(model.installedConfiguration)
        model.clearCompatibilityList(); XCTAssertEqual(model.selectedCompatibility, .manualAllowed)
        model.removeHeadsetConfirmation(name: "Same headset")
        try Data("{\"allow_list\":[{\"name\":\"Same headset\"}],\"block_list\":[]}".utf8).write(to: source)
        model.importCompatibilityList(at: source)
        XCTAssertEqual(model.selectedCompatibility, .allowed)
        XCTAssertTrue(model.headsetConfirmations.isEmpty)
        XCTAssertEqual(model.selectedMicrophoneRole, .outboundHVC)
    }
    func testMalformedManualRecordsDoNotGrantChoices() throws {
        let prefs = defaults()
        for record: [String: Any] in [
            ["schemaVersion": 1, "entries": [["uid": "one", "name": "Headset"]]],
            ["schemaVersion": 2, "entries": [["uid": "one", "name": ""]]],
            ["schemaVersion": 2, "entries": [["uid": "one", "name": "Headset"], ["uid": "two", "name": "Headset"]]]
        ] {
            prefs.set(try JSONSerialization.data(withJSONObject: record), forKey: HeadsetConfirmationStore.preferenceKey)
            XCTAssertTrue(HeadsetConfirmationStore(defaults: prefs).entries.isEmpty)
        }
    }
    func testSameUIDInventoryReplacementRejectsPendingValidation() async throws {
        var snapshot = try inventory(), resume: CheckedContinuation<InstalledNCConfiguration, Never>?
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { XCTFail("No permission"); return .authorized }, requestAuthorization: { false }, factory: { HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: defaults()), compatibilityStore: cacheStore(), resolveInstalledProvider: { _, _, _ in await withCheckedContinuation { resume = $0 } })
        await select(model); model.confirmSelectedHeadset()
        let validation = Task { await model.validateInstalledProvider() }; try await wait { resume != nil }
        snapshot = try inventory(name: "Different interface"); await model.refresh()
        resume?.resume(returning: configuration(.outboundHVC)); await validation.value
        XCTAssertEqual(model.inputUID, "one"); XCTAssertNil(model.installedConfiguration)
        XCTAssertEqual(model.selectedMicrophoneRole, .outbound)
    }
    func testImportedAllowListSelectsHVCWithoutManualAndResetKeepsList() async throws {
        let store = cacheStore()
        let source = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: source) }
        try Data("{\"allow_list\":[{\"name\":\"Same headset\"}],\"block_list\":[]}".utf8).write(to: source)
        let snapshot = try inventory(); var requested: [InstalledNCModelRole] = []
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { XCTFail("No permission"); return .authorized }, requestAuthorization: { false }, factory: { HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: defaults()), compatibilityStore: store, resolveInstalledProvider: { _, _, role in requested.append(role); return self.configuration(role) })
        await select(model); model.importCompatibilityList(at: source)
        XCTAssertTrue(model.headsetConfirmations.isEmpty)
        await model.validateInstalledProvider(); XCTAssertEqual(requested, [.outboundHVC])
        model.installedMicrophoneMode = .ordinaryNC
        await model.validateInstalledProvider(); XCTAssertEqual(requested, [.outboundHVC, .outbound])
        model.resetHeadsetConfirmations(); XCTAssertEqual(model.selectedCompatibility, .allowed)
        await model.validateInstalledProvider(); XCTAssertEqual(requested, [.outboundHVC, .outbound, .outboundHVC])
    }
    private func inventory(name: String = "Same headset") throws -> AudioInventory {
        let devices: [[String: Any]] = [
            ["uid": "one", "name": name, "interface_name": name, "manufacturer": "", "model_id": "", "alive": 1, "nominal_rate": 48000, "input": ["channels": 1], "output": ["channels": 0]],
            ["uid": "two", "name": "Same headset", "interface_name": "Other headset", "manufacturer": "", "model_id": "", "alive": 1, "nominal_rate": 48000, "input": ["channels": 1], "output": ["channels": 0]],
            ["uid": "speaker", "name": "Speaker", "alive": 1, "nominal_rate": 48000, "input": ["channels": 0], "output": ["channels": 2]]]
        return try JSONDecoder().decode(AudioInventory.self, from: JSONSerialization.data(withJSONObject: ["devices": devices,
            "companion_devices": [["uid": "dev.hari.labvoice.feed", "present": true], ["uid": "dev.hari.labvoice.monitor", "present": true]], "errors": []]))
    }
    private func configuration(_ role: InstalledNCModelRole) -> InstalledNCConfiguration {
        .init(nodePath: "/fixture/node", workerPath: "/fixture/worker", addonPath: "/fixture/addon", modelPath: "/fixture/model", adapterPath: "/fixture/adapter", libraryPath: "/fixture/lib", nodeSHA256: InstalledNCConfiguration.reviewedNodeSHA256, adapterSHA256: String(repeating: "a", count: 64), modelRole: role)
    }
    private func select(_ model: AudioRouteController) async {
        await model.refresh(); model.inputUID = "one"; model.outputUID = "speaker"
        model.microphoneNoise = true; model.microphoneProvider = .installedKrisp; model.installedMicrophoneMode = .backgroundVoice
        model.selectInstalledApp(URL(fileURLWithPath: "/fixture/App.app")); model.selectInstalledNode(URL(fileURLWithPath: "/fixture/node"))
    }
    private func wait(_ predicate: () -> Bool) async throws {
        for _ in 0..<1000 { if predicate() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Fixture did not progress")
    }
    func testAutomaticFallbackAndRename() async throws {
        var snapshot = try inventory()
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { XCTFail("No permission"); return .authorized }, requestAuthorization: { false }, factory: { HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: defaults()), compatibilityStore: cacheStore(), resolveInstalledProvider: { _, _, role in self.configuration(role) })
        await select(model); await model.validateInstalledProvider()
        XCTAssertEqual(model.installedConfiguration?.modelRole, .outbound)
        model.confirmSelectedHeadset(); XCTAssertTrue(model.selectedHeadsetConfirmed)
        await model.validateInstalledProvider(); XCTAssertEqual(model.installedConfiguration?.modelRole, .outboundHVC)
        snapshot = try inventory(name: "Renamed headset"); await model.refresh()
        XCTAssertFalse(model.selectedHeadsetConfirmed); XCTAssertNil(model.installedConfiguration)
        await model.validateInstalledProvider(); XCTAssertEqual(model.installedConfiguration?.modelRole, .outbound)
    }
    func testRemovalResetAndDeviceChangeRejectPendingValidation() async throws {
        let snapshot = try inventory(); var resume: CheckedContinuation<InstalledNCConfiguration, Never>?
        let prefs = defaults()
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { XCTFail("Unexpected authorization"); return .authorized }, requestAuthorization: { false }, factory: { XCTFail("Unexpected launch"); return HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: prefs), compatibilityStore: cacheStore(), resolveInstalledProvider: { _, _, _ in await withCheckedContinuation { resume = $0 } })
        await select(model); model.confirmSelectedHeadset()
        for action in ["device", "remove", "reset"] {
            model.inputUID = "one"; model.installedMicrophoneMode = .backgroundVoice; model.confirmSelectedHeadset(); resume = nil
            let validation = Task { await model.validateInstalledProvider() }; try await wait { resume != nil }
            switch action {
            case "device": model.inputUID = "two"
            case "remove": model.removeHeadsetConfirmation(name: "Same headset")
            default: prefs.set("keep", forKey: "otherPreference"); model.resetHeadsetConfirmations()
            }
            resume?.resume(returning: configuration(.outboundHVC)); await validation.value
            XCTAssertNil(model.installedConfiguration); XCTAssertFalse(model.providerValidating)
            if action == "reset" {
                XCTAssertEqual(model.installedMicrophoneMode, .backgroundVoice); XCTAssertTrue(model.headsetConfirmations.isEmpty)
                XCTAssertEqual(prefs.string(forKey: "otherPreference"), "keep")
            }
        }
    }
    func testDeferredPermissionReturnToOriginalSelectionCannotRestoreAdmission() async throws {
        for changeMode in [false, true] {
            let snapshot = try inventory(); var permission: CheckedContinuation<Bool, Never>?, launches = 0
            let model = AudioRouteController(readInventory: { snapshot }, authorization: { .notDetermined }, requestAuthorization: { await withCheckedContinuation { permission = $0 } }, factory: { launches += 1; return HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: defaults()), compatibilityStore: cacheStore(), resolveInstalledProvider: { _, _, role in self.configuration(role) })
            await select(model); model.confirmSelectedHeadset(); await model.validateInstalledProvider(); model.start()
            try await wait { permission != nil }
            if changeMode {
                model.installedMicrophoneMode = .ordinaryNC; model.installedMicrophoneMode = .backgroundVoice
            } else { model.inputUID = "two"; model.inputUID = "one" }
            XCTAssertTrue(model.selectedHeadsetConfirmed); XCTAssertNil(model.installedConfiguration)
            permission?.resume(returning: true); try await wait { launches > 0 || model.phase == .idle }
            XCTAssertEqual(launches, 0); XCTAssertEqual(model.phase, .idle)
            _ = await model.stop()
        }
    }
    func testDeferredPermissionDeviceChangePreventsHelperLaunchAndLocksPolicy() async throws {
        let snapshot = try inventory(); var permission: CheckedContinuation<Bool, Never>?, launches = 0
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .notDetermined }, requestAuthorization: { await withCheckedContinuation { permission = $0 } }, factory: { launches += 1; return HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: defaults()), compatibilityStore: cacheStore(), resolveInstalledProvider: { _, _, role in self.configuration(role) })
        await select(model); model.confirmSelectedHeadset(); await model.validateInstalledProvider(); model.start()
        try await wait { permission != nil }; XCTAssertFalse(model.canEditHeadsetConfirmations)
        model.removeHeadsetConfirmation(name: "Same headset"); model.resetHeadsetConfirmations()
        XCTAssertTrue(model.selectedHeadsetConfirmed); XCTAssertEqual(model.installedMicrophoneMode, .backgroundVoice)
        model.inputUID = "two"; model.confirmSelectedHeadset(); XCTAssertFalse(model.selectedHeadsetConfirmed)
        permission?.resume(returning: true); try await wait { model.phase == .idle }
        XCTAssertEqual(launches, 0); XCTAssertNil(model.activeOptions)
    }
}

@MainActor private final class HeadsetChild: AudioHelperChild {
    var running = false
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws { XCTFail("Unexpected helper launch") }
    func send(_ line: Data) throws {}
    func terminate() {}
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { true }
}
