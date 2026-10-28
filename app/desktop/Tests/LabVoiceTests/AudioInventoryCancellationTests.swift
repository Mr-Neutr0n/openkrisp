import XCTest
import AVFoundation
@testable import LabVoice

@MainActor final class AudioInventoryCancellationTests: XCTestCase {
    private func snapshot(_ name: String) throws -> AudioInventory {
        try JSONDecoder().decode(AudioInventory.self, from: Data("{\"devices\":[{\"uid\":\"mic\",\"name\":\"\(name)\",\"alive\":1,\"nominal_rate\":48000,\"input\":{\"channels\":1},\"output\":{\"channels\":0}}],\"companion_devices\":[],\"errors\":[]}".utf8))
    }
    private func wait(_ predicate: () -> Bool) async throws {
        for _ in 0..<1000 { if predicate() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Fixture did not progress")
    }
    private func model(read: @escaping () async throws -> AudioInventory, stop: @escaping () async -> Bool) -> AudioRouteController {
        AudioRouteController(readInventory: read, stopInventory: stop, authorization: { XCTFail("No permission"); return .authorized }, requestAuthorization: { XCTFail("No permission"); return false }, factory: { throw AudioHelperError.missingHelper })
    }
    func testStopRevokesLateSuccessAndFailure() async throws {
        for succeeds in [true, false] {
            var pending: CheckedContinuation<AudioInventory, Error>?
            let model = model(read: { try await withCheckedThrowingContinuation { pending = $0 } }, stop: { true })
            let refresh = Task { await model.refresh() }; try await wait { pending != nil }
            let stopped = await model.stop(); XCTAssertTrue(stopped)
            if succeeds { pending?.resume(returning: try snapshot("stale")) }
            else { pending?.resume(throwing: AudioHelperError.invalidInventory) }
            await refresh.value
            XCTAssertNil(model.inventory); XCTAssertNil(model.error); XCTAssertFalse(model.loading)
        }
    }
    func testCancelledReadCannotReleaseAdmissionDuringStopAndReplacementStaysCurrent() async throws {
        var reads: [CheckedContinuation<AudioInventory, Error>] = []
        var stop: CheckedContinuation<Bool, Never>?
        let model = model(read: { try await withCheckedThrowingContinuation { reads.append($0) } }, stop: { await withCheckedContinuation { stop = $0 } })
        let old = Task { await model.refresh() }; try await wait { reads.count == 1 }
        let stopping = Task { await model.stop() }; try await wait { stop != nil }
        reads[0].resume(returning: try snapshot("old")); await old.value
        XCTAssertTrue(model.loading); XCTAssertTrue(model.engaged); XCTAssertFalse(model.canStart)
        await model.refresh(); XCTAssertEqual(reads.count, 1)
        stop?.resume(returning: true); let stopped = await stopping.value; XCTAssertTrue(stopped)
        XCTAssertFalse(model.loading); XCTAssertNil(model.inventory)
        let replacement = Task { await model.refresh() }; try await wait { reads.count == 2 }
        XCTAssertTrue(model.loading)
        reads[1].resume(returning: try snapshot("new")); await replacement.value
        XCTAssertEqual(model.inventory?.devices.first?.name, "new"); XCTAssertNil(model.error)
    }
    func testStopConfirmedBeforeReadStillHoldsServiceSlotUntilReadUnwinds() async throws {
        var pending: CheckedContinuation<AudioInventory, Error>?, reads = 0
        let model = model(read: { reads += 1; return try await withCheckedThrowingContinuation { pending = $0 } }, stop: { true })
        let refresh = Task { await model.refresh() }; try await wait { pending != nil }
        let stopped = await model.stop(); XCTAssertTrue(stopped)
        XCTAssertTrue(model.loading); XCTAssertTrue(model.engaged)
        await model.refresh(); XCTAssertEqual(reads, 1)
        pending?.resume(throwing: AudioHelperError.invalidInventory); await refresh.value
        XCTAssertFalse(model.loading); XCTAssertNil(model.error); XCTAssertNil(model.inventory)
    }
    func testFailedStopKeepsAdmissionUntilReadExitOrConfirmedRetry() async throws {
        for retry in [false, true] {
            var pending: CheckedContinuation<AudioInventory, Error>?, stops = 0
            let model = model(read: { try await withCheckedThrowingContinuation { pending = $0 } }, stop: { stops += 1; return stops > 1 })
            let refresh = Task { await model.refresh() }; try await wait { pending != nil }
            let stopped = await model.stop(); XCTAssertFalse(stopped)
            XCTAssertTrue(model.loading); XCTAssertTrue(model.engaged); XCTAssertFalse(model.canStart)
            XCTAssertNotNil(model.error)
            await model.refresh(); XCTAssertEqual(stops, 1)
            if retry { let retried = await model.stop(); XCTAssertTrue(retried); XCTAssertTrue(model.loading); XCTAssertNil(model.error) }
            pending?.resume(returning: try snapshot("cancelled")); await refresh.value
            XCTAssertFalse(model.loading); XCTAssertNil(model.inventory)
        }
    }
    func testDuplicateStopsShareFlightAndDoNotReleaseReplacementQuery() async throws {
        var reads: [CheckedContinuation<AudioInventory, Error>] = []
        var stops: [CheckedContinuation<Bool, Never>] = []
        let model = model(read: { try await withCheckedThrowingContinuation { reads.append($0) } }, stop: { await withCheckedContinuation { stops.append($0) } })
        let old = Task { await model.refresh() }; try await wait { reads.count == 1 }
        let first = Task { await model.stop() }; try await wait { stops.count == 1 }
        let second = Task { await model.stop() }
        await Task.yield(); XCTAssertEqual(stops.count, 1)
        reads[0].resume(throwing: AudioHelperError.invalidInventory); await old.value
        XCTAssertTrue(model.loading)
        stops[0].resume(returning: true)
        let one = await first.value, two = await second.value; XCTAssertTrue(one); XCTAssertTrue(two)
        XCTAssertFalse(model.loading); XCTAssertNil(model.error)
        let replacement = Task { await model.refresh() }; try await wait { reads.count == 2 }
        XCTAssertTrue(model.loading)
        reads[1].resume(returning: try snapshot("new")); await replacement.value
        XCTAssertEqual(model.inventory?.devices.first?.name, "new")
    }

    func testQuitWaitsForCancelledQueryToDrain() async throws {
        var pending: CheckedContinuation<AudioInventory, Error>?
        let model = model(read: { try await withCheckedThrowingContinuation { pending = $0 } }, stop: { true })
        let refresh = Task { await model.refresh() }; try await wait { pending != nil }
        let quit = QuitCoordinator(snapshot: {
            QuitSnapshot(recordingActive: false, audioEngaged: model.engaged, testEngaged: false, otherWork: false)
        }, confirmSave: { true }, stopAudio: { await model.stop() }, cleanupTest: { true }, gate: QuitGate())
        let early = await quit.request(); XCTAssertFalse(early); XCTAssertTrue(model.loading)
        pending?.resume(returning: try snapshot("cancelled")); await refresh.value
        let drained = await quit.request(); XCTAssertTrue(drained)
        XCTAssertNil(model.inventory)
    }

}
