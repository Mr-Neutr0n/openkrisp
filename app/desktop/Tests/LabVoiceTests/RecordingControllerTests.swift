import XCTest
import Foundation
import LocalStore
@testable import LabVoice

private actor SuspendedFailureStorage: RecordingStoring {
    let base: RecordingStorage
    var suspension: CheckedContinuation<Void, Error>?
    init(_ base: RecordingStorage) { self.base = base }
    func prepare(operationID: UUID, location: LibraryLocationSnapshot) async throws -> RecordingJob { try await base.prepare(operationID: operationID, location: location) }
    func retainedDirectories() async throws -> [String] { try await base.retainedDirectories() }
    func retainFailure(_ job: RecordingJob, message: String) async throws {
        try await withCheckedThrowingContinuation { suspension = $0 }
    }
    func isSuspended() -> Bool { suspension != nil }
    func releaseFailure() { suspension?.resume(throwing: NSError(domain: "Old failure persistence error", code: 1)); suspension = nil }
    func saveCompleted(_ job: RecordingJob, path: String, frames: UInt64, sampleRate: Double, channels: UInt32) async throws -> RecordingSave {
        try await base.saveCompleted(job, path: path, frames: frames, sampleRate: sampleRate, channels: channels)
    }
}

@MainActor final class RecordingControllerTests: XCTestCase {
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        throw NSError(domain: "Recording fixture timed out", code: 1)
    }
    private func ack(_ command: [String: Any], accepted: Bool = true, operation: String? = nil) -> String {
        var object = command
        object.removeValue(forKey: "path")
        object["type"] = "recording-ack"; object["action"] = String((command["type"] as! String).dropFirst(10))
        object["accepted"] = accepted
        if !accepted { object["error"] = "fixture rejection" }
        if let operation { object["operationID"] = operation }
        return String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }
    func testExplicitStartPauseResumeAndUnexpectedExitRetainedAcrossRestart() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: root.appendingPathComponent("sessions"))
        let controller = RecordingController(storage: storage), id = UUID()
        var commands: [[String: Any]] = []
        controller.start(); XCTAssertEqual(controller.phase, .idle)
        controller.attach(operationID: id) { commands.append(try JSONSerialization.jsonObject(with: $0) as! [String: Any]) }
        XCTAssertTrue(commands.isEmpty); XCTAssertEqual(controller.phase, .idle)
        controller.start(); try await wait { commands.count == 1 }
        controller.receive(ack(commands[0], operation: UUID().uuidString), operationID: id)
        XCTAssertEqual(controller.phase, .starting)
        controller.receive(ack(commands[0]), operationID: id)
        XCTAssertEqual(controller.phase, .recording)
        controller.pauseOrResume(); XCTAssertEqual(controller.phase, .pausing)
        controller.receive(ack(commands[1]), operationID: id); XCTAssertEqual(controller.phase, .paused)
        controller.pauseOrResume(); controller.receive(ack(commands[2]), operationID: id)
        XCTAssertEqual(controller.phase, .recording)
        await controller.helperExited(operationID: id)
        XCTAssertFalse(controller.busy); XCTAssertNil(controller.savedSessionID)
        XCTAssertNotNil(controller.error)
        let restarted = RecordingController(storage: storage)
        await restarted.refreshRetained()
        XCTAssertEqual(restarted.retainedPaths.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("sessions").path))
        controller.receive(ack(commands[0]), operationID: id)
        XCTAssertFalse(controller.busy)
    }
    func testRejectedStartAndLostAckNeverClaimSaved() async throws {
        for reject in [true, false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: root.appendingPathComponent("sessions"))
            let controller = RecordingController(storage: storage, timeout: 5_000_000), id = UUID()
            var commands: [[String: Any]] = []
            controller.attach(operationID: id) { commands.append(try JSONSerialization.jsonObject(with: $0) as! [String: Any]) }
            controller.start(); try await wait { !commands.isEmpty }
            if reject { controller.receive(ack(commands[0], accepted: false), operationID: id) }
            try await wait { controller.error != nil }
            XCTAssertNil(controller.savedSessionID)
            if !reject { XCTAssertEqual(controller.phase, .uncertain); XCTAssertFalse(controller.canStart) }
            await controller.helperExited(operationID: id)
            await controller.refreshRetained()
            XCTAssertEqual(controller.retainedPaths.count, 1)
        }
    }
    func testActualPipeFinalizationImportsSyntheticWavDuringRouteStop() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeRoot = root.appendingPathComponent("sessions")
        let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: storeRoot)
        let controller = RecordingController(storage: storage), id = UUID()
        let child = SystemAudioHelperChild(url: URL(fileURLWithPath: "/usr/bin/python3"))
        // Writes deterministic PCM16 fixtures only. It opens no capture or playback device.
        let script = """
        import sys,json,os,wave,struct
        active=None
        for row in sys.stdin:
            command=json.loads(row); action=command['type'][10:]
            if action=='start':
                path=command['path']; fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
                active=(command,os.fdopen(fd,'wb'))
            ack={k:command[k] for k in ('operationID','sequence','recordingID')}
            ack.update(type='recording-ack',action=action,accepted=True)
            print(json.dumps(ack),flush=True)
            if action=='stop':
                original,handle=active
                with wave.open(handle,'wb') as output:
                    output.setnchannels(2); output.setsampwidth(2); output.setframerate(48000)
                    output.writeframes(b''.join(struct.pack('<hh',i%100,-(i%100)) for i in range(480)))
                handle.close()
                result={'type':'recording-result','operationID':original['operationID'],'recordingID':original['recordingID'],
                        'status':'completed','path':original['path'],'frames':480,'sampleRate':48000,'channels':2}
                print(json.dumps(result),flush=True)
        """
        try child.launch(arguments: ["-u", "-c", script], line: { controller.receive($0, operationID: id) }, exit: { _ in })
        defer { child.terminate() }
        controller.attach(operationID: id) { try child.send($0) }
        controller.start(); try await wait { controller.phase == .recording }
        await controller.prepareForRouteStop()
        XCTAssertEqual(controller.phase, .idle)
        XCTAssertNotNil(controller.savedSessionID)
        let store = try LocalStore(root: storeRoot)
        let session = try XCTUnwrap(store.inventory().sessions.first)
        XCTAssertEqual(session.durationSeconds, 0.01); XCTAssertTrue(session.transcript.isEmpty)
        XCTAssertTrue(controller.retainedPaths.isEmpty)
        child.terminate(); _ = await child.waitForExit(timeoutNanoseconds: 2_000_000_000)
        await controller.helperExited(operationID: id)
        XCTAssertFalse(controller.busy)
    }
    func testOldSuspendedFailureCannotOverwriteNewRecording() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = SuspendedFailureStorage(RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: root.appendingPathComponent("sessions")))
        let controller = RecordingController(storage: storage), id = UUID()
        var commands: [[String: Any]] = []
        controller.attach(operationID: id) { commands.append(try JSONSerialization.jsonObject(with: $0) as! [String: Any]) }
        controller.start(); try await wait { commands.count == 1 }
        controller.receive(ack(commands[0], accepted: false), operationID: id)
        for _ in 0..<1000 {
            if await storage.isSuspended() { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let suspended = await storage.isSuspended(); XCTAssertTrue(suspended)
        controller.start(); try await wait { commands.count == 2 }
        controller.receive(ack(commands[1]), operationID: id)
        XCTAssertEqual(controller.phase, .recording); XCTAssertNil(controller.error)
        await storage.releaseFailure()
        try await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertEqual(controller.phase, .recording); XCTAssertNil(controller.error)
        // Finish this fixture without suspending another failure operation.
        let completion = Task { await controller.helperExited(operationID: id) }
        for _ in 0..<1000 {
            if await storage.isSuspended() { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        await storage.releaseFailure(); await completion.value
    }

    func testActualCppRecordingProtocolWritesOnlyActiveSyntheticFrames() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeRoot = root.appendingPathComponent("sessions")
        let controller = RecordingController(storage: RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: storeRoot))
        let desktop = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let executable = desktop.deletingLastPathComponent().appendingPathComponent("audio-host/build/recording-wire-fixture")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw NSError(domain: "Build audio-host ./verify before desktop tests: recording-wire-fixture missing", code: 1)
        }
        let id = UUID(), child = SystemAudioHelperChild(url: executable)
        try child.launch(arguments: [id.uuidString], line: { controller.receive($0, operationID: id) }, exit: { _ in })
        defer { child.terminate() }
        controller.attach(operationID: id) { try child.send($0) }
        controller.start(); try await wait { controller.phase == .recording }
        controller.pauseOrResume(); try await wait { controller.phase == .paused }
        controller.pauseOrResume(); try await wait { controller.phase == .recording }
        controller.stop(); try await wait { controller.savedSessionID != nil }
        let store = try LocalStore(root: storeRoot)
        let session = try XCTUnwrap(store.inventory().sessions.first)
        XCTAssertEqual(session.durationSeconds, 32.0 / 48000)
        let wav = try XCTUnwrap(store.recordingURL(for: session.id))
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: wav.path)[.posixPermissions] as? NSNumber, NSNumber(value: 0o600))
        XCTAssertTrue(controller.retainedPaths.isEmpty)
        child.terminate(); _ = await child.waitForExit(timeoutNanoseconds: 2_000_000_000)
        await controller.helperExited(operationID: id)
    }

}
