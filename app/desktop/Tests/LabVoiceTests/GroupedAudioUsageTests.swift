import XCTest
@testable import LabVoice

final class GroupedAudioUsageTests: XCTestCase {
    private func device(_ id: UInt32, streams: Bool? = true, uid: String? = nil) -> AudioUsedDevice {
        .init(objectID: id, uid: uid ?? "device-\(id)", hasInputStreams: streams)
    }
    private var idle: AudioProcessDirection { .init(running: false, devices: []) }
    private var unknown: AudioProcessDirection { .init(running: nil, devices: nil) }
    private func active(_ devices: [AudioUsedDevice]) -> AudioProcessDirection { .init(running: true, devices: devices) }
    private func process(_ object: UInt32, actual: Int? = 10, owner: Int? = 100, appID: String? = "app", name: String? = "App",
                         input: AudioProcessDirection? = nil, output: AudioProcessDirection? = nil, errors: [String] = [], usageStale: Bool? = nil, pending: Bool? = nil) -> AudioProcessUsage {
        .init(objectID: object, actualPID: actual, responsiblePID: owner, responsiblePIDFallback: false, responsiblePIDResolution: "responsibility_lookup", appName: name, appID: appID, processBundleID: appID, responsibleBundleID: appID, usageStale: usageStale, stabilizationPending: pending, input: input ?? idle, output: output ?? idle, errors: errors)
    }
    private func group(_ rows: [AudioProcessUsage], status: String = "available") -> GroupedAudioUsage {
        AudioUsageGrouping.group(.init(status: status, errors: [], processes: rows))
    }
    func testGroupsAllSiblingPIDsIncludingInactiveInNumericUniqueOrderPerDeviceAndDirection() {
        let result = group([
            process(30, actual: 9, output: active([device(42), device(41), device(42)])),
            process(20, actual: 2), // Inactive sibling belongs in both actualPids strings.
            process(10, actual: 12, input: active([device(51)]), output: active([device(41)])),
            process(40, actual: 9)
        ])
        XCTAssertTrue(result.complete); XCTAssertEqual(result.applications.count, 1)
        XCTAssertEqual(result.clients.count, 3)
        XCTAssertTrue(result.clients.allSatisfy { $0.clientPID == 100 && $0.actualPids == "2,9,12" })
        XCTAssertEqual(result.clients.filter { $0.direction == .input }.map(\.deviceID), ["51"])
        XCTAssertEqual(result.clients.filter { $0.direction == .output }.map(\.deviceID), ["41", "42"])
        XCTAssertEqual(result.clients.first { $0.deviceID == "41" }?.sourceObjectID, 10)
    }
    func testNormalizationUsesTwoOrderedPassesAndRetainsLastDeviceEvenWhenItOverlaps() {
        let input = active([device(2, streams: false), device(1, streams: true)])
        let normalized = AudioUsageGrouping.normalizeInput(input, output: active([device(1)]))
        // OR-loop would remove1 first. Native no-stream pass removes2 and stops.
        XCTAssertEqual(normalized.devices?.map(\.objectID), [1]); XCTAssertNil(normalized.issue)
        let remaining = AudioUsageGrouping.normalizeInput(active([device(3), device(2), device(1)]), output: active([device(1), device(2), device(3)]))
        XCTAssertEqual(remaining.devices?.map(\.objectID), [3])
        let one = AudioUsageGrouping.normalizeInput(active([device(1, streams: false)]), output: active([device(1)]))
        XCTAssertEqual(one.devices?.map(\.objectID), [1])
    }
    func testUnknownMetadataOnlyBlocksNormalizationWhenReachedAndOutputRemainsIndependent() {
        let harmless = AudioUsageGrouping.normalizeInput(active([device(1, streams: false), device(2, streams: nil)]), output: unknown)
        XCTAssertEqual(harmless.devices?.map(\.objectID), [2]); XCTAssertNil(harmless.issue)
        let needed = AudioUsageGrouping.normalizeInput(active([device(1, streams: nil), device(2, streams: false)]), output: idle)
        XCTAssertNil(needed.devices); XCTAssertNotNil(needed.issue)
        let outputNeeded = AudioUsageGrouping.normalizeInput(active([device(1), device(2)]), output: unknown)
        XCTAssertNil(outputNeeded.devices)
        let result = group([process(1, input: active([device(1, streams: nil), device(2)]), output: active([device(8)]), errors: ["input stream read failed"])])
        XCTAssertFalse(result.complete)
        XCTAssertEqual(result.clients.map(\.deviceID), ["8"])
        XCTAssertEqual(result.clients.first?.direction, .output)
    }
    func testDedupUsesExactAppIDConcatenatedWithDecimalDeviceIDAndAscendingSourceOrder() {
        let result = group([
            process(20, actual: 20, owner: 200, appID: "a1", output: active([device(23)])),
            process(10, actual: 10, owner: 100, appID: "a12", output: active([device(3)])),
            process(30, actual: 30, owner: 300, appID: "a12", input: active([device(3)]))
        ])
        XCTAssertEqual(result.clients.filter { $0.direction == .output }.count, 1)
        XCTAssertEqual(result.clients.first { $0.direction == .output }?.clientPID, 100)
        XCTAssertEqual(result.clients.first { $0.direction == .output }?.deviceID, "3")
        XCTAssertEqual(result.clients.filter { $0.direction == .input }.count, 1) // Independent directional maps.
        XCTAssertFalse(result.complete); XCTAssertTrue(result.issues.contains { $0.contains("deduplicated") })
        let unicode = group([process(1, appID: "caf\u{00e9}", output: active([device(1)])), process(2, appID: "cafe\u{0301}", output: active([device(1)]))])
        XCTAssertEqual(unicode.clients.count, 2)
    }
    func testUnknownIdentityMakesSiblingGroupsIncompleteAndNeverGroupsByName() {
        let result = group([
            process(1, actual: 10, owner: 100, name: "Same", input: active([device(1)])),
            process(2, actual: 20, owner: 200, appID: "other", name: "Same", output: active([device(2)])),
            process(3, actual: nil, owner: nil, appID: nil, input: unknown)
        ])
        XCTAssertEqual(result.applications.map(\.id), [100, 200])
        XCTAssertTrue(result.clients.allSatisfy { $0.actualPids == nil && $0.incomplete })
        XCTAssertFalse(result.complete)
        let missingApp = group([process(4, appID: nil, input: active([device(1)]))])
        XCTAssertTrue(missingApp.clients.isEmpty); XCTAssertFalse(missingApp.issues.isEmpty)
        let failed = group([process(1, output: active([device(1)]))], status: "failed")
        XCTAssertTrue(failed.clients.isEmpty); XCTAssertFalse(failed.complete)
    }
    func testPublicAndPrivateUIDsRemainSeparateAndUnmappedUIDDoesNotGainEligibility() {
        let devices: [AudioUsedDevice] = [
            device(1, uid: "dev.hari.labvoice.microphone"), device(2, uid: "dev.hari.labvoice.speaker"),
            device(3, uid: "dev.hari.labvoice.feed"), device(4, uid: "dev.hari.labvoice.monitor"),
            .init(objectID: 5, uid: nil, hasInputStreams: nil)]
        let result = group([process(1, output: active(devices))])
        XCTAssertEqual(result.clients.map(\.deviceRole), [.publicMicrophone, .publicSpeaker, .privateFeed, .privateMonitor, .unknown])
        XCTAssertEqual(result.clients.count, 5); XCTAssertFalse(result.complete)
        XCTAssertEqual(result.clients.last?.deviceID, "5"); XCTAssertNil(result.clients.last?.deviceUID)
    }
    func testStalePublishedRowsRemainIncompleteWhileHealthyOwnersAndRawObservationsStayUsable() {
        let result = group([
            process(1, actual: 1, input: active([device(1)]), usageStale: true, pending: false),
            process(2, actual: 2, output: active([device(2)]), usageStale: false, pending: false),
            process(3, actual: 3, owner: 200, appID: "other", output: active([device(3)]), usageStale: false, pending: false)
        ])
        XCTAssertFalse(result.complete)
        XCTAssertTrue(result.clients.first { $0.sourceObjectID == 1 }?.stale == true)
        XCTAssertTrue(result.clients.filter { $0.clientPID == 100 }.allSatisfy { $0.incomplete && $0.actualPids == nil })
        let healthy = result.clients.first { $0.clientPID == 200 }
        XCTAssertEqual(healthy?.actualPids, "3"); XCTAssertFalse(healthy?.incomplete ?? true)
        let raw = group([process(1, input: active([device(1)]))])
        XCTAssertTrue(raw.complete); XCTAssertFalse(raw.clients[0].stale); XCTAssertFalse(raw.clients[0].stabilizationPending)
        let pending = group([process(1, input: active([device(1)]), usageStale: false, pending: true)])
        XCTAssertTrue(pending.complete); XCTAssertTrue(pending.clients[0].stabilizationPending)
    }

}
