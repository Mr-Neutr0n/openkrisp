import XCTest
import Foundation
@testable import LabVoice

final class MicrophoneTestFilesTests: XCTestCase {
    func testStrictPairValidationAndOwnerOnlyCleanupLeavesOtherCrashStageVisible() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = MicrophoneTestFiles(root: root)
        let job = try await files.prepare(id: UUID(), inputUID: "synthetic")
        let otherOwner = MicrophoneTestFiles(root: root)
        let other = try await otherOwner.prepare(id: UUID(), inputUID: "other synthetic")
        for url in [job.original, job.processed] {
            try recordingFixtureWAV(frames: 240000, channels: 1).write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        try await files.validate(job, frames: 240000, originalPath: job.original.path, processedPath: job.processed.path)
        do {
            try await files.validate(job, frames: 240001, originalPath: job.original.path, processedPath: job.processed.path)
            XCTFail("Mismatched frames accepted")
        } catch { }
        do {
            try await files.validate(job, frames: 240000, originalPath: other.original.path, processedPath: job.processed.path)
            XCTFail("Foreign path accepted")
        } catch { }
        do { try await files.remove(other); XCTFail("A different owner stage was deleted") } catch { }
        try await files.remove(job)
        XCTAssertFalse(FileManager.default.fileExists(atPath: job.directory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.directory.path))
        let restarted = MicrophoneTestFiles(root: root)
        let retained = try await restarted.retained()
        XCTAssertEqual(retained.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }, [other.directory.resolvingSymlinksInPath().path])
    }
}
