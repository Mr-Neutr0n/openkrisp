import XCTest
import Foundation
import AVFoundation
@testable import LabVoice

private actor FixtureComparisonPlayback: ComparisonPlaying {
    var id: UUID?
    var position = 1.25
    var playing = false
    var selected = ComparisonVariant.original
    var configured = 0
    func configure(id: UUID, original: URL, processed: URL) { self.id = id; configured += 1 }
    func select(id: UUID, variant: ComparisonVariant) -> ComparisonPlaybackState { selected = variant; return .init(playing: playing, position: position) }
    func play(id: UUID, replay: Bool) -> ComparisonPlaybackState { playing = true; if replay { position = 0 }; return .init(playing: playing, position: position) }
    func pause(id: UUID) -> ComparisonPlaybackState { playing = false; return .init(playing: false, position: position) }
    func snapshot(id: UUID) -> ComparisonPlaybackState? { .init(playing: playing, position: position) }
    func stop(id: UUID) { self.id = nil; playing = false }
    func configurations() -> Int { configured }
}
private actor SuspendedTestFiles: MicrophoneTestStoring {
    let base: MicrophoneTestFiles
    var pending: CheckedContinuation<MicrophoneTestJob, Error>?
    var created: MicrophoneTestJob?
    var failRemoval = true
    init(root: URL) { base = MicrophoneTestFiles(root: root) }
    func prepare(id: UUID, inputUID: String) async throws -> MicrophoneTestJob {
        created = try await base.prepare(id: id, inputUID: inputUID)
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func suspended() -> Bool { pending != nil }
    func releasePrepare(failing: Bool = false) {
        if failing { pending?.resume(throwing: MicrophoneTestPreparationFailure(job: created!, underlying: MicrophoneTestError.unavailable)) }
        else { pending?.resume(returning: created!) }
        pending = nil
    }
    func allowRemoval() { failRemoval = false }
    func validate(_ job: MicrophoneTestJob, frames: UInt64, originalPath: String, processedPath: String) async throws {
        try await base.validate(job, frames: frames, originalPath: originalPath, processedPath: processedPath)
    }
    func remove(_ job: MicrophoneTestJob) async throws {
        if failRemoval { throw MicrophoneTestError.unavailable }
        try await base.remove(job)
    }
    func retained() async throws -> [String] { try await base.retained() }
}

@MainActor private final class FixtureTestChild: AudioHelperChild {
    var running = false, waitResult = true, exitOnTerminate = true
    var arguments: [String] = [], commands: [[String: Any]] = []
    var lines: ((String) -> Void)?, exit: ((HelperExit) -> Void)?
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        self.arguments = arguments; lines = line; self.exit = exit; running = true
    }
    func argument(_ flag: String) -> String { arguments[arguments.firstIndex(of: flag)! + 1] }
    func emit(_ value: [String: Any]) { lines?(String(decoding: try! JSONSerialization.data(withJSONObject: value), as: UTF8.self)) }
    func started(operation: String? = nil) {
        emit(["event": "test_started", "operationID": operation ?? argument("--operation-id"), "input_uid": argument("--input"), "sampleRate": 48000, "channels": 1, "minimumFrames": 240000, "maximumFrames": 2880000])
    }
    func progress(_ frames: UInt64) { emit(["event": "test_progress", "operationID": argument("--operation-id"), "frames": frames]) }
    func complete(frames: UInt64 = 240000) {
        let directory = argument("--directory")
        emit(["event": "test_result", "operationID": argument("--operation-id"), "status": "completed", "frames": frames,
              "sampleRate": 48000, "channels": 1, "engine": "RNNoise", "originalPath": directory + "/original.wav",
              "processedPath": directory + "/processed.wav", "adapterBufferingFrames": 480, "adapterDelayAligned": true])
    }
    func finish(_ status: Int32 = 0) { running = false; exit?(HelperExit(status: status, output: Data(), diagnostic: "")) }
    func send(_ data: Data) throws { commands.append(try JSONSerialization.jsonObject(with: data) as! [String: Any]) }
    func terminate() { if exitOnTerminate { finish() } }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { waitResult && !running }
}

@MainActor private final class CppMicrophoneTestChild: AudioHelperChild {
    private let inner: SystemAudioHelperChild
    var running: Bool { inner.running }
    init(url: URL) { inner = SystemAudioHelperChild(url: url) }
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        func value(_ key: String) -> String { arguments[arguments.firstIndex(of: key)! + 1] }
        try inner.launch(arguments: [value("--operation-id"), value("--directory"), value("--input")], line: line, exit: exit)
    }
    func send(_ data: Data) throws { try inner.send(data) }
    func terminate() { inner.terminate() }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { await inner.waitForExit(timeoutNanoseconds: timeoutNanoseconds) }
}

@MainActor final class MicrophoneTestTests: XCTestCase {
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        throw NSError(domain: "Microphone test fixture timed out", code: 1)
    }
    private func input(rate: Double = 48000) throws -> LabVoice.AudioHardwareDevice {
        try JSONDecoder().decode(LabVoice.AudioHardwareDevice.self, from: Data("{\"uid\":\"mic\",\"name\":\"Fixture microphone\",\"alive\":1,\"nominal_rate\":\(rate),\"input\":{\"channels\":1},\"output\":{\"channels\":0}}".utf8))
    }
    private func controller(_ child: FixtureTestChild, root: URL, player: FixtureComparisonPlayback = FixtureComparisonPlayback()) -> MicrophoneTestController {
        MicrophoneTestController(files: MicrophoneTestFiles(root: root), playback: player,
            authorization: { .authorized }, requestAuthorization: { XCTFail("Unexpected permission prompt"); return false }, factory: { child }, exitTimeout: 1_000_000)
    }
    private func writeFiles(_ child: FixtureTestChild) throws {
        for name in ["original.wav", "processed.wav"] {
            let url = URL(fileURLWithPath: child.argument("--directory")).appendingPathComponent(name)
            try recordingFixtureWAV(frames: 240000, channels: 1).write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }
    func testEntryConstraintsNeverRequestPermissionOrLaunch() throws {
        var authorizations = 0, launches = 0
        let test = MicrophoneTestController(authorization: { authorizations += 1; return .denied }, requestAuthorization: { XCTFail("Unexpected prompt"); return false }, factory: { launches += 1; throw MicrophoneTestError.unavailable })
        test.start(input: try input(), microphoneUnmuted: false, routeStopped: true)
        test.start(input: try input(), microphoneUnmuted: true, routeStopped: false)
        test.start(input: try input(rate: 44100), microphoneUnmuted: true, routeStopped: true)
        XCTAssertEqual(authorizations, 0); XCTAssertEqual(launches, 0); XCTAssertFalse(test.engaged)
    }
    func testCancelDuringPermissionPreventsLateHelperLaunch() async throws {
        var permission: CheckedContinuation<Bool, Never>?, launched = 0
        let test = MicrophoneTestController(authorization: { .notDetermined }, requestAuthorization: { await withCheckedContinuation { permission = $0 } }, factory: { launched += 1; throw MicrophoneTestError.unavailable })
        test.start(input: try input(), microphoneUnmuted: true, routeStopped: true)
        try await wait { permission != nil }
        let cancelled = await test.cancelAndCleanup(); XCTAssertTrue(cancelled)
        permission?.resume(returning: true)
        try await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertEqual(launched, 0); XCTAssertFalse(test.engaged)
    }
    func testCompletedFilesWaitForExitAndCompareAtSamePlaybackPosition() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let child = FixtureTestChild(), player = FixtureComparisonPlayback(), test = controller(child, root: root, player: player)
        test.start(input: try input(), microphoneUnmuted: true, routeStopped: true)
        try await wait { child.running }
        XCTAssertTrue(child.arguments.contains("--control-stdin"))
        child.started(operation: UUID().uuidString); XCTAssertEqual(test.phase, .starting)
        child.started(); child.progress(120000); XCTAssertFalse(test.canStop)
        test.stop(); XCTAssertTrue(child.commands.isEmpty)
        child.progress(240000); test.stop(); XCTAssertEqual(child.commands.count, 1)
        try writeFiles(child); child.complete(); XCTAssertEqual(test.phase, .validating)
        let beforeExit = await player.configurations(); XCTAssertEqual(beforeExit, 0)
        child.finish(); try await wait { test.phase == .comparison }
        test.play(); try await wait { test.playing }
        test.select(.processed); try await wait { test.variant == .processed && test.playbackPosition == 1.25 }
        let playback = await player.snapshot(id: UUID()); XCTAssertEqual(playback?.position, 1.25)
        let removed = await test.cancelAndCleanup(); XCTAssertTrue(removed)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        XCTAssertFalse(test.engaged)
    }
    func testCancelIntentSuppressesLateCompletedResultAndRetainsUnconfirmedWriter() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let child = FixtureTestChild(), player = FixtureComparisonPlayback(), test = controller(child, root: root, player: player)
        test.start(input: try input(), microphoneUnmuted: true, routeStopped: true); try await wait { child.running }; child.started()
        child.exitOnTerminate = false; child.waitResult = false
        let unconfirmed = await test.cancelAndCleanup(); XCTAssertFalse(unconfirmed)
        child.complete()
        XCTAssertTrue(test.engaged); XCTAssertEqual(test.phase, .failed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: child.argument("--directory")))
        let configured = await player.configurations(); XCTAssertEqual(configured, 0)
        XCTAssertEqual(test.retainedPaths.count, 1)
        child.waitResult = true; child.finish()
        let cleaned = await test.cancelAndCleanup(); XCTAssertTrue(cleaned)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }
    func testSharedAdmissionBlocksInterleavedWindowStartsBeforePermission() async throws {
        var testPermission: CheckedContinuation<Bool, Never>?, testLaunches = 0, routeLaunches = 0
        let test = MicrophoneTestController(authorization: { .notDetermined }, requestAuthorization: { await withCheckedContinuation { testPermission = $0 } }, factory: { testLaunches += 1; throw MicrophoneTestError.unavailable })
        let snapshot = try JSONDecoder().decode(AudioInventory.self, from: Data("""
        {"devices":[{"uid":"mic","name":"Mic","alive":1,"nominal_rate":48000,"input":{"channels":1},"output":{"channels":0}},
                    {"uid":"speaker","name":"Speaker","alive":1,"nominal_rate":48000,"input":{"channels":0},"output":{"channels":2}}],
         "companion_devices":[{"uid":"dev.hari.labvoice.feed","present":true},{"uid":"dev.hari.labvoice.monitor","present":true}],"errors":[]}
        """.utf8))
        let route = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { XCTFail("Unexpected route prompt"); return false }, factory: { routeLaunches += 1; throw MicrophoneTestError.unavailable })
        await route.refresh(); route.inputUID = "mic"; route.outputUID = "speaker"
        test.start(input: try input(), microphoneUnmuted: true, routeStopped: true)
        try await wait { testPermission != nil }
        XCTAssertFalse(route.canStart); route.start(); XCTAssertEqual(routeLaunches, 0)
        _ = await test.cancelAndCleanup()
        route.start(); try await wait { routeLaunches == 1 && route.phase == .idle }
        testPermission?.resume(returning: true)
        try await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertEqual(testLaunches, 0); XCTAssertTrue(AudioCaptureAdmission.shared.available)
    }
    func testMismatchedStartupCancelsImmediatelyWithoutWaitingForDeadline() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let child = FixtureTestChild(), test = controller(child, root: root)
        test.start(input: try input(), microphoneUnmuted: true, routeStopped: true); try await wait { child.running }
        child.emit(["event": "test_started", "operationID": child.argument("--operation-id"), "input_uid": "wrong-input", "sampleRate": 48000, "channels": 1, "minimumFrames": 240000, "maximumFrames": 2880000])
        try await wait { !test.engaged }
        XCTAssertFalse(child.running); XCTAssertTrue(child.commands.contains { $0["type"] as? String == "test-cancel" })
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    func testCancelledSuspendedPrepareRetainsOwnershipWhenRemovalFails() async throws {
        for preparationFails in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let files = SuspendedTestFiles(root: root)
            var launches = 0
            let test = MicrophoneTestController(files: files, playback: FixtureComparisonPlayback(), authorization: { .authorized }, requestAuthorization: { false }, factory: { launches += 1; throw MicrophoneTestError.unavailable })
            test.start(input: try input(), microphoneUnmuted: true, routeStopped: true)
            for _ in 0..<1000 {
                if await files.suspended() { break }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            let cancellation = Task { await test.cancelAndCleanup() }
            try await wait { test.phase == .cancelling }
            await files.releasePrepare(failing: preparationFails)
            let removed = await cancellation.value
            XCTAssertFalse(removed); XCTAssertTrue(test.engaged); XCTAssertEqual(launches, 0)
            XCTAssertEqual(test.retainedPaths.count, 1)
            XCTAssertFalse(AudioCaptureAdmission.shared.available)
            await files.allowRemoval()
            let retried = await test.cancelAndCleanup()
            XCTAssertTrue(retried); XCTAssertFalse(test.engaged); XCTAssertTrue(AudioCaptureAdmission.shared.available)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        }
    }
    func testActualCppSyntheticCaptureAndRnnoisePairThenCleanup() async throws {
        let desktop = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let executable = desktop.deletingLastPathComponent().appendingPathComponent("audio-host/build/microphone-test-wire-fixture")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw NSError(domain: "Build audio-host ./verify before desktop tests: microphone test wire fixture missing", code: 1)
        }
        for cancel in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let child = CppMicrophoneTestChild(url: executable), player = FixtureComparisonPlayback()
            let test = MicrophoneTestController(files: MicrophoneTestFiles(root: root), playback: player,
                authorization: { .authorized }, requestAuthorization: { XCTFail("Unexpected OS prompt"); return false }, factory: { child })
            test.start(input: try input(), microphoneUnmuted: true, routeStopped: true)
            try await wait { child.running }
            if !cancel {
                try await wait { test.canStop }
                test.stop()
                try await wait { test.phase == .comparison || test.phase == .failed }
                XCTAssertEqual(test.phase, .comparison, test.error ?? "No error supplied")
                XCTAssertEqual(test.frames, 240000)
                let configured = await player.configurations(); XCTAssertEqual(configured, 1)
                XCTAssertFalse(test.playing)
            }
            let cleaned = await test.cancelAndCleanup()
            XCTAssertTrue(cleaned); XCTAssertFalse(test.engaged)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        }
    }

}
