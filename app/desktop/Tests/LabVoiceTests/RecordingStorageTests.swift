import XCTest
import Foundation
import AVFoundation
import LocalStore
@testable import LabVoice

func recordingFixtureWAV(frames: UInt32 = 480, channels: UInt16 = 2) -> Data {
        var result = Data()
        func text(_ value: String) { result.append(Data(value.utf8)) }
        func word<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; withUnsafeBytes(of: &little) { result.append(contentsOf: $0) } }
        let dataSize = frames * UInt32(channels) * 2
        text("RIFF"); word(UInt32(36) + dataSize); text("WAVEfmt "); word(UInt32(16))
        word(UInt16(1)); word(channels); word(UInt32(48000)); word(UInt32(48000) * UInt32(channels) * 2)
        word(channels * 2); word(UInt16(16)); text("data"); word(dataSize)
        for frame in 0..<frames { for channel in 0..<channels { word(Int16((Int(frame) * 7 + Int(channel) * 17) % 500)) } }
        return result
    }

final class RecordingStorageTests: XCTestCase {
    func testFinalizedSyntheticRecordingPreservesExistingHistoryAndTranscript() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeRoot = root.appendingPathComponent("sessions")
        let existingStore = try LocalStore(root: storeRoot)
        let existing = try existingStore.save(title: "Existing", startedAt: Date(), durationSeconds: 1,
            transcript: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "Keep this text")])
        let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: storeRoot)
        let job = try await storage.prepare(operationID: UUID())
        let metadata = job.directory.appendingPathComponent("job.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: metadata.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        try recordingFixtureWAV().write(to: job.wav)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: job.wav.path)
        let saved = try await storage.saveCompleted(job, path: job.wav.path, frames: 480, sampleRate: 48000, channels: 2)
        XCTAssertEqual(saved.session.durationSeconds, 0.01)
        XCTAssertTrue(saved.session.transcript.isEmpty)
        XCTAssertEqual(try existingStore.load(existing.id), existing)
        XCTAssertEqual(try existingStore.inventory().sessions.count, 2)
        let savedFile = try XCTUnwrap(existingStore.recordingURL(for: saved.session.id))
        XCTAssertEqual(try Data(contentsOf: savedFile), recordingFixtureWAV())
        XCTAssertFalse(FileManager.default.fileExists(atPath: job.directory.path))
    }
    func testIncompleteOrMismatchedWavIsRetainedAndNeverSaved() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeRoot = root.appendingPathComponent("sessions")
        let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: storeRoot)
        let job = try await storage.prepare(operationID: UUID())
        var truncated = recordingFixtureWAV(); truncated.removeLast(8); try truncated.write(to: job.wav)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: job.wav.path)
        do { _ = try await storage.saveCompleted(job, path: job.wav.path, frames: 480, sampleRate: 48000, channels: 2); XCTFail("Incomplete RIFF was saved") }
        catch { }
        try recordingFixtureWAV().write(to: job.wav)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: job.wav.path)
        do { _ = try await storage.saveCompleted(job, path: job.wav.path, frames: 479, sampleRate: 48000, channels: 2); XCTFail("Mismatched frames were saved") }
        catch { }
        try await storage.retainFailure(job, message: "Fixture failure")
        XCTAssertTrue(FileManager.default.fileExists(atPath: job.wav.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: job.directory.path).contains { $0.hasPrefix("failure-") })
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeRoot.path))
    }
    func testValidFloatWavCannotMasqueradeAsPcm16Completion() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: root.appendingPathComponent("sessions"))
        let job = try await storage.prepare(operationID: UUID())
        do {
            let output = try AVAudioFile(forWriting: job.wav, settings: [AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true])
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: output.processingFormat, frameCapacity: 480))
            buffer.frameLength = 480
            for channel in 0..<2 { buffer.floatChannelData![channel].initialize(repeating: 0.001, count: 480) }
            try output.write(from: buffer)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: job.wav.path)
        XCTAssertEqual(try AVAudioFile(forReading: job.wav).fileFormat.commonFormat, .pcmFormatFloat32)
        do { _ = try await storage.saveCompleted(job, path: job.wav.path, frames: 480, sampleRate: 48000, channels: 2); XCTFail("Wrong encoding was saved") }
        catch { }
        XCTAssertTrue(FileManager.default.fileExists(atPath: job.wav.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("sessions").path))
    }

    func testExistingApplicationSupportDirectoryCanBeReused() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let existing = root.appendingPathComponent("Lab Voice", isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        let storage = RecordingStorage(applicationSupportRoot: root)
        let before = try await storage.retainedDirectories()
        XCTAssertTrue(before.isEmpty)
        let first = try await storage.prepare(operationID: UUID())
        let second = try await storage.prepare(operationID: UUID())
        XCTAssertNotEqual(first.directory, second.directory)
        XCTAssertEqual(first.directory.deletingLastPathComponent().path, existing.appendingPathComponent("recording-staging").path)
        let retained = try await storage.retainedDirectories()
        XCTAssertEqual(retained.count, 2)
    }

}
