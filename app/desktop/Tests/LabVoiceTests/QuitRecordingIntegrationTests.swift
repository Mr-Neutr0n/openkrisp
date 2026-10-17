import XCTest
import LocalStore
@testable import LabVoice

private actor QuitFailingRecordingStorage: RecordingStoring {
    private(set) var failures = 0
    private let storeRoot: URL?
    init(storeRoot: URL? = nil) { self.storeRoot = storeRoot }
    func prepare(operationID: UUID, location: LibraryLocationSnapshot) throws -> RecordingJob {
        .init(id: UUID(), operationID: operationID, directory: URL(fileURLWithPath: "/synthetic-quit-staging"), startedAt: Date(), libraryLocation: location)
    }
    func retainedDirectories() -> [String] { ["/synthetic-quit-staging"] }
    func retainFailure(_ job: RecordingJob, message: String) { failures += 1 }
    func saveCompleted(_ job: RecordingJob, path: String, frames: UInt64, sampleRate: Double, channels: UInt32) throws -> RecordingSave {
        guard let storeRoot else { throw StoreError.io(operation: "injected import failure", code: 5) }
        let session = try LocalStore(root: storeRoot).save(title: "Synthetic quit recording", startedAt: job.startedAt,
                                                         durationSeconds: Double(frames) / sampleRate, transcript: [])
        return RecordingSave(session: session, cleanupWarning: "Injected staging cleanup warning")
    }
}
@MainActor private final class QuitRecordingChild: AudioHelperChild {
    var running = false
    var arguments: [String] = []
    var line: ((String) -> Void)?
    var exit: ((HelperExit) -> Void)?
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        self.arguments = arguments; self.line = line; self.exit = exit; running = true
    }
    private func emit(_ object: [String: Any]) { line?(String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)) }
    func ready() {
        let index = arguments.firstIndex(of: "--operation-id")!
        emit(["event": "route_started", "operationID": arguments[index + 1], "input_uid": "mic", "output_uid": "speaker",
              "microphone_noise": false, "speaker_noise": false, "microphone_provider": "none", "speaker_provider": "none",
              "microphone": ["muted": false, "gain": 1], "speaker": ["muted": false, "gain": 1]])
    }
    func send(_ data: Data) throws {
        let command = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let type = command["type"] as? String, type.hasPrefix("recording-") else { return }
        let action = String(type.dropFirst(10))
        var ack = command; ack["type"] = "recording-ack"; ack["action"] = action; ack["accepted"] = true; ack.removeValue(forKey: "path")
        emit(ack)
        if action == "stop" {
            emit(["type": "recording-result", "operationID": command["operationID"]!, "recordingID": command["recordingID"]!,
                  "status": "completed", "path": "/synthetic-quit-staging/recording.wav", "frames": 480, "sampleRate": 48000, "channels": 2])
        }
    }
    func terminate() { running = false; exit?(.init(status: 0, output: Data(), diagnostic: "")) }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { !running }
}
@MainActor final class QuitRecordingIntegrationTests: XCTestCase {
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Injected lifecycle did not settle")
    }
    private func runningRecording(storage: QuitFailingRecordingStorage) async throws -> (AudioRouteController, RecordingController, LibraryLocation) {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let location = LibraryLocation(defaults: defaults, defaultRoot: URL(fileURLWithPath: "/synthetic-library"), inspect: { _ in })
        let recording = RecordingController(storage: storage, location: location)
        let inventory = try JSONDecoder().decode(AudioInventory.self, from: Data("""
        {"devices":[{"uid":"mic","name":"Mic","alive":1,"nominal_rate":48000,"input":{"channels":1},"output":{"channels":0}},{"uid":"speaker","name":"Speaker","alive":1,"nominal_rate":48000,"input":{"channels":0},"output":{"channels":2}}],"companion_devices":[{"uid":"dev.hari.labvoice.feed","present":true},{"uid":"dev.hari.labvoice.monitor","present":true}],"errors":[]}
        """.utf8))
        let child = QuitRecordingChild()
        let route = AudioRouteController(readInventory: { inventory }, authorization: { .authorized }, requestAuthorization: { XCTFail("No permission prompt expected"); return false }, factory: { child }, recording: recording)
        await route.refresh(); route.inputUID = "mic"; route.outputUID = "speaker"; route.start()
        try await wait { child.running }; child.ready(); XCTAssertEqual(route.phase, .running)
        recording.start(); try await wait { recording.phase == .recording }
        return (route, recording, location)
    }
    func testRouteStopDoesNotProveRecordingWasSaved() async throws {
        let storage = QuitFailingRecordingStorage()
        let (route, recording, location) = try await runningRecording(storage: storage)
        let stopped = await route.stop()
        XCTAssertTrue(stopped) // Process exit is a different fact from successful library publication.
        XCTAssertEqual(recording.phase, .idle); XCTAssertFalse(recording.busy)
        XCTAssertNil(recording.savedSessionID); XCTAssertNotNil(recording.error)
        let failures = await storage.failures; XCTAssertEqual(failures, 1)
        XCTAssertTrue(location.activities.isEmpty)
    }
    func testQuitRejectsActualImportFailureAfterCleanHelperExit() async throws {
        let (route, recording, location) = try await runningRecording(storage: QuitFailingRecordingStorage())
        let gate = QuitGate()
        var confirmations = 0
        let quit = QuitCoordinator(snapshot: {
            QuitSnapshot(recordingActive: recording.busy, audioEngaged: route.engaged, testEngaged: false,
                         otherWork: location.activities.values.contains { $0 != "Recording" },
                         recordingSaved: recording.savedSessionID != nil && !recording.busy,
                         recordingFailure: recording.savedSessionID == nil ? recording.error : nil)
        }, confirmSave: { confirmations += 1; return true }, stopAudio: { await route.stop() }, cleanupTest: { true }, gate: gate)
        let allowed = await quit.request()
        XCTAssertFalse(allowed); XCTAssertEqual(confirmations, 1)
        XCTAssertEqual(route.phase, .idle); XCTAssertNil(recording.savedSessionID)
        XCTAssertNotNil(quit.reason); XCTAssertFalse(gate.quitting)
    }
    func testQuitAcceptsPublishedRecordingDespiteNonfatalCleanupWarning() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (route, recording, location) = try await runningRecording(storage: QuitFailingRecordingStorage(storeRoot: root))
        let gate = QuitGate()
        let quit = QuitCoordinator(snapshot: {
            QuitSnapshot(recordingActive: recording.busy, audioEngaged: route.engaged, testEngaged: false,
                         otherWork: location.activities.values.contains { $0 != "Recording" },
                         recordingSaved: recording.savedSessionID != nil && !recording.busy,
                         recordingFailure: recording.savedSessionID == nil ? recording.error : nil)
        }, confirmSave: { true }, stopAudio: { await route.stop() }, cleanupTest: { true }, gate: gate)
        let allowed = await quit.request()
        XCTAssertTrue(allowed); XCTAssertNotNil(recording.savedSessionID)
        XCTAssertNotNil(recording.error) // Cleanup warning is not failed publication.
        XCTAssertNil(quit.reason); XCTAssertTrue(gate.quitting)
        XCTAssertEqual(try LocalStore(root: root).inventory().sessions.count, 1)
    }

}
