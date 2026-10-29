import XCTest
@testable import LabVoice

final class LocalCallPolicyTests: XCTestCase {
    private func usage(_ pid: Int = 1, _ device: String = "1", virtual: Bool = false) -> LocalCallUsage {
        .init(pid: pid, actualPids: "\(pid)", deviceID: device, isVirtual: virtual)
    }
    private func addCall(_ name: String, to policy: inout LocalCallPolicy, now: Double = 0) {
        policy.add(name: name, usage: usage(), direction: .input, now: now)
        policy.add(name: name, usage: usage(1, "2"), direction: .output, now: now)
    }
    func testTwoLegsTrimExactNameAndArraySelection() {
        var policy = LocalCallPolicy(); policy.reset()
        policy.add(name: " A ", usage: usage(), direction: .input, now: 0)
        XCTAssertNil(policy.current)
        policy.add(name: "A", usage: usage(2, "2"), direction: .output, now: 0)
        XCTAssertEqual(policy.current, "A")
        addCall("B", to: &policy); XCTAssertEqual(policy.current, "A")
        policy.setBlocked("a", blocked: true); XCTAssertEqual(policy.current, "B")
        policy.setBlocked("a", blocked: false); XCTAssertEqual(policy.current, "B")
        policy.switchTo("A"); XCTAssertEqual(policy.current, "A")
        XCTAssertEqual(policy.calls.map(\.name), ["A", "B"])
        policy.switchTo("absent"); XCTAssertEqual(policy.current, "A")
    }
    func testOrderedLegsIdentityAndDuplicatePreservation() {
        var call = LocalTrackedCall(name: "App")
        call.add(usage(1), direction: .input, allApps: true)
        call.add(usage(2), direction: .input, allApps: true)
        call.add(.init(pid: 2, actualPids: "changed", deviceID: "1", isVirtual: true), direction: .input, allApps: true)
        XCTAssertEqual(call.input.map(\.pid), [2, 1]); XCTAssertEqual(call.input.first?.actualPids, "2")
        XCTAssertEqual(call.lastInput?.pid, 1)
        call.add(usage(3), direction: .output, allApps: true)
        call.add(usage(4), direction: .output, allApps: true)
        call.add(usage(5, virtual: true), direction: .output, allApps: true)
        XCTAssertEqual(call.output.map(\.pid), [5, 3, 4])
        call.remove(usage(5), direction: .output); XCTAssertEqual(call.lastOutput?.pid, 5)
    }
    func testCallKeepsFirstIdentityMetadata() {
        var policy = LocalCallPolicy(); policy.reset()
        policy.add(name: "App", usage: usage(), direction: .input, now: 0, appID: "first", appVersion: "1")
        policy.add(name: "App", usage: usage(2, "2"), direction: .output, now: 0, appID: "second", appVersion: "2")
        XCTAssertEqual(policy.calls[0].appID, "first"); XCTAssertEqual(policy.calls[0].appVersion, "1")
    }
    func testStopDeadlineDoesNotExtendAndReplacementCanStart() {
        var policy = LocalCallPolicy(); policy.reset(); addCall("A", to: &policy); addCall("B", to: &policy)
        policy.remove(name: "A", usage: usage(), direction: .input, now: 10)
        let deadline = policy.stopDeadline!
        policy.remove(name: "A", usage: usage(1, "2"), direction: .output, now: 10.5)
        XCTAssertEqual(policy.stopDeadline, deadline)
        policy.expire(deadline, now: 10.99); XCTAssertEqual(policy.current, "A")
        policy.expire(deadline, now: 11); XCTAssertEqual(policy.current, "B")
        XCTAssertFalse(policy.calls.contains { $0.name == "A" })
    }
    func testRecoveryClassifiesShortGapAndSameDeviceLongGap() {
        var policy = LocalCallPolicy(); policy.reset(); addCall("A", to: &policy)
        policy.remove(name: "A", usage: usage(), direction: .input, now: 10)
        policy.add(name: "A", usage: usage(), direction: .input, now: 10.4)
        XCTAssertEqual(policy.calls[0].starts, 1); XCTAssertNil(policy.stopDeadline)
        policy.remove(name: "A", usage: usage(), direction: .input, now: 20)
        policy.add(name: "A", usage: usage(), direction: .input, now: 20.5)
        XCTAssertEqual(policy.calls[0].starts, 2)
        policy.remove(name: "A", usage: usage(), direction: .input, now: 30)
        policy.add(name: "A", usage: usage(1, "new"), direction: .input, now: 30.9)
        XCTAssertEqual(policy.calls[0].starts, 2)
    }
    func testSafariDelayAndInvalidationFenceExpiredSelection() {
        var policy = LocalCallPolicy(); policy.reset(); addCall("Safari", to: &policy)
        policy.remove(name: "Safari", usage: usage(), direction: .input, now: 10)
        XCTAssertEqual(policy.stopDeadline?.due, 11.3)
        let deadline = policy.stopDeadline!; policy.invalidate()
        policy.expire(deadline, now: 100); policy.setBlocked("Safari", blocked: false)
        policy.switchTo("Safari"); XCTAssertNil(policy.current); XCTAssertNil(policy.stopDeadline)
    }
    func testECMAScriptNameWhitespaceKeepsNELAndTrimsBOM() {
        var policy = LocalCallPolicy(); policy.reset()
        addCall("\u{FEFF}App\u{FEFF}", to: &policy)
        XCTAssertEqual(policy.calls.first?.name, "App")
        addCall("\u{0085}App\u{0085}", to: &policy)
        XCTAssertEqual(policy.calls.count, 2)
        XCTAssertEqual(policy.calls.last?.name, "\u{0085}App\u{0085}")
    }
    func testExactUnicodeNamesAndLowercaseBlocks() {
        var policy = LocalCallPolicy(); policy.reset()
        addCall("é", to: &policy); addCall("e\u{301}", to: &policy)
        XCTAssertEqual(policy.calls.count, 2)
        policy.setBlocked("É", blocked: true)
        XCTAssertTrue(policy.isBlocked("é")); XCTAssertFalse(policy.isBlocked("e\u{301}"))
        XCTAssertEqual(policy.current.map { Array($0.utf8) }, Array("e\u{301}".utf8))
    }
}

@MainActor final class LocalCallControllerTests: XCTestCase {
    private func snapshot(_ names: [(String, Int)], stale: Bool = false, uid: String = "physical", appID: String? = nil) -> AudioProcessSnapshot {
        let rows = names.map { name, pid in AudioProcessUsage(objectID: UInt32(pid), actualPID: pid,
            responsiblePID: pid, responsiblePIDFallback: false, responsiblePIDResolution: "responsible", appName: name,
            appID: appID ?? "\(name)", processBundleID: nil, responsibleBundleID: nil, usageStale: stale, stabilizationPending: false,
            input: .init(running: true, devices: [.init(objectID: 10, uid: uid, hasInputStreams: true)]),
            output: .init(running: true, devices: [.init(objectID: 20, uid: uid, hasInputStreams: false)]), errors: []) }
        return .init(status: "available", errors: [], processes: rows)
    }
    func testReadinessBaselineGapAndStaleBlockAreFenced() {
        let suite = "local-call-tests-\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = LocalCallController(defaults: defaults, automaticTimers: false)
        XCTAssertTrue(model.policy.allApps)
        let observed = snapshot([("App", 1)])
        model.receive(snapshot: observed, generation: 1, reason: "readiness", directions: [], coalesced: 0)
        XCTAssertEqual(model.policy.current, "App"); XCTAssertTrue(model.policy.fresh)
        model.receive(snapshot: observed, generation: 1, reason: "changed", directions: [.input], coalesced: 0)
        XCTAssertEqual(model.policy.current, "App")
        model.receive(snapshot: observed, generation: 1, reason: "changed", directions: [.output], coalesced: 0)
        XCTAssertEqual(model.policy.current, "App")
        model.receive(snapshot: observed, generation: 1, reason: "changed", directions: [.input], coalesced: 1)
        XCTAssertNil(model.policy.current); XCTAssertFalse(model.policy.fresh)
        model.setBlocked("APP", blocked: true); model.setBlocked("APP", blocked: false)
        XCTAssertNil(model.policy.current)
        model.receive(snapshot: observed, generation: 1, reason: "changed", directions: [.input, .output], coalesced: 0)
        XCTAssertEqual(model.policy.current, "App")
        model.receive(snapshot: snapshot([("App", 1)], stale: true), generation: 1, reason: "read_error", directions: [], coalesced: 0)
        XCTAssertNil(model.policy.current)
        model.setBlocked("APP", blocked: true)
        let reloaded = LocalCallController(defaults: defaults, automaticTimers: false)
        XCTAssertTrue(reloaded.policy.isBlocked("App")); XCTAssertNil(reloaded.policy.current)
    }
    func testPrivateEndpointsAndOwnBundleCannotQualify() {
        let suite = "local-call-tests-\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = LocalCallController(defaults: defaults, automaticTimers: false)
        for uid in ["dev.hari.labvoice.feed", "dev.hari.labvoice.monitor"] {
            model.invalidate("fixture")
            model.receive(snapshot: snapshot([("Internal", 1)], uid: uid), generation: 1, reason: "readiness", directions: [], coalesced: 0)
            XCTAssertNil(model.policy.current); XCTAssertTrue(model.policy.calls.isEmpty)
        }
        model.invalidate("fixture")
        model.receive(snapshot: snapshot([("Desktop", 1)], appID: "dev.labvoice.desktop"), generation: 1, reason: "readiness", directions: [], coalesced: 0)
        XCTAssertNil(model.policy.current); XCTAssertTrue(model.policy.calls.isEmpty)
    }
    func testNativeKeyOrderNotPIDPresentationAndVirtualOnlyMode() {
        let suite = "local-call-tests-\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = LocalCallController(defaults: defaults, automaticTimers: false)
        let observed = snapshot([("Zulu", 1), ("Alpha", 9)])
        model.receive(snapshot: observed, generation: 1, reason: "changed", directions: [.input, .output], coalesced: 0)
        XCTAssertEqual(model.policy.current, "Alpha")
        model.setAllApps(false); XCTAssertNil(model.policy.current)
        model.receive(snapshot: observed, generation: 1, reason: "changed", directions: [.input, .output], coalesced: 0)
        XCTAssertNil(model.policy.current); XCTAssertTrue(model.policy.calls.isEmpty)
    }
}

final class LocalCallStreamDiffTests: XCTestCase {
    private func client(_ appID: String, device: String = "10", name: String = "App", pid: Int = 1,
                        actualPids: String = "1") -> GroupedAudioClient {
        .init(direction: .input, clientPID: pid, actualPids: actualPids, appName: name, appID: appID,
              deviceID: device, deviceUID: "dev.hari.labvoice.microphone", sourceObjectID: UInt32(pid), incomplete: false)
    }
    private func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: [], locale: Locale(identifier: "en_US"))
    }
    func testExactStreamIdentityKeepsOriginalMetadata() {
        let original = client("own.app", name: "Original")
        let metadata = client("own.app", name: "Changed", actualPids: "1,2")
        let unchanged = LocalCallStreamDiff.reconcile([metadata], previous: [original], compare: compare)
        XCTAssertTrue(unchanged.created.isEmpty); XCTAssertTrue(unchanged.removed.isEmpty)
        XCTAssertEqual(unchanged.retained.first?.appName, "Original")
        XCTAssertEqual(unchanged.retained.first?.actualPids, "1")
        let replaced = LocalCallStreamDiff.reconcile([client("own.changed", name: "Original")], previous: [original], compare: compare)
        XCTAssertEqual(replaced.created.map(\.appID), ["own.changed"])
        XCTAssertEqual(replaced.removed.map(\.appID), ["own.app"])
        XCTAssertFalse(LocalCallStreamDiff.same(client("é"), client("e\u{301}")))
    }
    func testAdditionsAreLocaleSortedWithStableEqualAppIDAndReverseRemoval() {
        let incoming = [client("z", device: "1"), client("B", device: "1"), client("a", device: "10"), client("a", device: "2")]
            .sorted { $0.dedupKey.lexicographicallyPrecedes($1.dedupKey) }
        let previous = [client("old1"), client("old2"), client("old3")]
        let diff = LocalCallStreamDiff.reconcile(incoming, previous: previous, compare: compare)
        XCTAssertEqual(diff.created.map(\.appID), ["a", "a", "B", "z"])
        XCTAssertEqual(diff.created.map(\.deviceID), ["10", "2", "1", "1"])
        XCTAssertEqual(diff.removed.map(\.appID), ["old3", "old2", "old1"])
        XCTAssertEqual(diff.retained.map(\.appID), ["a", "a", "B", "z"])
    }
    func testVirtualReplacementAddsBeforeRemovalWithoutInventingCallRestart() {
        var policy = LocalCallPolicy(); policy.allApps = false; policy.reset()
        let old = client("own.app"), new = client("own.app", device: "11")
        let oldUsage = LocalCallUsage(pid: 1, actualPids: "1", deviceID: "10", isVirtual: true)
        policy.add(name: "App", usage: oldUsage, direction: .input, now: 0)
        policy.add(name: "App", usage: .init(pid: 1, actualPids: "1", deviceID: "20", isVirtual: true), direction: .output, now: 0)
        let diff = LocalCallStreamDiff.reconcile([new], previous: [old], compare: compare)
        for client in diff.created {
            policy.add(name: client.appName!, usage: .init(pid: client.clientPID, actualPids: client.actualPids, deviceID: client.deviceID, isVirtual: true), direction: .input, now: 1)
        }
        for client in diff.removed {
            policy.remove(name: client.appName!, usage: .init(pid: client.clientPID, actualPids: client.actualPids, deviceID: client.deviceID, isVirtual: true), direction: .input, now: 1)
        }
        XCTAssertEqual(policy.current, "App"); XCTAssertEqual(policy.calls[0].starts, 1)
        XCTAssertNil(policy.stopDeadline); XCTAssertEqual(policy.calls[0].input.map(\.deviceID), ["11"])
    }
}
