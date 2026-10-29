import XCTest
import CryptoKit
@testable import LabVoice

// Explicit local opt-in only. Observes native process properties and listeners;
// never starts a route, tap, IOProc, playback, recognition, or OS power event.
@MainActor final class StabilizedAudioUseIntegrationTests: XCTestCase {
    func testRealStabilizedHelperReachesProductionControllerAndStops() async throws {
        guard ProcessInfo.processInfo.environment["LABVOICE_TEST_STABILIZED_AUDIO_USE"] == "1" else {
            throw XCTSkip("Set LABVOICE_TEST_STABILIZED_AUDIO_USE=1 and pin LABVOICE_EXPECTED_AUDIO_HELPER_SHA256 for the read-only native integration test.")
        }
        let expected = ProcessInfo.processInfo.environment["LABVOICE_EXPECTED_AUDIO_HELPER_SHA256"] ?? ""
        guard expected.count == 64, expected.allSatisfy({ $0.isHexDigit }) else {
            XCTFail("An explicit frozen-helper SHA256 is required before native execution."); return
        }
        let desktop = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let helper = desktop.deletingLastPathComponent().appendingPathComponent("audio-host/build/audio-host")
        func hash() throws -> String { SHA256.hash(data: try Data(contentsOf: helper)).map { String(format: "%02x", $0) }.joined() }
        let before = try hash()
        guard before == expected.lowercased(), FileManager.default.isExecutableFile(atPath: helper.path) else {
            XCTFail("The own helper does not match the explicitly pinned executable."); return
        }
        let suite = "native-call-observation-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let calls = LocalCallController(defaults: defaults, automaticTimers: false)
        let child = ObservedNativeWatchChild(url: helper)
        let controller = AudioUseWatchController(factory: { child }, startupTimeout: 8_000_000_000, stopTimeout: 3_000_000_000, calls: calls)
        var thrown: Error?
        controller.start()
        do {
            let until = DispatchTime.now().uptimeNanoseconds + 9_000_000_000
            while controller.snapshot == nil && controller.engaged && DispatchTime.now().uptimeNanoseconds < until {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            XCTAssertEqual(controller.snapshot?.status, "available")
            XCTAssertEqual(controller.sourceState, "running"); XCTAssertEqual(controller.timingMode, "stabilized")
            XCTAssertEqual(controller.phase, .watching); XCTAssertFalse(controller.stale)
            XCTAssertTrue(controller.error == nil, "Source diagnostic present; contents intentionally not logged.")
            if let snapshot = controller.snapshot {
                let complete = AudioUsageGrouping.group(snapshot).complete && snapshot.processes.allSatisfy { $0.usageStale == false }
                XCTAssertEqual(calls.policy.fresh, complete)
                if complete {
                    XCTAssertTrue(controller.canRebaseCallTracking)
                    controller.rebaseCallTracking()
                    XCTAssertTrue(calls.policy.fresh)
                    XCTAssertTrue(calls.note.contains("Tracking refreshed"))
                    if let current = calls.policy.current {
                        XCTAssertTrue(calls.policy.calls.contains { $0.name == current && calls.policy.qualified($0) })
                    }
                } else { XCTAssertNil(calls.policy.current) }
            }
            XCTAssertTrue(controller.snapshot?.processes.allSatisfy { $0.usageStale != nil && $0.stabilizationPending != nil } == true)
        } catch { thrown = error }
        // Assertions do not bypass cleanup. A failed startup or cancelled test
        // still attempts bounded shutdown of this exact owned child.
        let stopped = await controller.stop()
        if !stopped {
            child.terminate()
            let fallbackDrained = await child.waitForExit(timeoutNanoseconds: 2_000_000_000)
            print("Native watch fallback process drain: \(fallbackDrained)")
        }
        XCTAssertTrue(stopped); XCTAssertFalse(controller.engaged); XCTAssertFalse(child.running)
        XCTAssertNil(calls.policy.current); XCTAssertFalse(calls.policy.fresh); XCTAssertNil(calls.policy.stopDeadline)
        XCTAssertTrue(controller.cleanupVerified)
        XCTAssertEqual(child.status, 0); XCTAssertEqual(child.retainedStdoutBytes, 0)
        XCTAssertEqual(child.diagnosticBytes, 0)
        XCTAssertNotNil(controller.allListenerRemovalsVerified)
        XCTAssertNotNil(controller.listenersRemoved); XCTAssertNotNil(controller.listenersInvalidObjectRetired); XCTAssertNotNil(controller.listenersRemoveFailed)
        XCTAssertEqual(controller.cleanDetachVerified, controller.allListenerRemovalsVerified == true)
        let after = try hash(); XCTAssertEqual(after, before)
        print("Own native helper SHA256: \(before)")
        print("Stabilized native readiness: status=\(controller.snapshot?.status ?? "missing") process_count=\(controller.snapshot?.processes.count ?? -1) partial_count=\(controller.snapshot?.processes.filter { !$0.errors.isEmpty || $0.usageStale == true }.count ?? -1) reason=\(controller.publicationReason ?? "missing") coalesced_total=\(controller.coalescedPublicationTotal)")
        print("Stabilized native shutdown: ownership_verified=\(controller.cleanupVerified) all_removals_verified=\(controller.allListenerRemovalsVerified.map(String.init) ?? "unknown") removed=\(controller.listenersRemoved.map(String.init) ?? "unknown") retired=\(controller.listenersInvalidObjectRetired.map(String.init) ?? "unknown") failed=\(controller.listenersRemoveFailed.map(String.init) ?? "unknown") status=\(child.status.map(String.init) ?? "unknown")")
        if let thrown { throw thrown }
    }
}

@MainActor private final class ObservedNativeWatchChild: AudioHelperChild {
    private let child: SystemAudioHelperChild
    private(set) var status: Int32?
    private(set) var retainedStdoutBytes: Int?
    private(set) var diagnosticBytes: Int?
    var running: Bool { child.running }
    init(url: URL) { child = SystemAudioHelperChild(url: url, outputMode: .streaming(maxLineBytes: 614400)) }
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        XCTAssertEqual(arguments, ["--watch-audio-use-stabilized"])
        try child.launch(arguments: arguments, line: line, exit: { [weak self] event in
            self?.status = event.status; self?.retainedStdoutBytes = event.output.count; self?.diagnosticBytes = event.diagnostic.utf8.count
            exit(event)
        })
    }
    func send(_ line: Data) throws { try child.send(line) }
    func terminate() { child.terminate() }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { await child.waitForExit(timeoutNanoseconds: timeoutNanoseconds) }
}
