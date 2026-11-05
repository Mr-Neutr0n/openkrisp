import XCTest
import Foundation
@testable import LabVoice

@MainActor final class AudioControlPipeTests: XCTestCase {
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        throw NSError(domain: "Fixture pipe response timed out", code: 1)
    }
    func testRealPipeRoundtripAndClosedLifecycle() async throws {
        let child = SystemAudioHelperChild(url: URL(fileURLWithPath: "/usr/bin/python3"))
        var rows: [String] = [], exited = false
        // This child only reads JSON and writes JSON. It never opens audio devices.
        let script = """
        import sys,json
        print('ready',flush=True)
        for row in sys.stdin:
            value=json.loads(row)
            value['type']='controls-ack'
            value['accepted']=True
            print(json.dumps(value),flush=True)
        """
        try child.launch(arguments: ["-u", "-c", script], line: { rows.append($0) }, exit: { _ in exited = true })
        defer { child.terminate() }
        try await wait { rows.contains("ready") }
        let id = UUID()
        var snapshot = AudioControlSnapshot()
        snapshot.microphone.gain = Double(Float(0.37)); snapshot.speaker.muted = true
        try child.send(AudioControlCommand(id: id, sequence: 1, snapshot: snapshot).line())
        try await wait { rows.count == 2 }
        let ack = try JSONDecoder().decode(AudioControlAcknowledgment.self, from: Data(rows[1].utf8))
        XCTAssertEqual(ack.operationID, id.uuidString)
        XCTAssertEqual(ack.sequence, 1); XCTAssertTrue(ack.accepted)
        XCTAssertEqual(ack.snapshot, snapshot)
        XCTAssertThrowsError(try child.send(Data(repeating: 10, count: 513)))
        child.terminate()
        let ended = await child.waitForExit(timeoutNanoseconds: 2_000_000_000)
        XCTAssertTrue(ended); XCTAssertTrue(exited)
        XCTAssertThrowsError(try child.send(AudioControlCommand(id: id, sequence: 2, snapshot: snapshot).line()))
    }
    func testChildClosedStdinReportsErrorWithoutSIGPIPE() async throws {
        let child = SystemAudioHelperChild(url: URL(fileURLWithPath: "/usr/bin/python3"))
        var ready = false
        try child.launch(arguments: ["-u", "-c", "import os,time; os.close(0); print('closed',flush=True); time.sleep(5)"],
                         line: { ready = $0 == "closed" }, exit: { _ in })
        defer { child.terminate() }
        try await wait { ready }
        XCTAssertThrowsError(try child.send(Data("{}\n".utf8)))
        child.terminate()
        let ended = await child.waitForExit(timeoutNanoseconds: 2_000_000_000)
        XCTAssertTrue(ended)
    }
    func testTerminateLetsHelperCloseItsOwnedWorker() async throws {
        let child = SystemAudioHelperChild(url: URL(fileURLWithPath: "/usr/bin/python3"))
        var rows: [String] = [], result: HelperExit?
        // The grandchild must remain alive until the helper sends close and
        // receives its acknowledgment. Group SIGTERM reproduces the GUI bug.
        let script = """
        import signal,subprocess,sys,time
        stopping=False
        def stop(signum,frame):
         global stopping
         stopping=True
        signal.signal(signal.SIGTERM,stop)
        worker=subprocess.Popen([sys.executable,'-u','-c',"import sys; print('ready',flush=True); assert sys.stdin.readline().strip()=='close'; print('closed',flush=True)"],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
        assert worker.stdout.readline().strip()=='ready'
        print('ready',flush=True)
        sys.stdin.read()
        while not stopping:time.sleep(.001)
        time.sleep(.05)
        try:
         worker.stdin.write('close\\n');worker.stdin.flush();worker.stdin.close()
         output=worker.stdout.read();status=worker.wait(timeout=2)
        except Exception:
         output='';status=worker.wait(timeout=2)
        okay=status==0 and output.strip()=='closed'
        print('worker_closed' if okay else 'worker_close_failed',flush=True)
        sys.exit(0 if okay else 1)
        """
        try child.launch(arguments: ["-u", "-c", script], line: { rows.append($0) }, exit: { result = $0 })
        defer { child.terminate() }
        try await wait { rows.contains("ready") }
        child.terminate()
        let ended = await child.waitForExit(timeoutNanoseconds: 5_000_000_000)
        XCTAssertTrue(ended)
        let event = try XCTUnwrap(result)
        XCTAssertEqual(event.status, 0, event.diagnostic)
        XCTAssertTrue(rows.contains("worker_closed"))
        XCTAssertFalse(child.running)
    }
    func testSwiftSnapshotAgainstActualCppControlProtocol() async throws {
        let desktop = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = desktop.deletingLastPathComponent().appendingPathComponent("audio-host/build/control-wire-fixture")
        guard FileManager.default.isExecutableFile(atPath: fixture.path) else {
            throw NSError(domain: "Build audio-host ./verify before desktop tests: control-wire-fixture is missing", code: 1)
        }
        let id = UUID(), child = SystemAudioHelperChild(url: fixture)
        var rows: [String] = []
        try child.launch(arguments: [id.uuidString], line: { rows.append($0) }, exit: { _ in })
        defer { child.terminate() }
        var desired = AudioControlSnapshot()
        desired.microphone.gain = Double(Float(0.37)); desired.microphone.muted = true
        desired.speaker.gain = Double(Float(0.73))
        try child.send(AudioControlCommand(id: id, sequence: 1, snapshot: desired).line())
        try await wait { !rows.isEmpty }
        let ack = try JSONDecoder().decode(AudioControlAcknowledgment.self, from: Data(rows[0].utf8))
        XCTAssertEqual(ack.operationID, id.uuidString); XCTAssertEqual(ack.sequence, 1)
        XCTAssertTrue(ack.accepted, ack.error ?? "No rejection reason")
        XCTAssertEqual(ack.snapshot, desired)
        child.terminate()
        let ended = await child.waitForExit(timeoutNanoseconds: 2_000_000_000)
        XCTAssertTrue(ended)
    }

}
