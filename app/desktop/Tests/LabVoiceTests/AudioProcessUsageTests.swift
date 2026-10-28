import XCTest
@testable import LabVoice

@MainActor final class AudioProcessUsageTests: XCTestCase {
    private func fixture() throws -> Data {
        let desktop = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let host = desktop.deletingLastPathComponent().appendingPathComponent("audio-host")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let binary = directory.appendingPathComponent("fixture")
        let compile = Process(); compile.executableURL = URL(fileURLWithPath: "/usr/bin/clang++")
        compile.arguments = ["-std=c++20", "-mmacosx-version-min=12.0", host.appendingPathComponent("audio_process_usage.cpp").path, host.appendingPathComponent("audio_process_usage_test.cpp").path, "-o", binary.path]
        try compile.run(); compile.waitUntilExit(); XCTAssertEqual(compile.terminationStatus, 0)
        let process = Process(), pipe = Pipe(); process.executableURL = binary; process.arguments = ["--emit-fixture"]; process.standardOutput = pipe
        try process.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
        return data
    }
    func testProductionCppFormatterDecodesDirectionErrorsPIDsAndUnfilteredDeviceUID() throws {
        let data = try fixture(), value = try JSONDecoder().decode(AudioProcessSnapshot.self, from: data)
        XCTAssertEqual(value.status, "available"); XCTAssertTrue(value.summary.contains("incomplete"))
        let process = try XCTUnwrap(value.processes.first)
        XCTAssertEqual(process.actualPID, 11); XCTAssertEqual(process.responsiblePID, 22)
        XCTAssertEqual(process.appID, "owner.bundle"); XCTAssertEqual(process.processBundleID, "process.bundle")
        XCTAssertEqual(process.input.running, true); XCTAssertEqual(process.output.running, false)
        XCTAssertEqual(process.input.devices?.first?.uid, "dev.hari.labvoice.feed")
        XCTAssertNil(process.input.devices?.last?.uid); XCTAssertFalse(process.errors.isEmpty)
        XCTAssertEqual(process.output.description, "not running")
    }
    func testUnknownDirectionAndSourceFailureAreNotEmptyIdleObservations() throws {
        let unknown = try JSONDecoder().decode(AudioProcessDirection.self, from: Data("{\"running\":null,\"devices\":null}".utf8))
        XCTAssertEqual(unknown.description, "unknown")
        let runningUnknown = try JSONDecoder().decode(AudioProcessDirection.self, from: Data("{\"running\":true,\"devices\":null}".utf8))
        XCTAssertEqual(runningUnknown.description, "running, device usage unknown")
        let source = try JSONDecoder().decode(AudioProcessSnapshot.self, from: Data("{\"status\":\"failed\",\"processes\":[],\"errors\":[\"read failed\"]}".utf8))
        XCTAssertTrue(source.summary.contains("unknown"))
        let old = try JSONDecoder().decode(AudioInventory.self, from: Data("{\"devices\":[],\"companion_devices\":[],\"errors\":[]}".utf8))
        XCTAssertNil(old.audioProcessUsage)
    }
    func testObservationIsExplicitAndUsesExistingCancellationFence() async throws {
        let data = try fixture(), usage = try JSONSerialization.jsonObject(with: data)
        let observed = try JSONDecoder().decode(AudioInventory.self, from: JSONSerialization.data(withJSONObject: ["devices": [], "companion_devices": [], "errors": [], "audio_process_usage": usage]))
        let ordinary = try JSONDecoder().decode(AudioInventory.self, from: Data("{\"devices\":[],\"companion_devices\":[],\"errors\":[]}".utf8))
        var ordinaryReads = 0, observationReads = 0, pauseObservation = true, pending: CheckedContinuation<AudioInventory, Error>?
        let controller = AudioRouteController(readInventory: { ordinaryReads += 1; return ordinary }, readAudioUse: { observationReads += 1; if pauseObservation { return try await withCheckedThrowingContinuation { pending = $0 } }; return observed }, authorization: { XCTFail("No permission"); return .authorized }, requestAuthorization: { XCTFail("No permission"); return false }, factory: { throw AudioHelperError.missingHelper })
        await controller.refresh(); XCTAssertEqual(ordinaryReads, 1); XCTAssertEqual(observationReads, 0)
        let task = Task { await controller.observeAudioUse() }
        for _ in 0..<1000 { if pending != nil { break }; try await Task.sleep(nanoseconds: 1_000_000) }
        let stopped = await controller.stop(); XCTAssertTrue(stopped)
        pending?.resume(returning: observed); await task.value
        XCTAssertNil(controller.inventory?.audioProcessUsage)
        XCTAssertEqual(observationReads, 1); XCTAssertFalse(controller.loading)
        XCTAssertNil(controller.audioUseObservedAt)
        pauseObservation = false; await controller.observeAudioUse()
        XCTAssertNotNil(controller.inventory?.audioProcessUsage); XCTAssertNotNil(controller.audioUseObservedAt)
        await controller.refresh(); XCTAssertNil(controller.inventory?.audioProcessUsage); XCTAssertNil(controller.audioUseObservedAt)
    }
}
