import XCTest
import Foundation
import LocalStore
import AVFoundation
@testable import LabVoice

@MainActor final class SelectedCaptureFixtureChild: AudioHelperChild {
    var running = false, drains = true, cleanup = true
    var launches = 0, stopCommands = 0
    var microphoneUID: String?
    var microphoneObjectID: UInt32 = 42
    var mixPolicy = "app_half_mic_half"
    var arguments: [String] = []
    private var line: ((String) -> Void)?, exit: ((HelperExit) -> Void)?
    private(set) var target: [String: Any] = [:]
    private(set) var operation = "", path = ""
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        self.arguments = arguments; self.line = line; self.exit = exit; running = true; launches += 1
        XCTAssertEqual(arguments[0], "--capture-selected-app")
        XCTAssertFalse(arguments.contains("--route")); XCTAssertFalse(arguments.contains("--input"))
        operation = arguments[2]; path = arguments[6]
        target = try JSONSerialization.jsonObject(with: Data(arguments[4].utf8)) as! [String: Any]
        if let index = arguments.firstIndex(of: "--microphone-uid") { microphoneUID = arguments[index + 1] }
    }
    func raw(_ object: [String: Any]) { line?(String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)) }
    func envelope(_ event: String) -> [String: Any] {
        var value: [String: Any] = ["version": 1, "event": event, "operation_id": operation, "target": target,
            "source": microphoneUID == nil ? "selected_app_output" : "selected_app_output_and_microphone",
            "sample_rate": 48000, "channels": 2, "pcm_format": "pcm16", "source_format": ["sample_rate": 44100, "channels": 2]]
        if let microphoneUID {
            value["microphone_uid"] = microphoneUID; value["microphone_object_id"] = microphoneObjectID
            value["microphone_source_format"] = ["sample_rate": 48000, "channels": 1]
            value["mix_policy"] = mixPolicy; value["timeline_policy"] = "adjacent_host_anchors_common_overlap"
        }
        return value
    }
    func started(wrongTarget: Bool = false) {
        var object = envelope("app_capture_started")
        if wrongTarget { object["target"] = ["responsible_pid": 1, "app_id": "wrong", "processes": [["object_id": 2, "actual_pid": 3]]] }
        raw(object)
    }
    func complete(exit shouldExit: Bool = true) throws {
        var bytes = Data()
        func tag(_ value: String) { bytes.append(contentsOf: value.utf8) }
        func u32(_ value: UInt32) { for shift in stride(from: 0, to: 32, by: 8) { bytes.append(UInt8((value >> shift) & 255)) } }
        func u16(_ value: UInt16) { bytes.append(UInt8(value & 255)); bytes.append(UInt8(value >> 8)) }
        tag("RIFF"); u32(36 + 480 * 4); tag("WAVEfmt "); u32(16); u16(1); u16(2); u32(48000); u32(192000); u16(4); u16(16)
        tag("data"); u32(480 * 4); bytes.append(Data(repeating: 0, count: 480 * 4))
        XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: bytes, attributes: [.posixPermissions: 0o600]))
        var event = envelope("app_capture_result")
        event["status"] = "completed"; event["path"] = path; event["frames"] = 480; event["cleanup_verified"] = cleanup
        raw(event)
        if shouldExit { finish() }
    }
    func send(_ data: Data) throws {
        XCTAssertEqual(data, Data("stop\n".utf8)); stopCommands += 1
        if drains { try complete() }
    }
    func finish() { running = false; exit?(.init(status: 0, output: Data(), diagnostic: "")) }
    func terminate() { if drains { finish() } }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { !running }
}
private actor DelayedSelectedCaptureStorage: RecordingStoring {
    let base: RecordingStorage
    var pending: CheckedContinuation<Void, Never>?
    init(_ base: RecordingStorage) { self.base = base }
    func prepare(operationID: UUID, location: LibraryLocationSnapshot) async throws -> RecordingJob {
        await withCheckedContinuation { pending = $0 }
        return try await base.prepare(operationID: operationID, location: location)
    }
    func waiting() -> Bool { pending != nil }
    func resume() { pending?.resume(); pending = nil }
    func persistMetadata(_ job: RecordingJob) async throws { try await base.persistMetadata(job) }
    func retainedDirectories() async throws -> [String] { try await base.retainedDirectories() }
    func retainFailure(_ job: RecordingJob, message: String) async throws { try await base.retainFailure(job, message: message) }
    func releaseDestination(_ job: RecordingJob) async { await base.releaseDestination(job) }
    func saveCompleted(_ job: RecordingJob, path: String, frames: UInt64, sampleRate: Double, channels: UInt32) async throws -> RecordingSave {
        try await base.saveCompleted(job, path: path, frames: frames, sampleRate: sampleRate, channels: channels)
    }
}

@MainActor final class SelectedAppCaptureTests: XCTestCase {
    override func tearDown() { PowerAdmission.shared.setAllowed(true) }
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Selected capture fixture did not progress")
    }
    private func selection() -> SelectedAppCaptureSelection {
        .init(epoch: "epoch", activationID: UUID(), name: "Fixture App", target: .init(responsiblePID: 123, appID: "own.fixture", processes: [.init(objectID: 8, actualPID: 124)]))
    }
    private func fixture() -> (URL, UserDefaults, String, LibraryLocation, RecordingStorage) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "selected-capture-tests-" + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        let location = LibraryLocation(defaults: defaults, defaultRoot: root.appendingPathComponent("library"))
        let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: root.appendingPathComponent("library"))
        return (root, defaults, suite, location, storage)
    }
    func testExplicitSelectedSourceImportRequiresStartedResultAndDrainedExit() async throws {
        let (root, prefs, suite, location, storage) = fixture()
        defer { prefs.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let child = SelectedCaptureFixtureChild(), admission = AudioCaptureAdmission(), target = selection()
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: admission, factory: { child }, selection: { target })
        XCTAssertEqual(child.launches, 0); XCTAssertTrue(model.canStart)
        model.start(); try await wait { child.running }; XCTAssertEqual(admission.owner, .selectedAppRecording)
        let manifest = try JSONDecoder().decode(RecordingJob.self, from: Data(contentsOf: URL(fileURLWithPath: child.path).deletingLastPathComponent().appendingPathComponent("job.json")))
        XCTAssertEqual(manifest.recordingSource?.appID, target.target.appID)
        child.started(); XCTAssertEqual(model.phase, .recording)
        try child.complete(exit: false); XCTAssertNil(model.savedSessionID); XCTAssertTrue(model.engaged)
        child.finish(); try await wait { !model.engaged }
        XCTAssertNotNil(model.savedSessionID); XCTAssertTrue(admission.available); XCTAssertTrue(location.activities.isEmpty)
        let saved = try XCTUnwrap(LocalStore(root: root.appendingPathComponent("library")).inventory().sessions.first)
        XCTAssertEqual(saved.recordingSource?.kind, "selected_app_output")
        XCTAssertEqual(saved.recordingSource?.appID, target.target.appID)
        XCTAssertEqual(saved.recordingSource?.processes.first?.objectID, 8)
        XCTAssertTrue(saved.title.hasPrefix("Selected app audio: Fixture App")); XCTAssertEqual(saved.durationSeconds, 0.01)
    }
    func testChangingSelectionDuringPreparationPreventsHelperLaunchAndRetainsJob() async throws {
        let (root, prefs, suite, location, base) = fixture()
        defer { prefs.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let storage = DelayedSelectedCaptureStorage(base), child = SelectedCaptureFixtureChild(), admission = AudioCaptureAdmission()
        var current: SelectedAppCaptureSelection? = selection()
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: admission, factory: { child }, selection: { current })
        model.start()
        for _ in 0..<2000 { if await storage.waiting() { break }; try await Task.sleep(nanoseconds: 1_000_000) }
        current = nil; model.revalidate(); await storage.resume(); try await wait { !model.engaged }
        XCTAssertEqual(child.launches, 0); XCTAssertNil(model.savedSessionID); XCTAssertEqual(model.retainedPaths.count, 1)
        XCTAssertTrue(admission.available); XCTAssertTrue(location.activities.isEmpty)
    }
    func testSourceSelectionLossFinalizesOwnedAudioAndManualOwnerBlocksStart() async throws {
        let (root, prefs, suite, location, storage) = fixture()
        defer { prefs.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let child = SelectedCaptureFixtureChild(), admission = AudioCaptureAdmission(), manual = UUID()
        var current: SelectedAppCaptureSelection? = selection()
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: admission, factory: { child }, selection: { current })
        XCTAssertTrue(admission.acquire(manual, owner: .route)); model.start(); XCTAssertEqual(child.launches, 0)
        XCTAssertEqual(admission.operationID, manual); admission.release(manual)
        model.start(); try await wait { child.running }; child.started()
        current = nil; model.revalidate(); try await wait { !model.engaged }
        XCTAssertEqual(child.stopCommands, 1); XCTAssertNotNil(model.savedSessionID)
        XCTAssertTrue(admission.available)
    }
    func testLateStartForSupersededSelectionIsRetainedWithoutSavedClaim() async throws {
        let (root, prefs, suite, location, storage) = fixture()
        defer { prefs.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let child = SelectedCaptureFixtureChild(), admission = AudioCaptureAdmission()
        var current: SelectedAppCaptureSelection? = selection()
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: admission, factory: { child }, selection: { current })
        model.start(); try await wait { child.running }; current = selection(); child.started()
        try await wait { !model.engaged }
        XCTAssertNil(model.savedSessionID); XCTAssertEqual(model.retainedPaths.count, 1)
        XCTAssertTrue(admission.available)
    }
    func testUncertainLiveStopKeepsAdmissionUntilRetryAndCleanupFailureNeverImports() async throws {
        let (root, prefs, suite, location, storage) = fixture()
        defer { prefs.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let child = SelectedCaptureFixtureChild(), admission = AudioCaptureAdmission(), target = selection()
        child.drains = false
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: admission, factory: { child }, selection: { target }, timeout: 100_000_000)
        model.start(); try await wait { child.running }; child.started()
        let stopped = await model.stop(); XCTAssertFalse(stopped); XCTAssertTrue(model.engaged); XCTAssertFalse(admission.available)
        child.drains = true; child.cleanup = false
        let retried = await model.stop(); XCTAssertTrue(retried); XCTAssertFalse(model.engaged)
        XCTAssertTrue(admission.available); XCTAssertNil(model.savedSessionID); XCTAssertEqual(model.retainedPaths.count, 1)
    }
    func testOldSourceCallbacksCannotAffectReplacementCaptureOperation() async throws {
        let (root, prefs, suite, location, storage) = fixture()
        defer { prefs.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let first = SelectedCaptureFixtureChild(), second = SelectedCaptureFixtureChild(), admission = AudioCaptureAdmission(), target = selection()
        var launches = 0
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: admission, factory: {
            launches += 1; return launches == 1 ? first : second
        }, selection: { target })
        model.start(); try await wait { first.running }; first.started()
        let stopped = await model.stop(); XCTAssertTrue(stopped); XCTAssertFalse(model.engaged)
        model.start(); try await wait { second.running }; second.started()
        first.started(wrongTarget: true); first.finish()
        XCTAssertEqual(model.phase, .recording); XCTAssertTrue(second.running); XCTAssertEqual(second.stopCommands, 0)
        let finalStop = await model.stop(); XCTAssertTrue(finalStop); XCTAssertNotNil(model.savedSessionID)
    }
    func testPowerSuspensionFinalizesOwnedSourceAndResumeDoesNotRestart() async throws {
        let (root, prefs, suite, location, storage) = fixture()
        defer { prefs.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let child = SelectedCaptureFixtureChild(), admission = AudioCaptureAdmission(), target = selection()
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: admission, factory: { child }, selection: { target })
        model.start(); try await wait { child.running }; child.started()
        let power = AppPowerLifecycle(revoke: { model.revokeForPowerEvent() }, suspend: { await model.suspendForPowerEvent() }, resume: { nil })
        power.request(.suspend); await power.waitUntilSettled()
        XCTAssertEqual(power.state, .suspended); XCTAssertFalse(model.engaged)
        XCTAssertNotNil(model.savedSessionID); XCTAssertTrue(location.activities.isEmpty)
        XCTAssertFalse(model.canStart)
        power.request(.resume); await power.waitUntilSettled()
        XCTAssertEqual(child.launches, 1); XCTAssertTrue(model.canStart)
    }
    func testWrongTargetEchoStopsBeforeAdmittingCapture() async throws {
        let (root, prefs, suite, location, storage) = fixture()
        defer { prefs.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let child = SelectedCaptureFixtureChild(), target = selection()
        let model = SelectedAppCaptureController(storage: storage, location: location, admission: AudioCaptureAdmission(), factory: { child }, selection: { target })
        model.start(); try await wait { child.running }; child.started(wrongTarget: true)
        try await wait { !model.engaged }; XCTAssertNil(model.savedSessionID); XCTAssertEqual(model.retainedPaths.count, 1)
    }
}

final class SelectedAppCaptureTargetTests: XCTestCase {
    private func row(_ object: UInt32, actual: Int, active: Bool = true, fallback: Bool = false, pending: Bool = false,
                     appID: String = "own.fixture") -> AudioProcessUsage {
        .init(objectID: object, actualPID: actual, responsiblePID: 123, responsiblePIDFallback: fallback,
              responsiblePIDResolution: "responsibility_lookup", appName: "Fixture App", appID: appID,
              processBundleID: appID, responsibleBundleID: appID, usageStale: false, stabilizationPending: pending,
              input: .init(running: true, devices: [.init(objectID: 10, uid: "physical", hasInputStreams: true)]),
              output: .init(running: active, devices: active ? [.init(objectID: 20, uid: "physical", hasInputStreams: false)] : []), errors: [])
    }
    private func policy() -> LocalCallPolicy {
        var policy = LocalCallPolicy(); policy.reset()
        policy.add(name: "Fixture App", usage: .init(pid: 123, actualPids: "124,125", deviceID: "10", isVirtual: false), direction: .input, now: 0, appID: "own.fixture")
        policy.add(name: "Fixture App", usage: .init(pid: 123, actualPids: "124,125", deviceID: "20", isVirtual: false), direction: .output, now: 0)
        return policy
    }
    private func make(_ rows: [AudioProcessUsage], policy: LocalCallPolicy? = nil, stale: Bool = false) -> SelectedAppCaptureSelection? {
        .make(policy: policy ?? self.policy(), snapshot: .init(status: "available", errors: [], processes: rows), epoch: "fixture:1", stale: stale)
    }
    func testLegacyRecordingJobWithoutSourceStillDecodes() throws {
        let job = RecordingJob(id: UUID(), operationID: UUID(), directory: URL(fileURLWithPath: "/private/tmp/legacy-recording"), startedAt: Date(), libraryLocation: nil)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(job)) as? [String: Any])
        object.removeValue(forKey: "recordingSource")
        let decoded = try JSONDecoder().decode(RecordingJob.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.id, job.id); XCTAssertNil(decoded.recordingSource)
        XCTAssertTrue(decoded.title.hasPrefix("Route recording "))
    }
    func testRawIdentitySelectsOnlyCurrentActiveOutputTuples() {
        let target = make([row(8, actual: 124), row(9, actual: 125, active: false)])
        XCTAssertEqual(target?.target.responsiblePID, 123)
        XCTAssertEqual(target?.target.processes, [.init(objectID: 8, actualPID: 124)])
        XCTAssertNil(make([row(8, actual: 124)], stale: true))
        var blocked = policy(); blocked.setBlocked("Fixture App", blocked: true)
        XCTAssertNil(make([row(8, actual: 124)], policy: blocked))
    }
    func testAmbiguousOrUnvalidatedTargetsAreRejectedBeforeCapture() {
        XCTAssertNil(make([row(8, actual: 124, fallback: true)]))
        XCTAssertNil(make([row(8, actual: 124, pending: true)]))
        XCTAssertNil(make([row(8, actual: 124), row(9, actual: 124)]))
        XCTAssertNil(make([row(8, actual: 124), row(8, actual: 125)]))
        XCTAssertNil(make([row(8, actual: 124, appID: "other.app")]))
        XCTAssertNil(make((1...33).map { row(UInt32($0), actual: 1000 + $0) }))
        var ambiguous = policy()
        ambiguous.add(name: "Fixture App", usage: .init(pid: 999, actualPids: "1000", deviceID: "20", isVirtual: false), direction: .output, now: 0)
        XCTAssertNil(make([row(8, actual: 124)], policy: ambiguous))
    }
}

@MainActor final class SelectedAppCaptureQuitTests: XCTestCase {
    func testPriorManualSaveDoesNotSatisfyFailedSelectedAppSave() async {
        var active = true
        let quit = QuitCoordinator(snapshot: {
            QuitSnapshot(recordingActive: false, audioEngaged: false, testEngaged: false, otherWork: false,
                         additionalRecordingActive: active, additionalRecordingSaved: false,
                         additionalRecordingFailure: "Selected app save failed", recordingSaved: true)
        }, confirmSave: { true }, stopAudio: { active = false; return true }, cleanupTest: { true }, gate: QuitGate())
        let approved = await quit.request()
        XCTAssertFalse(approved); XCTAssertEqual(quit.reason, "Selected app save failed")
    }
}
