import XCTest
import AVFoundation
@testable import LabVoice

@MainActor final class HeadsetConfirmationTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "headset-confirmation-tests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
    func testPersistenceUsesUIDAndRetainsNamesOnlyAsLabels() {
        let prefs = defaults(), store = HeadsetConfirmationStore(defaults: prefs)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(store.confirm(uid: "one", name: "Same headset"))
        XCTAssertTrue(store.confirm(uid: "two", name: "Same headset"))
        XCTAssertEqual(HeadsetConfirmationStore(defaults: prefs).entries.map(\.uid), ["one", "two"])
        XCTAssertTrue(store.confirm(uid: "one", name: "Renamed headset"))
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries.first { $0.uid == "one" }?.name, "Renamed headset")
        XCTAssertTrue(store.remove(uid: "two"))
        XCTAssertEqual(HeadsetConfirmationStore(defaults: prefs).entries.map(\.uid), ["one"])
        prefs.set("unrelated", forKey: "otherPreference")
        XCTAssertTrue(store.reset()); XCTAssertTrue(HeadsetConfirmationStore(defaults: prefs).entries.isEmpty)
        XCTAssertEqual(prefs.string(forKey: "otherPreference"), "unrelated")
    }
    func testMalformedPersistedRecordsNeverGrantConfirmation() throws {
        let prefs = defaults()
        let invalid: [Any] = [
            ["schemaVersion": 2, "entries": [["uid": "one", "name": "Headset"]]],
            ["schemaVersion": 1, "entries": [["uid": "", "name": "Headset"]]],
            ["schemaVersion": 1, "entries": [["uid": "one", "name": ""]]],
            ["schemaVersion": 1, "entries": [["uid": "one", "name": "Headset"], ["uid": "one", "name": "Duplicate"]]],
            ["schemaVersion": 1, "entries": [["uid": "one"]]],
            ["schemaVersion": 1, "entries": [["uid": "one\0", "name": "Headset"]]],
            ["schemaVersion": 1, "entries": Array(repeating: ["uid": "one", "name": "Headset"], count: 257)]
        ]
        for record in invalid {
            prefs.set(try JSONSerialization.data(withJSONObject: record), forKey: HeadsetConfirmationStore.preferenceKey)
            XCTAssertTrue(HeadsetConfirmationStore(defaults: prefs).entries.isEmpty)
        }
        prefs.set("wrong type", forKey: HeadsetConfirmationStore.preferenceKey)
        let store = HeadsetConfirmationStore(defaults: prefs)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(store.confirm(uid: " ", name: "Headset")); XCTAssertFalse(store.confirm(uid: "one", name: String(repeating: "a", count: 4097)))
    }
    private func inventory(name: String = "Same headset") throws -> AudioInventory {
        let devices: [[String: Any]] = [
            ["uid": "one", "name": name, "alive": 1, "nominal_rate": 48000, "input": ["channels": 1], "output": ["channels": 0]],
            ["uid": "two", "name": "Same headset", "alive": 1, "nominal_rate": 48000, "input": ["channels": 1], "output": ["channels": 0]],
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
    func testConfirmationGatesHVCWithoutLaunchingAndRenameKeepsUID() async throws {
        var snapshot = try inventory(), resolutions = 0, permissions = 0, launches = 0
        let prefs = defaults()
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { permissions += 1; return .authorized }, requestAuthorization: { XCTFail("Unexpected permission request"); return false }, factory: { launches += 1; return HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: prefs), resolveInstalledProvider: { _, _, role in resolutions += 1; return self.configuration(role) })
        await select(model); await model.validateInstalledProvider(); model.start()
        XCTAssertEqual(resolutions, 0); XCTAssertEqual(permissions, 0); XCTAssertEqual(launches, 0); XCTAssertFalse(model.canStart)
        model.confirmSelectedHeadset(); XCTAssertTrue(model.selectedHeadsetConfirmed)
        XCTAssertEqual(permissions, 0); XCTAssertEqual(launches, 0)
        await model.validateInstalledProvider(); XCTAssertTrue(model.canStart)
        snapshot = try inventory(name: "Renamed headset"); await model.refresh()
        XCTAssertTrue(model.selectedHeadsetConfirmed); XCTAssertEqual(model.selectedMicrophone?.name, "Renamed headset")
        model.inputUID = "two"; XCTAssertFalse(model.selectedHeadsetConfirmed); XCTAssertNil(model.installedConfiguration)
        await model.validateInstalledProvider(); XCTAssertEqual(resolutions, 1)
        model.installedMicrophoneMode = .ordinaryNC; await model.validateInstalledProvider(); XCTAssertTrue(model.canStart)
        model.microphoneProvider = .rnnoise; XCTAssertTrue(model.canStart)
        XCTAssertEqual(permissions, 0); XCTAssertEqual(launches, 0)
    }
    func testRemovalResetAndDeviceChangeRejectPendingValidation() async throws {
        let snapshot = try inventory(); var resume: CheckedContinuation<InstalledNCConfiguration, Never>?
        let prefs = defaults()
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { XCTFail("Unexpected authorization"); return .authorized }, requestAuthorization: { false }, factory: { XCTFail("Unexpected launch"); return HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: prefs), resolveInstalledProvider: { _, _, _ in await withCheckedContinuation { resume = $0 } })
        await select(model); model.confirmSelectedHeadset()
        for action in ["device", "remove", "reset"] {
            model.inputUID = "one"; model.installedMicrophoneMode = .backgroundVoice; model.confirmSelectedHeadset(); resume = nil
            let validation = Task { await model.validateInstalledProvider() }; try await wait { resume != nil }
            switch action {
            case "device": model.inputUID = "two"
            case "remove": model.removeHeadsetConfirmation(uid: "one")
            default: prefs.set("keep", forKey: "otherPreference"); model.resetHeadsetConfirmations()
            }
            resume?.resume(returning: configuration(.outboundHVC)); await validation.value
            XCTAssertNil(model.installedConfiguration); XCTAssertFalse(model.providerValidating)
            if action == "reset" {
                XCTAssertEqual(model.installedMicrophoneMode, .ordinaryNC); XCTAssertTrue(model.headsetConfirmations.isEmpty)
                XCTAssertEqual(prefs.string(forKey: "otherPreference"), "keep")
            }
        }
    }
    func testDeferredPermissionReturnToOriginalSelectionCannotRestoreAdmission() async throws {
        for changeMode in [false, true] {
            let snapshot = try inventory(); var permission: CheckedContinuation<Bool, Never>?, launches = 0
            let model = AudioRouteController(readInventory: { snapshot }, authorization: { .notDetermined }, requestAuthorization: { await withCheckedContinuation { permission = $0 } }, factory: { launches += 1; return HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: defaults()), resolveInstalledProvider: { _, _, role in self.configuration(role) })
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
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .notDetermined }, requestAuthorization: { await withCheckedContinuation { permission = $0 } }, factory: { launches += 1; return HeadsetChild() }, headsetStore: HeadsetConfirmationStore(defaults: defaults()), resolveInstalledProvider: { _, _, role in self.configuration(role) })
        await select(model); model.confirmSelectedHeadset(); await model.validateInstalledProvider(); model.start()
        try await wait { permission != nil }; XCTAssertFalse(model.canEditHeadsetConfirmations)
        model.removeHeadsetConfirmation(uid: "one"); model.resetHeadsetConfirmations()
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
