import XCTest
import AVFoundation
import LocalStore
@testable import LabVoice

private actor RecoveryGate: RecordingRecoveryServing {
    var items: [RecoverableRecording]
    var scanWait: CheckedContinuation<Void, Never>?
    var saveWait: CheckedContinuation<Void, Never>?
    var holdScan = false, holdSave = false, failScan = false, failSave = false
    var scans = 0, saves = 0
    var cleanupFailure = false
    init(_ items: [RecoverableRecording]) { self.items = items }
    func configure(scan: Bool = false, save: Bool = false, failScan: Bool = false, failSave: Bool = false, cleanupFailure: Bool = false) {
        holdScan = scan; holdSave = save; self.failScan = failScan; self.failSave = failSave; self.cleanupFailure = cleanupFailure
    }
    func scan() async throws -> [RecoverableRecording] {
        scans += 1
        if holdScan { await withCheckedContinuation { scanWait = $0 } }
        if failScan { throw CocoaError(.fileReadNoPermission) }
        return items
    }
    func saveCopy(_ item: RecoverableRecording, to location: LibraryLocationSnapshot) async throws -> RecordingSave {
        saves += 1
        if holdSave { await withCheckedContinuation { saveWait = $0 } }
        if failSave { throw cleanupFailure ? RecordingRecoveryError.cleanupIncomplete(path: "/synthetic-retained-snapshot") : RecordingRecoveryError.sourceChanged }
        return .init(session: try location.open().save(title: "Injected copy", startedAt: Date(), durationSeconds: 1, transcript: []), cleanupWarning: nil)
    }
    func waitingScan() -> Bool { scanWait != nil }
    func waitingSave() -> Bool { saveWait != nil }
    func counts() -> (Int, Int) { (scans, saves) }
    func releaseScan() { scanWait?.resume(); scanWait = nil; holdScan = false }
    func releaseSave() { saveWait?.resume(); saveWait = nil; holdSave = false }
}

@MainActor final class RecordingRecoveryControllerTests: XCTestCase {
    private func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    private func location(_ root: URL) -> LibraryLocation {
        let suite = "Recovery-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return LibraryLocation(defaults: defaults, defaultRoot: root)
    }
    private func audio() -> AudioRouteController {
        AudioRouteController(readInventory: {
            .init(devices: [.init(uid: "synthetic-input", name: "Synthetic", alive: 1, nominalRate: 48000, input: .init(channels: 1), output: .init(channels: 0)),
                            .init(uid: "synthetic-output", name: "Synthetic", alive: 1, nominalRate: 48000, input: .init(channels: 0), output: .init(channels: 2))],
                  companions: [.init(uid: "dev.hari.labvoice.feed", present: true), .init(uid: "dev.hari.labvoice.monitor", present: true)], errors: [])
        }, authorization: { XCTFail("Recovery must block route before authorization"); return .denied }, requestAuthorization: { XCTFail("No permission request"); return false }, factory: { XCTFail("No helper launch"); throw AudioHelperError.missingHelper })
    }
    private func item() -> RecoverableRecording { .init(id: UUID(), directory: URL(fileURLWithPath: "/unused-retained-fixture"), startedAt: Date(), frames: 48000, eligibility: .finalized) }
    func testScanAndSaveHoldSharedCaptureAndLibraryAdmissionsUntilCompletion() async throws {
        let target = location(try temporary()), route = audio(), service = RecoveryGate([item()])
        let controller = RecordingRecoveryController(service: service, audio: route, location: target)
        await route.refresh(); route.inputUID = "synthetic-input"; route.outputUID = "synthetic-output"
        XCTAssertTrue(route.canStart)
        await service.configure(scan: true)
        let scanning = Task { await controller.scan() }
        for _ in 0..<1000 { if await service.waitingScan() { break }; await Task.yield() }
        XCTAssertTrue(controller.busy); XCTAssertFalse(target.canSwitch); XCTAssertFalse(route.canStart)
        route.start(); XCTAssertEqual(route.phase, .idle)
        let microphone = MicrophoneTestController(authorization: { XCTFail("No microphone permission read"); return .denied }, factory: { XCTFail("No microphone helper"); throw AudioHelperError.missingHelper })
        microphone.start(input: route.inventory?.devices.first, microphoneUnmuted: true, routeStopped: true)
        XCTAssertFalse(microphone.engaged)
        await service.releaseScan(); await scanning.value
        XCTAssertTrue(controller.canRecover); XCTAssertTrue(target.canSwitch)
        let request = try XCTUnwrap(controller.request(for: controller.items[0]))
        await service.configure(save: true)
        let saving = Task { await controller.saveCopy(request) }
        for _ in 0..<1000 { if await service.waitingSave() { break }; await Task.yield() }
        XCTAssertTrue(controller.busy); XCTAssertFalse(target.canSwitch); XCTAssertFalse(route.canStart)
        await controller.saveCopy(request) // Another window cannot start a second write.
        await service.releaseSave(); await saving.value
        let calls = await service.counts(); XCTAssertEqual(calls.1, 1)
        XCTAssertNil(controller.error)
        XCTAssertTrue(controller.canRecover); XCTAssertTrue(AudioCaptureAdmission.shared.available)
    }
    func testStaleConfirmationAndFailuresNeverWriteOrHoldLeases() async throws {
        let target = location(try temporary()), service = RecoveryGate([item()])
        let controller = RecordingRecoveryController(service: service, audio: audio(), location: target)
        await controller.scan()
        let old = try XCTUnwrap(controller.request(for: controller.items[0]))
        let chosen = await target.choose(try temporary())
        XCTAssertTrue(chosen)
        await controller.saveCopy(old)
        var calls = await service.counts(); XCTAssertEqual(calls.1, 0)
        XCTAssertTrue(controller.items.isEmpty)
        await service.configure(failScan: true); await controller.scan()
        XCTAssertNotNil(controller.error); XCTAssertTrue(controller.canRecover)
        await service.configure(); await controller.scan()
        let staleScan = try XCTUnwrap(controller.request(for: controller.items[0]))
        await controller.scan(); await controller.saveCopy(staleScan)
        calls = await service.counts(); XCTAssertEqual(calls.1, 0)
        let fresh = try XCTUnwrap(controller.request(for: controller.items[0]))
        await service.configure(failSave: true); await controller.saveCopy(fresh)
        XCTAssertNotNil(controller.error); XCTAssertTrue(target.canSwitch); XCTAssertTrue(AudioCaptureAdmission.shared.available)
        await service.configure(failSave: true, cleanupFailure: true); await controller.saveCopy(fresh)
        XCTAssertTrue(controller.error?.contains("/synthetic-retained-snapshot") == true)
        XCTAssertTrue(controller.error?.contains("source was not deleted") == true)
    }
    func testExistingCaptureOwnerAndInvalidCandidateCannotRecover() async throws {
        let target = location(try temporary()), valid = item()
        let invalid = RecoverableRecording(id: UUID(), directory: valid.directory, startedAt: Date(), frames: 0, eligibility: .invalid("Incomplete WAV"))
        let service = RecoveryGate([invalid]), controller = RecordingRecoveryController(service: service, audio: audio(), location: target)
        let owner = UUID(); XCTAssertTrue(AudioCaptureAdmission.shared.acquire(owner, owner: .route))
        await controller.scan(); let calls = await service.counts(); XCTAssertEqual(calls.0, 0)
        AudioCaptureAdmission.shared.release(owner)
        await controller.scan(); XCTAssertNil(controller.request(for: invalid)); XCTAssertNil(controller.request(for: valid))
    }
    func testSyntheticFinalizedStageThroughControllerCopiesAndNotifiesWithoutDeletingSource() async throws {
        let root = try temporary(), library = try temporary(), target = location(library)
        let storage = RecordingStorage(stagingRoot: root), job = try await storage.prepare(operationID: UUID())
        var wav = Data()
        func text(_ value: String) { wav.append(contentsOf: value.utf8) }
        func word(_ value: UInt32, _ count: Int) { for n in 0..<count { wav.append(UInt8(truncatingIfNeeded: value >> (8 * n))) } }
        text("RIFF"); word(436, 4); text("WAVEfmt "); word(16, 4); word(1, 2); word(2, 2)
        word(48000, 4); word(192000, 4); word(4, 2); word(16, 2); text("data"); word(400, 4); wav.append(Data(repeating: 0, count: 400))
        try wav.write(to: job.wav); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: job.wav.path)
        let originalManifest = try Data(contentsOf: job.directory.appendingPathComponent("job.json"))
        let notifications = NotificationCenter(), saved = expectation(description: "History refresh notification")
        saved.expectedFulfillmentCount = 2
        let observer = notifications.addObserver(forName: .localRecordingSaved, object: nil, queue: nil) { _ in saved.fulfill() }
        defer { notifications.removeObserver(observer) }
        let controller = RecordingRecoveryController(service: RecordingRecovery(stagingRoot: root), audio: audio(), location: target, notifications: notifications)
        await controller.scan(); let candidate = try XCTUnwrap(controller.items.first)
        let request = try XCTUnwrap(controller.request(for: candidate))
        XCTAssertTrue(try target.snapshot.open().inventory().sessions.isEmpty)
        await controller.saveCopy(request); await controller.saveCopy(request)
        await fulfillment(of: [saved], timeout: 1)
        XCTAssertNil(controller.error)
        let sessions = try target.snapshot.open().inventory().sessions
        XCTAssertEqual(sessions.count, 2); XCTAssertNotEqual(sessions[0].id, sessions[1].id)
        for session in sessions {
            let url = try XCTUnwrap(target.snapshot.open().recordingURL(for: session.id))
            XCTAssertEqual(try Data(contentsOf: url), wav)
        }
        XCTAssertEqual(try Data(contentsOf: job.wav), wav)
        XCTAssertEqual(try Data(contentsOf: job.directory.appendingPathComponent("job.json")), originalManifest)
    }
}
