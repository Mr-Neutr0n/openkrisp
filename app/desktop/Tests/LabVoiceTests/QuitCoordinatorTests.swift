import XCTest
import AVFoundation
@testable import LabVoice

@MainActor final class QuitCoordinatorTests: XCTestCase {
    private func idle() -> QuitSnapshot { .init(recordingActive: false, audioEngaged: false, testEngaged: false, otherWork: false) }
    func testOtherWorkCancelsWithoutPromptOrInterruption() async {
        var state = idle(); state = .init(recordingActive: true, audioEngaged: true, testEngaged: false, otherWork: true)
        let gate = QuitGate()
        let quit = QuitCoordinator(snapshot: { state }, confirmSave: { XCTFail("Must finish work before prompting"); return true }, stopAudio: { XCTFail("Must not interrupt work"); return true }, cleanupTest: { XCTFail("Must not interrupt test"); return true }, gate: gate)
        let result = await quit.request()
        XCTAssertFalse(result)
        XCTAssertTrue(quit.reason?.contains("Finish") == true); XCTAssertFalse(gate.quitting)
    }
    func testCancelRecordingPromptReleasesGateAndDoesNotStop() async {
        let gate = QuitGate()
        let quit = QuitCoordinator(snapshot: { .init(recordingActive: true, audioEngaged: true, testEngaged: false, otherWork: false) }, confirmSave: { XCTAssertTrue(gate.quitting); return false }, stopAudio: { XCTFail("Cancel must not stop"); return true }, cleanupTest: { true }, gate: gate)
        let result = await quit.request()
        XCTAssertFalse(result); XCTAssertNil(quit.reason); XCTAssertFalse(gate.quitting)
        XCTAssertNotNil(gate.beginWork())
    }
    func testSuccessKeepsGateClosedAndOverlappingRequestDoesNotReplyEarly() async {
        let gate = QuitGate()
        var state = QuitSnapshot(recordingActive: true, audioEngaged: true, testEngaged: false, otherWork: false)
        var stopping: CheckedContinuation<Void, Never>?
        var stops = 0
        let quit = QuitCoordinator(snapshot: { state }, confirmSave: { true }, stopAudio: {
            stops += 1
            await withCheckedContinuation { stopping = $0 }
            state = self.idle(); state.recordingSaved = true
            return true
        }, cleanupTest: { true }, gate: gate)
        let first = Task { await quit.request() }
        for _ in 0..<1000 { if stopping != nil { break }; await Task.yield() }
        XCTAssertTrue(quit.inProgress); XCTAssertTrue(gate.quitting); XCTAssertNil(gate.beginWork())
        let duplicate = await quit.request(); XCTAssertFalse(duplicate); XCTAssertEqual(stops, 1)
        stopping?.resume(); let result = await first.value
        XCTAssertTrue(result); XCTAssertTrue(gate.quitting); XCTAssertNil(quit.reason)
    }
    func testUncertainStopAndMissingSaveProofKeepAppOpen() async {
        for failedStop in [true, false] {
            let gate = QuitGate()
            var state = QuitSnapshot(recordingActive: true, audioEngaged: true, testEngaged: false, otherWork: false)
            let quit = QuitCoordinator(snapshot: { state }, confirmSave: { true }, stopAudio: {
                state = self.idle(); state.recordingFailure = "Import failed; stage retained"
                state.stopFailure = "Helper exit uncertain"
                return !failedStop
            }, cleanupTest: { true }, gate: gate)
            let result = await quit.request(); XCTAssertFalse(result); XCTAssertFalse(gate.quitting)
            XCTAssertEqual(quit.reason, failedStop ? "Helper exit uncertain" : "Import failed; stage retained")
        }
    }
    func testTestCleanupFailureUsesItsOwnErrorAndNeverStopsUnrelatedAudio() async {
        var state = QuitSnapshot(recordingActive: false, audioEngaged: false, testEngaged: true, otherWork: false)
        state.stopFailure = "Old unrelated audio error"; state.testFailure = "Test cleanup failed"
        let gate = QuitGate()
        let quit = QuitCoordinator(snapshot: { state }, confirmSave: { XCTFail(); return false }, stopAudio: { XCTFail(); return true }, cleanupTest: { false }, gate: gate)
        let result = await quit.request(); XCTAssertFalse(result); XCTAssertEqual(quit.reason, "Test cleanup failed"); XCTAssertFalse(gate.quitting)
    }
    func testPendingDiagnosticWorkAndTokenIdentityPreventQuit() async {
        let gate = QuitGate(), first = gate.beginWork()!, second = gate.beginWork()!
        gate.endWork(first); gate.endWork(first)
        let quit = QuitCoordinator(snapshot: idle, confirmSave: { XCTFail(); return true }, stopAudio: { XCTFail(); return true }, cleanupTest: { XCTFail(); return true }, gate: gate)
        let result = await quit.request(); XCTAssertFalse(result); XCTAssertTrue(gate.hasPendingWork)
        gate.endWork(second)
        let token = gate.beginQuit()!; gate.cancelQuit(UUID()); XCTAssertTrue(gate.quitting)
        gate.cancelQuit(token); XCTAssertFalse(gate.quitting)
    }
    func testActualDiagnosticExportBlocksQuitAndReleasesWorkAfterFailure() async {
        var export: CheckedContinuation<Void, Error>?
        let diagnostics = DiagnosticsController(snapshot: { .init(audio: .idle, recording: .idle, library: .idle, microphoneTest: .idle, controls: .idle, sessionCount: 0) }, export: { _, _, _ in
            try await withCheckedThrowingContinuation { export = $0 }
        })
        let saving = Task { await diagnostics.save(to: URL(fileURLWithPath: "/unused-injected-export")) }
        for _ in 0..<1000 { if export != nil { break }; await Task.yield() }
        XCTAssertTrue(diagnostics.saving); XCTAssertTrue(QuitGate.shared.hasPendingWork)
        let quit = QuitCoordinator(snapshot: idle, confirmSave: { XCTFail(); return true }, stopAudio: { XCTFail(); return true }, cleanupTest: { XCTFail(); return true })
        let result = await quit.request(); XCTAssertFalse(result); XCTAssertFalse(QuitGate.shared.quitting)
        XCTAssertTrue(diagnostics.saving)
        export?.resume(throwing: CocoaError(.fileWriteNoPermission)); await saving.value
        XCTAssertTrue(diagnostics.failed); XCTAssertFalse(QuitGate.shared.hasPendingWork)
    }
    func testSharedGateBlocksRealCaptureRecordingLibraryAndDiagnosticEntries() async throws {
        let gate = QuitGate.shared, token = try XCTUnwrap(gate.beginQuit())
        defer { gate.cancelQuit(token) }
        XCTAssertFalse(AudioCaptureAdmission.shared.available)
        XCTAssertFalse(AudioCaptureAdmission.shared.acquire(UUID(), owner: .route))
        let defaults = UserDefaults(suiteName: "Quit-" + UUID().uuidString)!
        let location = LibraryLocation(defaults: defaults, defaultRoot: URL(fileURLWithPath: "/unused-quit-library"), inspect: { _ in XCTFail("No folder I/O") })
        XCTAssertFalse(location.canSwitch); XCTAssertThrowsError(try location.begin("Import"))
        let recording = RecordingController(location: location)
        var commands = 0
        recording.attach(operationID: UUID()) { _ in commands += 1 }
        recording.start(); XCTAssertEqual(recording.phase, .idle); XCTAssertEqual(commands, 0)
        let route = AudioRouteController(readInventory: { XCTFail("No helper inventory during quit"); throw AudioHelperError.missingHelper }, authorization: { XCTFail(); return .denied }, requestAuthorization: { XCTFail(); return false }, factory: { XCTFail(); throw AudioHelperError.missingHelper })
        await route.refresh(); XCTAssertFalse(route.loading)
        let microphone = MicrophoneTestController(authorization: { XCTFail(); return .denied }, factory: { XCTFail(); throw AudioHelperError.missingHelper })
        microphone.start(input: .init(uid: "synthetic", name: "Synthetic", alive: 1, nominalRate: 48000, input: .init(channels: 1), output: .init(channels: 0)), microphoneUnmuted: true, routeStopped: true)
        XCTAssertFalse(microphone.engaged)
        let diagnostics = DiagnosticsController(snapshot: { XCTFail("No report created"); return .init(audio: .idle, recording: .idle, library: .idle, microphoneTest: .idle, controls: .idle, sessionCount: 0) }, export: { _, _, _ in XCTFail("No export") })
        await diagnostics.save(to: URL(fileURLWithPath: "/unused-report"))
        XCTAssertTrue(diagnostics.failed); XCTAssertFalse(diagnostics.saving)
    }
}
