import XCTest
import Foundation
import AVFoundation
import LocalStore
@testable import LabVoice

@MainActor private final class CapturePermissionGate {
    var pending: CheckedContinuation<Bool, Never>?
    var calls = 0
    func request() async -> Bool { calls += 1; return await withCheckedContinuation { pending = $0 } }
    func resolve(_ value: Bool) { pending?.resume(returning: value); pending = nil }
}

@MainActor private final class CaptureInspectionGate {
    var pending: CheckedContinuation<LabVoice.AudioHardwareDevice?, Error>?
    var canDrain = false
    var stopCalls = 0
    func inspect(_ uid: String) async throws -> LabVoice.AudioHardwareDevice? {
        try await withCheckedThrowingContinuation { pending = $0 }
    }
    func stop() -> Bool {
        stopCalls += 1
        guard canDrain else { return false }
        pending?.resume(returning: nil); pending = nil; return true
    }
}

private actor CaptureMetadataGateStorage: RecordingStoring {
    let base: RecordingStorage
    var pending: CheckedContinuation<Void, Never>?
    var first = true
    var states: [Bool] = []
    let failWrites: Bool
    init(_ base: RecordingStorage, failWrites: Bool = false) { self.base = base; self.failWrites = failWrites }
    func prepare(operationID: UUID, location: LibraryLocationSnapshot) async throws -> RecordingJob { try await base.prepare(operationID: operationID, location: location) }
    func prepare(operationID: UUID, location: LibraryLocationSnapshot, source: RecordingSource) async throws -> RecordingJob { try await base.prepare(operationID: operationID, location: location, source: source) }
    func persistMetadata(_ job: RecordingJob) async throws {
        if failWrites { throw RecordingStorageError.invalidDirectory }
        if first { first = false; await withCheckedContinuation { pending = $0 } }
        try await base.persistMetadata(job); states.append(job.captureAdmissionVerified == true)
    }
    func waiting() -> Bool { pending != nil }
    func resume() { pending?.resume(); pending = nil }
    func savedStates() -> [Bool] { states }
    func releaseDestination(_ job: RecordingJob) async { await base.releaseDestination(job) }
    func retainedDirectories() async throws -> [String] { try await base.retainedDirectories() }
    func retainFailure(_ job: RecordingJob, message: String) async throws { try await base.retainFailure(job, message: message) }
    func saveCompleted(_ job: RecordingJob, path: String, frames: UInt64, sampleRate: Double, channels: UInt32) async throws -> RecordingSave { try await base.saveCompleted(job, path: path, frames: frames, sampleRate: sampleRate, channels: channels) }
}

@MainActor final class SelectedCaptureMicrophoneTests: XCTestCase {
    override func tearDown() { PowerAdmission.shared.setAllowed(true) }
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        throw NSError(domain: "Microphone capture fixture timed out", code: 1)
    }
    private func selection() -> SelectedAppCaptureSelection {
        .init(epoch: "fixture:1", activationID: UUID(), name: "Fixture", target: .init(responsiblePID: 123, appID: "own.fixture", processes: [.init(objectID: 8, actualPID: 124)]))
    }
    private func microphone(_ uid: String = "own.physical.microphone", rate: Double = 48000, channels: UInt32 = 1) -> LabVoice.AudioHardwareDevice {
        .init(uid: uid, name: "Fixture microphone", alive: 1, nominalRate: rate, input: .init(channels: channels), output: .init(channels: 0))
    }
    private func fixture() -> (URL, LibraryLocation, RecordingStorage) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "dual-capture-tests-" + UUID().uuidString, prefs = UserDefaults(suiteName: suite)!
        addTeardownBlock { prefs.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        return (root, LibraryLocation(defaults: prefs, defaultRoot: root.appendingPathComponent("library")),
                RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: root.appendingPathComponent("library")))
    }
    func testAppOnlyNeverChecksOrRequestsMicrophonePermission() async throws {
        let (_, location, storage) = fixture(), child = SelectedCaptureFixtureChild(), target = selection()
        var checks = 0, requests = 0, inspections = 0
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: AudioCaptureAdmission(), factory: { child }, selection: { target },
            currentMicrophone: { nil }, inspectMicrophone: { _ in inspections += 1; return nil },
            authorization: { checks += 1; return .notDetermined }, requestAuthorization: { requests += 1; return false })
        XCTAssertFalse(model.includesMicrophone); model.start(); try await wait { child.running }; child.started()
        let stopped = await model.stop(); XCTAssertTrue(stopped)
        XCTAssertEqual(checks, 0); XCTAssertEqual(requests, 0); XCTAssertEqual(inspections, 0)
        XCTAssertFalse(child.arguments.contains("--microphone-uid")); XCTAssertNotNil(model.savedSessionID)
    }
    func testExplicitDualModeUsesPermissionFreshDeviceAndTypedSavedProvenance() async throws {
        let (root, location, storage) = fixture(), child = SelectedCaptureFixtureChild(), target = selection(), mic = microphone(channels: 8)
        var inspections = 0, requests = 0
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: AudioCaptureAdmission(), factory: { child }, selection: { target },
            currentMicrophone: { mic }, inspectMicrophone: { uid in inspections += 1; XCTAssertEqual(uid, mic.uid); return mic },
            authorization: { .notDetermined }, requestAuthorization: { requests += 1; return true })
        model.setIncludesMicrophone(true); XCTAssertEqual(child.launches, 0); XCTAssertEqual(requests, 0)
        model.start(); try await wait { child.running }; XCTAssertEqual(requests, 1); XCTAssertEqual(inspections, 1)
        XCTAssertEqual(child.microphoneUID, mic.uid); child.started()
        let manifestURL = URL(fileURLWithPath: child.path).deletingLastPathComponent().appendingPathComponent("job.json")
        try await wait { (try? JSONDecoder().decode(RecordingJob.self, from: Data(contentsOf: manifestURL)))?.captureAdmissionVerified == true }
        let admitted = try JSONDecoder().decode(RecordingJob.self, from: Data(contentsOf: manifestURL))
        XCTAssertEqual(admitted.recordingSource?.microphoneObjectID, 42)
        let stopped = await model.stop(); XCTAssertTrue(stopped)
        let saved = try XCTUnwrap(LocalStore(root: root.appendingPathComponent("library")).inventory().sessions.first)
        XCTAssertEqual(saved.recordingSource?.kind, "selected_app_output_and_microphone")
        XCTAssertEqual(saved.recordingSource?.microphoneUID, mic.uid); XCTAssertEqual(saved.recordingSource?.microphoneObjectID, 42)
        XCTAssertEqual(saved.recordingSource?.microphoneChannel, 0)
        XCTAssertEqual(saved.recordingSource?.mixPolicy, "app_half_mic_half")
        XCTAssertEqual(saved.recordingSource?.timelinePolicy, "adjacent_host_anchors_common_overlap")
        XCTAssertTrue(saved.title.hasPrefix("Call audio: Fixture"))
    }
    func testSelectionModeUIDAndPowerChangesDuringPermissionNeverLaunch() async throws {
        for change in ["selection", "mode", "uid", "power"] {
            let (_, location, storage) = fixture(), child = SelectedCaptureFixtureChild(), gate = CapturePermissionGate(), admission = AudioCaptureAdmission()
            var selected: SelectedAppCaptureSelection? = selection(), mic = microphone(), inspections = 0
            let model = SelectedAppCaptureController(storage: storage, location: location, admission: admission, factory: { child }, selection: { selected },
                currentMicrophone: { mic }, inspectMicrophone: { _ in inspections += 1; return mic },
                authorization: { .notDetermined }, requestAuthorization: { await gate.request() })
            model.setIncludesMicrophone(true); model.start(); try await wait { gate.pending != nil }
            XCTAssertFalse(admission.available)
            switch change {
            case "selection": selected = nil; model.revalidate()
            case "mode": model.setIncludesMicrophone(false)
            case "uid": mic = microphone("different.microphone"); model.revalidate()
            default: PowerAdmission.shared.setAllowed(false); model.revokeForPowerEvent()
            }
            gate.resolve(true); try await wait { !model.engaged }
            XCTAssertEqual(child.launches, 0, change); XCTAssertEqual(inspections, 0, change)
            XCTAssertNil(model.savedSessionID); XCTAssertTrue(location.activities.isEmpty)
            PowerAdmission.shared.setAllowed(true); XCTAssertTrue(admission.available)
        }
    }
    func testUnconfirmedInspectionCleanupHoldsCaptureLeaseUntilRetry() async throws {
        let (_, location, storage) = fixture(), child = SelectedCaptureFixtureChild(), target = selection(), mic = microphone()
        let gate = CaptureInspectionGate(), admission = AudioCaptureAdmission()
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: admission, factory: { child }, selection: { target },
            currentMicrophone: { mic }, inspectMicrophone: { try await gate.inspect($0) }, stopMicrophoneInspection: { gate.stop() }, authorization: { .authorized })
        model.setIncludesMicrophone(true); model.start(); try await wait { gate.pending != nil }
        let stopped = await model.stop(); XCTAssertFalse(stopped)
        XCTAssertTrue(model.engaged); XCTAssertFalse(admission.available); XCTAssertEqual(child.launches, 0)
        gate.canDrain = true
        let retried = await model.stop(); XCTAssertTrue(retried)
        XCTAssertFalse(model.engaged); XCTAssertTrue(admission.available); XCTAssertEqual(child.launches, 0)
        XCTAssertTrue(location.activities.isEmpty)
    }
    func testDeniedPermissionAndChangedFreshDeviceFailBeforeFilesOrCapture() async throws {
        for denied in [true, false] {
            let (root, location, storage) = fixture(), child = SelectedCaptureFixtureChild(), target = selection(), mic = microphone()
            var requests = 0
            let model = SelectedAppCaptureController(storage: storage, location: location, admission: AudioCaptureAdmission(), factory: { child }, selection: { target },
                currentMicrophone: { mic }, inspectMicrophone: { _ in self.microphone(rate: 44100) },
                authorization: { denied ? .denied : .authorized }, requestAuthorization: { requests += 1; return true })
            model.setIncludesMicrophone(true); model.start(); try await wait { !model.engaged }
            XCTAssertEqual(child.launches, 0); XCTAssertEqual(requests, 0); XCTAssertNotNil(model.error)
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("staging").path))
        }
    }
    func testUnsupportedCachedRateAndOwnVirtualMicrophoneCannotStart() {
        let (_, location, storage) = fixture(), child = SelectedCaptureFixtureChild(), target = selection()
        var mic = microphone(rate: 44100), requests = 0
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: AudioCaptureAdmission(), factory: { child }, selection: { target },
            currentMicrophone: { mic }, authorization: { .notDetermined }, requestAuthorization: { requests += 1; return true })
        model.setIncludesMicrophone(true); XCTAssertFalse(model.canStart); model.start()
        mic = microphone("dev.hari.labvoice.microphone"); XCTAssertFalse(model.canStart); model.start()
        XCTAssertEqual(child.launches, 0); XCTAssertEqual(requests, 0)
    }
    func testFailedMicPreparationPreservesNativeErrorWithoutActualDeviceIdentity() async throws {
        let (_, location, storage) = fixture(), child = SelectedCaptureFixtureChild(), target = selection(), mic = microphone()
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: AudioCaptureAdmission(), factory: { child }, selection: { target },
            currentMicrophone: { mic }, inspectMicrophone: { _ in mic }, authorization: { .authorized })
        model.setIncludesMicrophone(true); model.start(); try await wait { child.running }
        var result = child.envelope("app_capture_result")
        result["microphone_object_id"] = nil; result["microphone_source_format"] = nil
        result["status"] = "failed"; result["path"] = child.path; result["frames"] = 0
        result["cleanup_verified"] = true; result["error"] = "microphone_not_physical"
        child.raw(result); child.finish(); try await wait { !model.engaged }
        XCTAssertEqual(model.error, "microphone_not_physical"); XCTAssertNil(model.savedSessionID)
    }
    func testWrongMicrophoneOrMixEchoIsNeverSaved() async throws {
        for wrongUID in [true, false] {
            let (_, location, storage) = fixture(), child = SelectedCaptureFixtureChild(), target = selection(), mic = microphone()
            let model = SelectedAppCaptureController(storage: storage, location: location, admission: AudioCaptureAdmission(), factory: { child }, selection: { target },
                currentMicrophone: { mic }, inspectMicrophone: { _ in mic }, authorization: { .authorized })
            model.setIncludesMicrophone(true); model.start(); try await wait { child.running }
            if wrongUID { child.microphoneUID = "wrong.microphone" } else { child.mixPolicy = "wrong_mix" }
            child.started(); try await wait { !model.engaged }
            XCTAssertNil(model.savedSessionID); XCTAssertEqual(model.retainedPaths.count, 1)
        }
    }
    func testDurableAdmissionAndLaterInvalidationAreSerializedBeforeRetention() async throws {
        let (_, location, base) = fixture(), child = SelectedCaptureFixtureChild(), target = selection(), mic = microphone()
        let storage = CaptureMetadataGateStorage(base)
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: AudioCaptureAdmission(), factory: { child }, selection: { target },
            currentMicrophone: { mic }, inspectMicrophone: { _ in mic }, authorization: { .authorized })
        model.setIncludesMicrophone(true); model.start(); try await wait { child.running }; child.started()
        for _ in 0..<2000 { if await storage.waiting() { break }; try await Task.sleep(nanoseconds: 1_000_000) }
        child.started(wrongTarget: true)
        await storage.resume(); try await wait { !model.engaged }
        let states = await storage.savedStates(); XCTAssertEqual(states, [true, false])
        let retained = try XCTUnwrap(model.retainedPaths.first)
        let job = try JSONDecoder().decode(RecordingJob.self, from: Data(contentsOf: URL(fileURLWithPath: retained).appendingPathComponent("job.json")))
        XCTAssertEqual(job.captureAdmissionVerified, false)
        XCTAssertNil(model.savedSessionID)
    }
    func testMetadataPersistenceFailureStopsWithoutVerifiedRecoveryClaim() async throws {
        let (_, location, base) = fixture(), child = SelectedCaptureFixtureChild(), target = selection(), mic = microphone()
        let model = SelectedAppCaptureController(storage: CaptureMetadataGateStorage(base, failWrites: true), location: location, admission: AudioCaptureAdmission(), factory: { child }, selection: { target },
            currentMicrophone: { mic }, inspectMicrophone: { _ in mic }, authorization: { .authorized })
        model.setIncludesMicrophone(true); model.start(); try await wait { child.running }; child.started()
        try await wait { !model.engaged }
        XCTAssertNil(model.savedSessionID)
        let retained = try XCTUnwrap(model.retainedPaths.first)
        let job = try JSONDecoder().decode(RecordingJob.self, from: Data(contentsOf: URL(fileURLWithPath: retained).appendingPathComponent("job.json")))
        XCTAssertEqual(job.captureAdmissionVerified, false)
    }
    func testModeChangeFinalizesOldDualModeAndRetainedRecoveryKeepsMicIdentity() async throws {
        let (root, location, storage) = fixture(), child = SelectedCaptureFixtureChild(), target = selection(), mic = microphone()
        child.cleanup = false
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: AudioCaptureAdmission(), factory: { child }, selection: { target },
            currentMicrophone: { mic }, inspectMicrophone: { _ in mic }, authorization: { .authorized })
        model.setIncludesMicrophone(true); model.start(); try await wait { child.running }; child.started()
        model.setIncludesMicrophone(false); try await wait { !model.engaged }
        XCTAssertNil(model.savedSessionID); XCTAssertEqual(child.stopCommands, 1)
        let retained = try XCTUnwrap(model.retainedPaths.first)
        let job = try JSONDecoder().decode(RecordingJob.self, from: Data(contentsOf: URL(fileURLWithPath: retained).appendingPathComponent("job.json")))
        XCTAssertEqual(job.recordingSource?.microphoneObjectID, 42)
        let recovery = RecordingRecovery(stagingRoot: root.appendingPathComponent("staging"))
        let candidates = try await recovery.scan(), candidate = try XCTUnwrap(candidates.first)
        let saved = try await recovery.saveCopy(candidate, to: location.snapshot)
        XCTAssertEqual(saved.session.recordingSource?.microphoneUID, mic.uid)
        XCTAssertEqual(saved.session.recordingSource?.microphoneObjectID, 42)
        XCTAssertTrue(saved.session.title.hasPrefix("Recovered call audio: Fixture"))
    }
}
