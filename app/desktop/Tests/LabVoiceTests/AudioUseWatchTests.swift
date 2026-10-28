import XCTest
@testable import LabVoice

@MainActor final class AudioUseWatchTests: XCTestCase {
    override func tearDown() { PowerAdmission.shared.setAllowed(true) }
    private func ready(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Observer fixture did not progress")
    }
    func testSnapshotReadinessGenerationAndLateCallbacksNeverOverwriteReplacement() async throws {
        let first = WatchFixtureChild(), second = WatchFixtureChild(); var created = 0
        let model = AudioUseWatchController(factory: { created += 1; return created == 1 ? first : second })
        model.start(); XCTAssertEqual(first.arguments, ["--watch-audio-use-stabilized"]); XCTAssertEqual(model.phase, .starting)
        first.snapshot(sequence: 1, generation: 1, object: 10)
        XCTAssertEqual(model.phase, .watching); XCTAssertFalse(model.stale)
        first.snapshot(sequence: 2, generation: 2, object: 20)
        first.snapshot(sequence: 3, generation: 1, object: 30)
        XCTAssertEqual(model.snapshot?.processes.first?.objectID, 20)
        let stopped = await model.stop(); XCTAssertTrue(stopped); XCTAssertFalse(model.engaged)
        XCTAssertTrue(model.cleanDetachVerified); XCTAssertTrue(model.stale)
        model.start(); second.snapshot(sequence: 1, generation: 1, object: 40)
        first.snapshot(sequence: 99, generation: 99, object: 99); first.finish(status: 2)
        XCTAssertEqual(model.snapshot?.processes.first?.objectID, 40); XCTAssertFalse(model.stale)
        _ = await model.stop(); XCTAssertFalse(model.engaged)
    }
    func testErrorOrUnexpectedExitPreservesLastObservationAsStaleAndReleasesOnlyExitedProcess() async throws {
        let child = WatchFixtureChild(), model = AudioUseWatchController(factory: { child })
        model.start(); child.snapshot(sequence: 1, generation: 1, object: 10)
        child.finish(status: 2, diagnostic: "Listener removal failed")
        XCTAssertFalse(model.engaged); XCTAssertTrue(model.canStart)
        XCTAssertEqual(model.phase, .failed); XCTAssertTrue(model.stale)
        XCTAssertFalse(model.cleanDetachVerified); XCTAssertEqual(model.error, "Listener removal failed")
        XCTAssertEqual(model.snapshot?.processes.first?.objectID, 10)
    }
    func testOldDeferredFailureCleanupCannotStopNewRun() async throws {
        let first = WatchFixtureChild(), second = WatchFixtureChild(); var created = 0
        let model = AudioUseWatchController(factory: { created += 1; return created == 1 ? first : second })
        model.start(); first.raw("not-json") // Defers stop, tied to this operation.
        first.finish(status: 2)
        model.start(); second.snapshot(sequence: 1, generation: 1, object: 20)
        await Task.yield()
        XCTAssertTrue(second.running); XCTAssertEqual(second.stopCommands, 0)
        XCTAssertFalse(model.stale); XCTAssertEqual(model.snapshot?.processes.first?.objectID, 20)
        _ = await model.stop()
    }
    func testLiveCleanupFailureBlocksRestartAndQuitUntilStopRetryDrains() async throws {
        let child = WatchFixtureChild(); child.drains = false
        let model = AudioUseWatchController(factory: { child }, stopTimeout: 1_000_000)
        model.start(); child.snapshot(sequence: 1, generation: 1, object: 10)
        let quit = QuitCoordinator(snapshot: { QuitSnapshot(recordingActive: false, audioEngaged: model.engaged, testEngaged: false, otherWork: false, stopFailure: model.error) }, confirmSave: { true }, stopAudio: { await model.stop() }, cleanupTest: { true }, gate: QuitGate())
        let failed = await quit.request(); XCTAssertFalse(failed)
        XCTAssertTrue(model.engaged); XCTAssertFalse(model.canStart); XCTAssertTrue(model.stale)
        XCTAssertNotNil(model.error); XCTAssertTrue(child.running)
        child.drains = true
        let retried = await quit.request(); XCTAssertTrue(retried)
        XCTAssertFalse(model.engaged); XCTAssertFalse(child.running)
    }
    func testSuspendFencesPublicationStopsObserverAndResumeNeverRestartsIt() async throws {
        let child = WatchFixtureChild(); var launches = 0
        let model = AudioUseWatchController(factory: { launches += 1; return child })
        model.start(); child.snapshot(sequence: 1, generation: 1, object: 10)
        let power = AppPowerLifecycle(revoke: { model.revokeForPowerEvent() }, suspend: {
            let stopped = await model.stop(); return .init(failure: stopped ? nil : model.error, blocking: !stopped)
        }, resume: { nil })
        power.request(.suspend)
        child.snapshot(sequence: 2, generation: 1, object: 20)
        XCTAssertTrue(model.stale); XCTAssertEqual(model.snapshot?.processes.first?.objectID, 10)
        await power.waitUntilSettled(); XCTAssertFalse(model.engaged)
        power.request(.resume); await power.waitUntilSettled()
        XCTAssertEqual(launches, 1); XCTAssertTrue(model.stale); XCTAssertTrue(model.canStart)
    }
    func testStartupDeadlineAndFailedSnapshotDoNotReplaceLastGoodObservation() async throws {
        let child = WatchFixtureChild(), model = AudioUseWatchController(factory: { child }, startupTimeout: 1_000_000)
        model.start(); try await ready { !model.engaged }; XCTAssertNotNil(model.error)
        let second = WatchFixtureChild(), watch = AudioUseWatchController(factory: { second })
        watch.start(); second.snapshot(sequence: 1, generation: 1, object: 10)
        second.snapshot(sequence: 2, generation: 1, object: 20, status: "failed")
        XCTAssertTrue(watch.engaged); XCTAssertTrue(second.running)
        XCTAssertEqual(watch.snapshot?.processes.first?.objectID, 10); XCTAssertTrue(watch.stale)
        XCTAssertNotNil(watch.error)
        second.snapshot(sequence: 3, generation: 1, object: 30)
        XCTAssertFalse(watch.stale); XCTAssertNil(watch.error)
        _ = await watch.stop()
    }
    func testTerminalNativeErrorDetailsSurviveImmediateDrainedFailureExit() {
        let child = WatchFixtureChild(), model = AudioUseWatchController(factory: { child })
        model.start()
        child.raw("{\"version\":1,\"timing_mode\":\"stabilized\",\"event\":\"audio_use_error\",\"sequence\":1,\"generation\":1,\"message\":\"Cleanup failed\",\"snapshot\":{\"status\":\"failed\",\"errors\":[\"OSStatus=-1 object=22\"],\"processes\":[]}}")
        child.finish(status: 2)
        XCTAssertTrue(model.error?.contains("OSStatus=-1 object=22") == true)
        XCTAssertFalse(model.engaged); XCTAssertFalse(model.cleanDetachVerified)
    }
    func testVerifiedDestroyedObjectsEndOwnershipWithoutClaimingSuccessfulRemove() async {
        let child = WatchFixtureChild(); child.allRemovalsVerified = false; child.retired = 4; child.removed = 2
        let model = AudioUseWatchController(factory: { child })
        model.start(); child.snapshot(sequence: 1, generation: 1, object: 10)
        let stopped = await model.stop(); XCTAssertTrue(stopped)
        XCTAssertTrue(model.cleanupVerified); XCTAssertFalse(model.cleanDetachVerified)
        XCTAssertEqual(model.allListenerRemovalsVerified, false)
        XCTAssertEqual(model.listenersRemoved, 2); XCTAssertEqual(model.listenersInvalidObjectRetired, 4)
        XCTAssertEqual(model.listenersRemoveFailed, 0)
        XCTAssertTrue(model.cleanupNote?.contains("4 listener registrations") == true)
        XCTAssertNil(model.error); XCTAssertFalse(model.engaged); XCTAssertTrue(model.stale)
    }
    func testMissingAllRemovalFlagCannotClaimSuccessfulRemoveAndContradictionsFailClosed() async {
        let legacy = WatchFixtureChild(); legacy.allRemovalsVerified = nil
        let unknown = AudioUseWatchController(factory: { legacy })
        unknown.start(); let contained = await unknown.stop(); XCTAssertTrue(contained)
        XCTAssertTrue(unknown.cleanupVerified); XCTAssertFalse(unknown.cleanDetachVerified)
        XCTAssertNotNil(unknown.cleanupNote)
        for allVerified in [true, false] {
            let child = WatchFixtureChild(); child.allRemovalsVerified = allVerified; child.retired = allVerified ? 1 : 0
            let model = AudioUseWatchController(factory: { child })
            model.start(); let stopped = await model.stop(); XCTAssertTrue(stopped)
            XCTAssertFalse(model.cleanupVerified); XCTAssertFalse(model.cleanDetachVerified)
            XCTAssertTrue(model.error?.contains("contradictory") == true)
        }
    }
    func testRestartResetDoesNotPublishNoAppsAndRecoveryPreservesPublicationScope() async {
        let child = WatchFixtureChild(), model = AudioUseWatchController(factory: { child })
        model.start(); child.snapshot(sequence: 1, generation: 1, object: 10, activeInput: true)
        child.snapshot(sequence: 2, generation: 2, object: 0, status: "unavailable", source: "restarting", reason: "restart_begin", empty: true)
        XCTAssertEqual(model.phase, .reconnecting); XCTAssertTrue(model.stale)
        XCTAssertEqual(model.snapshot.map(AudioUsageGrouping.group)?.clients.count, 1)
        XCTAssertEqual(model.snapshot?.processes.first?.objectID, 10); XCTAssertEqual(model.changedDirections, [])
        child.snapshot(sequence: 3, generation: 2, object: 0, status: "unavailable", source: "restarting", reason: "restart_reset", directions: ["input", "output"], empty: true)
        XCTAssertEqual(model.snapshot?.processes.first?.objectID, 10)
        XCTAssertEqual(model.changedDirections, [.input, .output])
        child.snapshot(sequence: 4, generation: 3, object: 20, reason: "changed", directions: ["input", "output"])
        XCTAssertFalse(model.stale); XCTAssertNil(model.error); XCTAssertEqual(model.sourceState, "running")
        XCTAssertEqual(model.publicationReason, "changed"); XCTAssertEqual(model.changedDirections, [.input, .output])
        XCTAssertEqual(model.snapshot?.processes.first?.objectID, 20)
        _ = await model.stop()
    }
    func testInitialRecoverableReadErrorKeepsSourceAliveWithoutPublishingEmptyUsage() async throws {
        let child = WatchFixtureChild(), model = AudioUseWatchController(factory: { child }, startupTimeout: 1_000_000)
        model.start(); child.snapshot(sequence: 1, generation: 1, object: 0, status: "failed", empty: true)
        try await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertTrue(model.engaged); XCTAssertTrue(child.running); XCTAssertNil(model.snapshot)
        XCTAssertTrue(model.stale); XCTAssertEqual(model.publicationReason, "read_error")
        child.snapshot(sequence: 2, generation: 1, object: 10)
        XCTAssertFalse(model.stale); XCTAssertNil(model.error)
        XCTAssertEqual(model.snapshot?.processes.first?.objectID, 10)
        _ = await model.stop()
    }
    func testContradictoryPublicationScopeIsRejectedWithoutReplacingLastObservation() async throws {
        let invalid: [(String, String, String, [String])] = [
            ("restarting", "readiness", "available", []),
            ("restarting", "changed", "available", ["input"]),
            ("running", "restart_begin", "unavailable", []),
            ("running", "restart_reset", "unavailable", ["input", "output"]),
            ("running", "changed", "failed", ["input"]),
            ("restarting", "restart_reset", "unavailable", [])]
        for (source, reason, status, directions) in invalid {
            let child = WatchFixtureChild(), model = AudioUseWatchController(factory: { child })
            model.start(); child.snapshot(sequence: 1, generation: 1, object: 10)
            child.snapshot(sequence: 2, generation: 2, object: 20, status: status, source: source, reason: reason, directions: directions)
            try await ready { !model.engaged }
            XCTAssertEqual(model.snapshot?.processes.first?.objectID, 10)
            XCTAssertTrue(model.error?.contains("invalid stabilized snapshot") == true); XCTAssertTrue(model.stale)
        }
    }
    func testRawModeCannotMasqueradeAsStabilizedObservation() async throws {
        let child = WatchFixtureChild(), model = AudioUseWatchController(factory: { child })
        model.start(); child.snapshot(sequence: 1, generation: 1, object: 10, mode: "raw")
        try await ready { !model.engaged }
        XCTAssertNil(model.snapshot); XCTAssertNil(model.timingMode)
        XCTAssertTrue(model.error?.contains("stabilized timing mode") == true)
    }
    func testMissingStabilizedProvenanceCannotPresentRawRowsAsSettled() async throws {
        let child = WatchFixtureChild(), model = AudioUseWatchController(factory: { child })
        model.start(); child.snapshot(sequence: 1, generation: 1, object: 10, includeProvenance: false)
        try await ready { !model.engaged }
        XCTAssertNil(model.snapshot); XCTAssertTrue(model.error?.contains("provenance") == true)
        let missingCount = WatchFixtureChild(), unknownHistory = AudioUseWatchController(factory: { missingCount })
        unknownHistory.start(); missingCount.snapshot(sequence: 1, generation: 1, object: 10, coalesced: nil)
        try await ready { !unknownHistory.engaged }
        XCTAssertNil(unknownHistory.snapshot)
        XCTAssertTrue(unknownHistory.error?.contains("invalid stabilized snapshot") == true)
    }
    func testCoalescedPublicationHistoryIsRetainedWithoutMakingCurrentSnapshotStale() async {
        let child = WatchFixtureChild(), model = AudioUseWatchController(factory: { child })
        model.start(); child.snapshot(sequence: 1, generation: 1, object: 10, reason: "changed", directions: ["input"], coalesced: 2, activeInput: true)
        XCTAssertEqual(model.snapshot.map(AudioUsageGrouping.group)?.clients.count, 1)
        XCTAssertEqual(model.coalescedPublications, 2); XCTAssertEqual(model.coalescedPublicationTotal, 2)
        XCTAssertFalse(model.stale)
        child.snapshot(sequence: 2, generation: 1, object: 20, reason: "changed", directions: ["input"], coalesced: 0)
        XCTAssertEqual(model.snapshot.map(AudioUsageGrouping.group)?.clients.count, 0)
        XCTAssertEqual(model.coalescedPublications, 0); XCTAssertEqual(model.coalescedPublicationTotal, 2)
        XCTAssertFalse(model.stale); XCTAssertEqual(model.snapshot?.processes.first?.objectID, 20)
        _ = await model.stop()
    }
    func testFreshOneShotOverridesStoppedWatchAndNewWatchOverridesOlderOneShot() {
        let old = Date(timeIntervalSince1970: 10), fresh = Date(timeIntervalSince1970: 20)
        XCTAssertFalse(AudioUseDisplaySource.prefersWatch(watchObservedAt: old, oneShotObservedAt: fresh))
        XCTAssertTrue(AudioUseDisplaySource.prefersWatch(watchObservedAt: fresh, oneShotObservedAt: old))
        XCTAssertFalse(AudioUseDisplaySource.prefersWatch(watchObservedAt: nil, oneShotObservedAt: fresh))
    }
}

@MainActor private final class WatchFixtureChild: AudioHelperChild {
    var running = false, drains = true
    var allRemovalsVerified: Bool? = true
    var removed: UInt64 = 0, retired: UInt64 = 0, removalFailed: UInt64 = 0
    var stopCommands = 0
    var arguments: [String] = []
    private var line: ((String) -> Void)?, exit: ((HelperExit) -> Void)?
    private var sequence: UInt64 = 0, generation: UInt64 = 1
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        self.arguments = arguments; self.line = line; self.exit = exit; running = true
    }
    func raw(_ row: String) { line?(row) }
    private func emit(_ object: [String: Any]) { raw(String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)) }
    func snapshot(sequence: UInt64, generation: UInt64, object: Int, status: String = "available",
                  mode: String = "stabilized", source: String = "running", reason: String? = nil,
                  directions: [String] = [], usageStale: Bool = false, pending: Bool = false, empty: Bool = false, includeProvenance: Bool = true, coalesced: UInt64? = 0, activeInput: Bool = false) {
        self.sequence = sequence; self.generation = generation
        var row: [String: Any] = ["object_id": object, "actual_pid": 10, "responsible_pid": 20, "responsible_pid_fallback": false,
            "responsible_pid_resolution": "responsibility_lookup", "app_name": "Fixture", "app_id": "own.fixture",
            "process_bundle_id": "own.fixture", "responsible_bundle_id": "own.fixture", "errors": [],
            "usage_stale": usageStale, "stabilization_pending": pending,
            "input": ["running": false, "devices": []], "output": ["running": false, "devices": []]]
        if activeInput { row["input"] = ["running": true, "devices": [["object_id": 100, "uid": "own.fixture.input", "has_input_streams": true]]] }
        if !includeProvenance { row.removeValue(forKey: "usage_stale"); row.removeValue(forKey: "stabilization_pending") }
        var envelope: [String: Any] = ["version": 1, "event": "audio_use_snapshot", "sequence": sequence, "generation": generation,
            "timing_mode": mode, "source_state": source,
            "publication_reason": reason ?? (status == "available" ? "readiness" : "read_error"), "changed_directions": directions,
            "snapshot": ["status": status, "errors": status == "available" ? [] : ["source failed"], "processes": empty ? [] : [row]]]
        if let coalesced { envelope["coalesced_publications"] = coalesced }
        emit(envelope)
    }
    func send(_ line: Data) throws {
        XCTAssertEqual(line, Data("stop\n".utf8)); stopCommands += 1
        if drains {
            var object: [String: Any] = ["version": 1, "timing_mode": "stabilized", "event": "audio_use_stopped", "sequence": sequence + 1, "generation": generation + 1, "cleanup_verified": true,
                "listeners_removed": removed, "listeners_invalid_object_retired": retired, "listeners_remove_failed": removalFailed]
            if let allRemovalsVerified { object["all_listener_removals_verified"] = allRemovalsVerified }
            emit(object)
            finish(status: 0)
        }
    }
    func terminate() { if drains { finish(status: 15) } }
    func finish(status: Int32, diagnostic: String = "") { running = false; exit?(.init(status: status, output: Data(), diagnostic: diagnostic)) }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { !running }
}

@MainActor final class AudioUseWatchProcessTests: XCTestCase {
    func testActualOwnNDJSONChildReachesControllerAndStopsWithVerifiedDrainedExit() async throws {
        let child = OwnWatchProcess(), controller = AudioUseWatchController(factory: { child })
        controller.start()
        for _ in 0..<3000 {
            if controller.snapshot?.processes.first?.objectID == 8 { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertEqual(controller.snapshot?.processes.first?.objectID, 8)
        XCTAssertEqual(controller.phase, .watching); XCTAssertFalse(controller.stale)
        let stopped = await controller.stop(); XCTAssertTrue(stopped)
        XCTAssertFalse(controller.engaged); XCTAssertTrue(controller.cleanDetachVerified); XCTAssertTrue(controller.stale)
        XCTAssertTrue(child.lastExit?.output.isEmpty == true)
        XCTAssertTrue(child.lastExit?.diagnostic.isEmpty == true)
    }
}

@MainActor private final class OwnWatchProcess: AudioHelperChild {
    private let child = SystemAudioHelperChild(url: URL(fileURLWithPath: "/usr/bin/python3"), outputMode: .streaming(maxLineBytes: 614400))
    private(set) var lastExit: HelperExit?
    var running: Bool { child.running }
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        XCTAssertEqual(arguments, ["--watch-audio-use-stabilized"])
        let script = """
        import sys,json
        for sequence in range(1,9):
            row={"object_id":sequence,"actual_pid":10,"responsible_pid":20,"responsible_pid_fallback":False,"responsible_pid_resolution":"responsibility_lookup","usage_stale":False,"stabilization_pending":False,"app_name":"Own fixture","app_id":"own.fixture","process_bundle_id":"own.fixture","responsible_bundle_id":"own.fixture","errors":[],"input":{"running":False,"devices":[]},"output":{"running":False,"devices":[]}}
            print(json.dumps({"version":1,"timing_mode":"stabilized","source_state":"running","publication_reason":"readiness","changed_directions":[],"coalesced_publications":0,"event":"audio_use_snapshot","sequence":sequence,"generation":1,"snapshot":{"status":"available","errors":[],"processes":[row]},"own_fixture_padding":"a"*350000}),flush=True)
        for command in sys.stdin:
            if command.strip()=="stop":
                print(json.dumps({"version":1,"timing_mode":"stabilized","event":"audio_use_stopped","sequence":9,"generation":2,"cleanup_verified":True,"all_listener_removals_verified":True,"listeners_removed":0,"listeners_invalid_object_retired":0,"listeners_remove_failed":0}),flush=True)
                break
        """
        try child.launch(arguments: ["-c", script], line: line, exit: { [weak self] event in self?.lastExit = event; exit(event) })
    }
    func send(_ line: Data) throws { try child.send(line) }
    func terminate() { child.terminate() }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { await child.waitForExit(timeoutNanoseconds: timeoutNanoseconds) }
}
