import XCTest
@testable import LabVoice

@MainActor final class RelaunchTests: XCTestCase {
    private let bundle = URL(fileURLWithPath: "/fixture/Lab Voice.app")
    private var executable: URL { bundle.appendingPathComponent("Contents/MacOS/LabVoice") }
    private func idle() -> QuitSnapshot { .init(recordingActive: false, audioEngaged: false, testEngaged: false, otherWork: false) }
    func testExactFreshBundleAllowsAbsentOptionalExecutable() async {
        var calls = 0
        let launcher = OwnAppRelauncher(bundleURL: bundle, executableURL: executable, currentPID: 100, existingPIDs: { [100, 101] }, open: { url, fresh in
            calls += 1; XCTAssertEqual(url, self.bundle); XCTAssertTrue(fresh)
            return .application(.init(pid: 102, bundleURL: url, executableURL: nil, terminated: false))
        })
        let result = await launcher.launch(); XCTAssertEqual(result, .confirmed); XCTAssertEqual(calls, 1)
    }
    func testExistingWrongOrMissingReturnedIdentityIsUncertain() async {
        for application in [
            RelaunchApplication(pid: 100, bundleURL: bundle, executableURL: executable, terminated: false),
            .init(pid: 101, bundleURL: bundle, executableURL: executable, terminated: false),
            .init(pid: 102, bundleURL: URL(fileURLWithPath: "/wrong.app"), executableURL: executable, terminated: false),
            .init(pid: 102, bundleURL: bundle, executableURL: URL(fileURLWithPath: "/wrong"), terminated: false),
            .init(pid: 102, bundleURL: nil, executableURL: executable, terminated: false),
            .init(pid: 102, bundleURL: bundle, executableURL: executable, terminated: true)
        ] {
            let launcher = OwnAppRelauncher(bundleURL: bundle, executableURL: executable, currentPID: 100, existingPIDs: { [100, 101] }, open: { _, _ in .application(application) })
            if case .uncertain = await launcher.launch() {} else { XCTFail("Not a confirmed fresh exact instance") }
        }
    }
    func testLaunchFailureReopensAdmissionAndAllowsExplicitRetry() async {
        let gate = QuitGate(); var launches = 0
        let coordinator = QuitCoordinator(snapshot: idle, confirmSave: { true }, stopAudio: { true }, cleanupTest: { true }, gate: gate,
            launchForRelaunch: { launches += 1; return launches == 1 ? .failed("fixture launch error") : .confirmed })
        let failed = await coordinator.request(intent: .relaunch)
        XCTAssertFalse(failed); XCTAssertFalse(gate.quitting); XCTAssertFalse(coordinator.relaunchUncertain)
        let work = gate.beginWork(); XCTAssertNotNil(work); gate.endWork(work!)
        let retried = await coordinator.request(intent: .relaunch)
        XCTAssertTrue(retried); XCTAssertTrue(gate.quitting); XCTAssertEqual(launches, 2)
    }
    func testUncertaintyBlocksRepeatButAllowsUseAndNormalQuit() async {
        let gate = QuitGate(); var launches = 0
        let coordinator = QuitCoordinator(snapshot: idle, confirmSave: { true }, stopAudio: { true }, cleanupTest: { true }, gate: gate,
            launchForRelaunch: { launches += 1; return .uncertain("fixture identity absent") })
        let uncertain = await coordinator.request(intent: .relaunch)
        XCTAssertFalse(uncertain); XCTAssertTrue(coordinator.relaunchUncertain); XCTAssertFalse(gate.quitting)
        let work = gate.beginWork(); XCTAssertNotNil(work); gate.endWork(work!)
        let duplicate = await coordinator.request(intent: .relaunch); XCTAssertFalse(duplicate); XCTAssertEqual(launches, 1)
        let quit = await coordinator.request(); XCTAssertTrue(quit); XCTAssertEqual(launches, 1)
    }
    func testPendingAndConfirmedLaunchCannotLaunchAgainBeforeExit() async {
        let gate = QuitGate(); var launches = 0; var resume: CheckedContinuation<RelaunchOutcome, Never>?
        let coordinator = QuitCoordinator(snapshot: idle, confirmSave: { true }, stopAudio: { true }, cleanupTest: { true }, gate: gate,
            launchForRelaunch: { launches += 1; return await withCheckedContinuation { resume = $0 } })
        let first = Task { await coordinator.request(intent: .relaunch) }
        for _ in 0..<1000 { if resume != nil { break }; await Task.yield() }
        XCTAssertNotNil(resume); XCTAssertTrue(gate.quitting)
        let pendingDuplicate = await coordinator.request(intent: .relaunch); XCTAssertFalse(pendingDuplicate)
        resume?.resume(returning: .confirmed); let approved = await first.value
        XCTAssertTrue(approved); XCTAssertTrue(gate.quitting)
        let completedDuplicate = await coordinator.request(intent: .relaunch)
        XCTAssertFalse(completedDuplicate); XCTAssertEqual(launches, 1)
    }
    func testCancelledRelaunchAndFailedShutdownNeverLaunch() async {
        for cancel in [true, false] {
            let gate = QuitGate(); var stops = 0, launches = 0
            let coordinator = QuitCoordinator(snapshot: { .init(recordingActive: true, audioEngaged: true, testEngaged: false, otherWork: false) },
                confirmSave: { XCTFail("Wrong prompt intent"); return true }, stopAudio: { stops += 1; return false }, cleanupTest: { true }, gate: gate,
                confirmRelaunchSave: { !cancel }, launchForRelaunch: { launches += 1; return .confirmed })
            let result = await coordinator.request(intent: .relaunch)
            XCTAssertFalse(result); XCTAssertFalse(gate.quitting); XCTAssertEqual(stops, cancel ? 0 : 1); XCTAssertEqual(launches, 0)
        }
    }
}
