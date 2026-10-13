import XCTest
import Foundation
import AVFoundation
@testable import LabVoice

@MainActor private final class FakeAudioChild: AudioHelperChild {
    var running = false
    var arguments: [String] = []
    var terminateCount = 0
    var waitCount = 0
    var waitResult = true
    var exitOnTerminate = true
    var failLaunch = false
    private var lineHandler: ((String) -> Void)?
    private var exitHandler: ((HelperExit) -> Void)?
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        if failLaunch { throw AudioHelperError.missingHelper }
        self.arguments = arguments; lineHandler = line; exitHandler = exit; running = true
    }
    var commands: [[String: Any]] = []
    var failSend = false
    func send(_ line: Data) throws {
        if failSend { throw AudioHelperError.controlChannelClosed }
        commands.append(try JSONSerialization.jsonObject(with: line) as! [String: Any])
    }
    func acknowledge(_ index: Int, accepted: Bool = true, operation: String? = nil, sequence: Int? = nil) {
        var value = commands[index]
        value["type"] = "controls-ack"; value["accepted"] = accepted
        if let operation { value["operationID"] = operation }
        if let sequence { value["sequence"] = sequence }
        if !accepted { value["error"] = "fixture rejection" }
        line(String(decoding: try! JSONSerialization.data(withJSONObject: value), as: UTF8.self))
    }
    func line(_ value: String) { lineHandler?(value) }
    func ready(input: String = "mic", output: String = "speaker", microphone: Bool = false, speaker: Bool = false) {
        func argument(_ key: String) -> String? {
            guard let index = arguments.firstIndex(of: key), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        let value: [String: Any] = ["operationID": argument("--operation-id") ?? "",
                                    "microphone": ["muted": arguments.contains("--microphone-muted"), "gain": Double(argument("--microphone-gain") ?? "1")!],
                                    "speaker": ["muted": arguments.contains("--speaker-muted"), "gain": Double(argument("--speaker-gain") ?? "1")!],
                                    "event": "route_started", "input_uid": input, "output_uid": output,
                                    "microphone_noise": microphone, "speaker_noise": speaker]
        let data = try! JSONSerialization.data(withJSONObject: value)
        line(String(decoding: data, as: UTF8.self))
    }
    func finish(status: Int32 = 0, diagnostic: String = "") {
        running = false
        exitHandler?(HelperExit(status: status, output: Data(), diagnostic: diagnostic))
    }
    func terminate() { terminateCount += 1; if exitOnTerminate { finish() } }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { waitCount += 1; return waitResult }
}

@MainActor final class AudioRouteTests: XCTestCase {
    private func inventory(driver: Bool = true, rate: Double = 48000) throws -> AudioInventory {
        let data = """
        {"devices":[{"uid":"mic","name":"Microphone","alive":1,"nominal_rate":\(rate),"input":{"channels":1},"output":{"channels":0}},
                    {"uid":"speaker","name":"Speaker","alive":1,"nominal_rate":48000,"input":{"channels":0},"output":{"channels":2}}],
         "companion_devices":[{"uid":"dev.hari.labvoice.feed","present":\(driver)}, {"uid":"dev.hari.labvoice.monitor","present":\(driver)}],"errors":[]}
        """.data(using: .utf8)!
        return try JSONDecoder().decode(AudioInventory.self, from: data)
    }
    private func ready(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Expected audio lifecycle transition did not arrive")
    }
    private func model(_ child: FakeAudioChild, driver: Bool = true, rate: Double = 48000,
                       timeout: UInt64 = 10_000_000_000) throws -> AudioRouteController {
        let snapshot = try inventory(driver: driver, rate: rate)
        return AudioRouteController(readInventory: { snapshot }, authorization: { .authorized },
                                    requestAuthorization: { XCTFail("Unexpected mic request"); return false },
                                    factory: { child }, startupTimeout: timeout)
    }
    private func select(_ model: AudioRouteController) { model.inputUID = "mic"; model.outputUID = "speaker" }
    func testInventoryAndChoicesDoNotRequestPermissionOrLaunchRoute() async throws {
        let child = FakeAudioChild()
        var requests = 0, launches = 0
        let snapshot = try inventory()
        let model = AudioRouteController(readInventory: { snapshot }, authorization: { .notDetermined },
            requestAuthorization: { requests += 1; return true }, factory: { launches += 1; return child })
        await model.refresh()
        XCTAssertEqual(model.inputUID, "")
        XCTAssertEqual(model.outputUID, "")
        XCTAssertFalse(model.canStart)
        select(model)
        XCTAssertTrue(model.canStart)
        XCTAssertEqual(requests, 0); XCTAssertEqual(launches, 0)
    }
    func testActualHandshakeControlsRunningAndOptionalProcessing() async throws {
        let child = FakeAudioChild()
        let route = try self.model(child)
        await route.refresh(); select(route); route.microphoneNoise = true; route.speakerNoise = true
        route.start()
        try await ready { child.running }
        XCTAssertEqual(route.phase, .starting)
        XCTAssertNil(route.activeOptions)
        XCTAssertEqual(Array(child.arguments.prefix(7)), ["--route", "--input", "mic", "--output", "speaker", "--microphone-noise-suppression", "--speaker-noise-suppression"])
        child.line("Route started. Physical microphone: mic")
        XCTAssertEqual(route.phase, .starting)
        child.ready(microphone: true, speaker: true)
        XCTAssertEqual(route.phase, .running)
        XCTAssertTrue(route.activeOptions?.microphoneNoise == true)
        XCTAssertTrue(route.activeOptions?.speakerNoise == true)
        let stopped = await route.stop()
        XCTAssertTrue(stopped)
        XCTAssertEqual(child.terminateCount, 1)
        XCTAssertEqual(child.waitCount, 1)
        XCTAssertEqual(route.phase, .idle)
        XCTAssertNil(route.activeOptions)
    }
    func testReadyFromAlreadyExitedProcessNeverEnablesAudio() async throws {
        let child = FakeAudioChild()
        let model = try self.model(child)
        await model.refresh(); select(model); model.start()
        try await ready { child.running }
        child.running = false
        child.ready()
        XCTAssertEqual(model.phase, .starting)
        XCTAssertNil(model.activeOptions)
        child.finish()
        XCTAssertEqual(model.phase, .idle)
    }
    func testCancelDuringPermissionPreventsLaunch() async throws {
        let child = FakeAudioChild()
        let snapshot = try inventory()
        var prompt: CheckedContinuation<Bool, Never>?, requested = 0, launched = 0
        let route = AudioRouteController(readInventory: { snapshot }, authorization: { .notDetermined }, requestAuthorization: {
            requested += 1; return await withCheckedContinuation { prompt = $0 }
        }, factory: { launched += 1; return child })
        await route.refresh(); select(route); route.start()
        try await ready { requested == 1 }
        let stopped = await route.stop()
        XCTAssertTrue(stopped)
        prompt?.resume(returning: true)
        try await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertEqual(launched, 0); XCTAssertEqual(route.phase, .idle)
    }
    func testDeniedPermissionNeverLaunchesHelper() async throws {
        let child = FakeAudioChild(), snapshot = try inventory()
        var launched = 0
        let route = AudioRouteController(readInventory: { snapshot }, authorization: { .denied },
            requestAuthorization: { XCTFail("Denied permission must not prompt again"); return false },
            factory: { launched += 1; return child })
        await route.refresh(); select(route); route.start()
        try await ready { route.phase == .idle }
        XCTAssertEqual(launched, 0); XCTAssertNotNil(route.error)
    }
    func testMissingDriverOrMismatchedRateBlocksStart() async throws {
        for route in [try model(FakeAudioChild(), driver: false), try model(FakeAudioChild(), rate: 24000)] {
            await route.refresh(); select(route)
            XCTAssertFalse(route.canStart)
            route.start(); XCTAssertEqual(route.phase, .idle)
        }
    }
    func testStartupFailureIsReportedWithoutEnabledState() async throws {
        let child = FakeAudioChild()
        let model = try self.model(child)
        await model.refresh(); select(model); model.start()
        try await ready { child.running }
        child.finish(status: 1, diagnostic: "aggregate creation failed")
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.activeOptions)
        XCTAssertEqual(model.error, "aggregate creation failed")
    }
    func testStopWaitsAndFailureKeepsLifecycleEngagedForRetry() async throws {
        let child = FakeAudioChild()
        let model = try self.model(child)
        await model.refresh(); select(model); model.start()
        try await ready { child.running }; child.ready()
        child.exitOnTerminate = false; child.waitResult = false
        let firstStop = await model.stop()
        XCTAssertFalse(firstStop)
        XCTAssertEqual(model.phase, .stopping)
        XCTAssertTrue(model.engaged)
        XCTAssertFalse(model.canStart)
        XCTAssertNotNil(model.error)
        child.exitOnTerminate = true; child.waitResult = true
        let secondStop = await model.stop()
        XCTAssertTrue(secondStop)
        XCTAssertEqual(model.phase, .idle)
        XCTAssertFalse(model.engaged)
    }
    func testStartupTimeoutStopsUnconfirmedChild() async throws {
        let child = FakeAudioChild()
        let route = try model(child, timeout: 5_000_000)
        await route.refresh(); select(route); route.start()
        try await ready { child.terminateCount == 1 }
        XCTAssertEqual(route.phase, .idle)
        XCTAssertNil(route.activeOptions)
        XCTAssertNotNil(route.error)
    }
    func testStaleMismatchStopCannotStopNewRoute() async throws {
        let old = FakeAudioChild(), new = FakeAudioChild(), snapshot = try inventory()
        var created = 0
        let route = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: {
            defer { created += 1 }; return created == 0 ? old : new
        })
        await route.refresh(); select(route); route.start()
        try await ready { old.running }
        old.ready(input: "wrong") // Queues Stop for the old operation.
        old.finish() // Clears that operation before the queued task runs.
        route.start() // A new operation begins synchronously before yielding.
        try await ready { new.running }
        XCTAssertEqual(new.terminateCount, 0)
        new.ready(); XCTAssertEqual(route.phase, .running)
        let stopped = await route.stop()
        XCTAssertTrue(stopped)
    }
    func testControlsCanonicalStartupCoalescingAndAcknowledgment() async throws {
        let child = FakeAudioChild(), route = try model(child)
        await route.refresh(); select(route)
        route.setMicrophonePercent(37); route.setMicrophoneMuted(true)
        route.start(); try await ready { child.running }
        route.setMicrophonePercent(80) // Locked while starting.
        XCTAssertEqual(route.desiredControls.microphone.gain, Double(Float(0.37)))
        child.ready(); XCTAssertEqual(route.confirmedControls, route.desiredControls)
        route.setMicrophonePercent(40); route.setMicrophonePercent(50); route.setSpeakerMuted(true)
        XCTAssertEqual(child.commands.count, 1); XCTAssertTrue(route.controlPending)
        child.acknowledge(0, operation: UUID().uuidString)
        child.acknowledge(0, sequence: 99)
        XCTAssertTrue(route.controlPending); XCTAssertEqual(child.commands.count, 1)
        child.acknowledge(0)
        XCTAssertEqual(child.commands.count, 2); XCTAssertTrue(route.controlPending)
        XCTAssertEqual(route.confirmedControls?.microphone.gain, Double(Float(0.4)))
        child.acknowledge(1)
        XCTAssertFalse(route.controlPending); XCTAssertEqual(route.confirmedControls, route.desiredControls)
        _ = await route.stop()
        child.acknowledge(1); XCTAssertNil(route.confirmedControls)
    }
    func testRejectedAndFailedControlsRetainLastAcceptedValues() async throws {
        let child = FakeAudioChild(), route = try model(child)
        await route.refresh(); select(route); route.start(); try await ready { child.running }; child.ready()
        let original = route.confirmedControls
        route.setSpeakerPercent(20); child.acknowledge(0, accepted: false)
        XCTAssertEqual(route.confirmedControls, original); XCTAssertNotNil(route.controlError)
        route.retryControls(); child.acknowledge(1)
        XCTAssertEqual(route.confirmedControls, route.desiredControls)
        let accepted = route.confirmedControls
        child.failSend = true; route.setSpeakerMuted(true)
        XCTAssertFalse(route.controlPending); XCTAssertNotNil(route.controlError)
        XCTAssertEqual(route.confirmedControls, accepted)
        _ = await route.stop()
    }
    func testControlTimeoutAndOldOperationCannotAffectReplacement() async throws {
        let old = FakeAudioChild(), new = FakeAudioChild(), snapshot = try inventory()
        var created = 0
        let route = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: {
            defer { created += 1 }; return created == 0 ? old : new
        }, controlTimeout: 5_000_000)
        await route.refresh(); select(route); route.start(); try await ready { old.running }; old.ready()
        route.setMicrophonePercent(30)
        try await ready { route.controlError != nil }
        XCTAssertNil(route.confirmedControls)
        route.setMicrophonePercent(100)
        XCTAssertEqual(old.commands.count, 2) // The lost ACK may have published 30%; 100% must be sent.
        _ = await route.stop(); route.start(); try await ready { new.running }; new.ready()
        old.acknowledge(0)
        XCTAssertEqual(route.confirmedControls, route.desiredControls); XCTAssertEqual(new.commands.count, 0)
        XCTAssertEqual(new.terminateCount, 0)
        _ = await route.stop()
    }

    func testRouteStopConsumesRecordingCompletionBeforeHelperExit() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeRoot = root.appendingPathComponent("sessions")
        let recorder = RecordingController(storage: RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: storeRoot))
        let child = FakeAudioChild(), snapshot = try inventory()
        let route = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { child }, recording: recorder)
        await route.refresh(); select(route); route.start(); try await ready { child.running }; child.ready()
        recorder.start(); try await ready { child.commands.count == 1 }
        let initial = child.commands[0]
        func ack(_ value: [String: Any], action: String) {
            child.line(String(decoding: try! JSONSerialization.data(withJSONObject: ["type": "recording-ack", "operationID": value["operationID"]!, "recordingID": value["recordingID"]!, "sequence": value["sequence"]!, "action": action, "accepted": true]), as: UTF8.self))
        }
        ack(initial, action: "start"); XCTAssertEqual(recorder.phase, .recording)
        let stop = Task { await route.stop() }
        try await ready { child.commands.count == 2 }
        XCTAssertEqual(route.phase, .stopping); XCTAssertEqual(child.terminateCount, 0)
        let path = initial["path"] as! String
        try recordingFixtureWAV().write(to: URL(fileURLWithPath: path))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        ack(child.commands[1], action: "stop")
        child.line(String(decoding: try JSONSerialization.data(withJSONObject: ["type": "recording-result", "operationID": initial["operationID"]!, "recordingID": initial["recordingID"]!, "status": "completed", "path": path, "frames": 480, "sampleRate": 48000, "channels": 2]), as: UTF8.self))
        let ended = await stop.value
        XCTAssertTrue(ended); XCTAssertEqual(route.phase, .idle)
        XCTAssertNotNil(recorder.savedSessionID); XCTAssertFalse(recorder.busy)
        XCTAssertEqual(child.terminateCount, 1)
    }

}
