import XCTest
import Darwin
import LocalStore
@testable import LabVoice

private final class RecoveryPathCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var url: URL?
    func set(_ value: URL) { lock.lock(); defer { lock.unlock() }; url = value }
    func get() -> URL? { lock.lock(); defer { lock.unlock() }; return url }
}
@MainActor final class RecordingRecoveryTests: XCTestCase {
    private func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    private func wav(frames: UInt32 = 100) -> Data {
        var bytes = Data()
        func text(_ value: String) { bytes.append(contentsOf: value.utf8) }
        func word(_ value: UInt32, _ count: Int) { for n in 0..<count { bytes.append(UInt8(truncatingIfNeeded: value >> (8 * n))) } }
        text("RIFF"); word(36 + frames * 4, 4); text("WAVEfmt "); word(16, 4); word(1, 2); word(2, 2)
        word(48000, 4); word(192000, 4); word(4, 2); word(16, 2); text("data"); word(frames * 4, 4)
        for n in 0..<Int(frames * 4) { bytes.append(UInt8(truncatingIfNeeded: n)) }; return bytes
    }
    private func job(_ root: URL, bytes: Data? = nil, manifestDirectory: URL? = nil) throws -> RecordingJob {
        let directory = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let job = RecordingJob(id: UUID(), operationID: UUID(), directory: manifestDirectory ?? directory, startedAt: Date(timeIntervalSince1970: 100), libraryLocation: nil)
        try JSONEncoder().encode(job).write(to: directory.appendingPathComponent("job.json"))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: directory.appendingPathComponent("job.json").path)
        try (bytes ?? wav()).write(to: directory.appendingPathComponent("recording.wav"))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: directory.appendingPathComponent("recording.wav").path)
        return RecordingJob(id: job.id, operationID: job.operationID, directory: directory, startedAt: job.startedAt, libraryLocation: nil)
    }
    private func location(_ root: URL) throws -> LibraryLocationSnapshot {
        _ = try LocalStore(root: root)
        return .init(root: root, createIfMissing: false, revision: UUID())
    }
    func testFinalizedCopyPreservesSourceAndRepeatedCopiesAreExplicit() async throws {
        let root = try temporary(), library = try temporary(), original = try job(root)
        let metadata = try Data(contentsOf: original.directory.appendingPathComponent("job.json")), audio = try Data(contentsOf: original.wav)
        let backend = RecordingRecovery(stagingRoot: root), target = try location(library)
        let items = try await backend.scan(), item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.eligibility, .finalized); XCTAssertEqual(item.frames, 100)
        XCTAssertNotEqual(item.id, original.id) // Existing manifests have a distinct job and directory ID.
        let first = try await backend.saveCopy(item, to: target), second = try await backend.saveCopy(item, to: target)
        XCTAssertNotEqual(first.session.id, second.session.id); XCTAssertTrue(first.session.transcript.isEmpty)
        XCTAssertEqual(first.session.durationSeconds, 100.0 / 48000)
        let store = try target.open(), copy = try XCTUnwrap(store.recordingURL(for: first.session.id))
        XCTAssertEqual(try Data(contentsOf: copy), audio)
        XCTAssertEqual(try Data(contentsOf: original.wav), audio)
        XCTAssertEqual(try Data(contentsOf: original.directory.appendingPathComponent("job.json")), metadata)
    }
    func testIncompleteCorruptAndForeignManifestAreListedButNeverAdmitted() async throws {
        let root = try temporary()
        _ = try job(root, bytes: Data("unfinished".utf8))
        _ = try job(root, manifestDirectory: URL(fileURLWithPath: "/arbitrary/not-used"))
        var invalid = wav(); invalid[24] = 1; _ = try job(root, bytes: invalid)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("not-a-job"), withIntermediateDirectories: false)
        let backend = RecordingRecovery(stagingRoot: root), items = try await backend.scan()
        XCTAssertEqual(items.count, 3)
        for item in items { if case .invalid = item.eligibility {} else { XCTFail("Invalid stage was admitted") } }
        let target = try location(temporary())
        do { _ = try await backend.saveCopy(items[0], to: target); XCTFail("Saved invalid stage") } catch {}
        XCTAssertTrue(try target.open().inventory().sessions.isEmpty)
    }
    func testChangedSourceAndReplacedDirectoryRejectOldAdmission() async throws {
        let root = try temporary(), original = try job(root), backend = RecordingRecovery(stagingRoot: root)
        let scanned = try await backend.scan()
        let item = try XCTUnwrap(scanned.first), target = try location(temporary())
        try wav(frames: 101).write(to: original.wav)
        do { _ = try await backend.saveCopy(item, to: target); XCTFail("Saved changed source") } catch {}
        XCTAssertTrue(try target.open().inventory().sessions.isEmpty)
        let rescanned = try await backend.scan()
        let fresh = try XCTUnwrap(rescanned.first)
        let moved = root.appendingPathComponent("preserved")
        try FileManager.default.moveItem(at: original.directory, to: moved)
        try FileManager.default.createDirectory(at: original.directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        do { _ = try await backend.saveCopy(fresh, to: target); XCTFail("Saved replacement directory") } catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.appendingPathComponent("recording.wav").path))
    }
    func testPrivatePermissionsSymlinksAndOversizedMetadataAreRejected() async throws {
        let root = try temporary(), first = try job(root), second = try job(root), third = try job(root)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: first.wav.path)
        try FileManager.default.removeItem(at: second.wav)
        try FileManager.default.createSymbolicLink(at: second.wav, withDestinationURL: first.wav)
        try Data(repeating: 32, count: 65537).write(to: third.directory.appendingPathComponent("job.json"))
        let items = try await RecordingRecovery(stagingRoot: root).scan()
        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.allSatisfy { if case .invalid = $0.eligibility { return true }; return false })
    }
    func testMissingSelectedLibraryHasNoFallbackAndStageRemains() async throws {
        let root = try temporary(), original = try job(root), backend = RecordingRecovery(stagingRoot: root)
        let scanned = try await backend.scan()
        let item = try XCTUnwrap(scanned.first), parent = try temporary(), missing = parent.appendingPathComponent("absent")
        let destination = LibraryLocationSnapshot(root: missing, createIfMissing: false, revision: UUID())
        do { _ = try await backend.saveCopy(item, to: destination); XCTFail("Created missing selected library") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        XCTAssertEqual(try Data(contentsOf: original.wav), wav())
    }
    func testMissingRootIsEmptyAndSymlinkRootIsRejected() async throws {
        let parent = try temporary(), missing = parent.appendingPathComponent("missing")
        let empty = try await RecordingRecovery(stagingRoot: missing).scan(); XCTAssertTrue(empty.isEmpty)
        let actual = try temporary(), link = parent.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: actual)
        do { _ = try await RecordingRecovery(stagingRoot: link).scan(); XCTFail("Followed symlink root") } catch {}
    }
    func testReplacementAfterDestinationAdmissionDoesNotPublishIntoReplacement() async throws {
        let root = try temporary(), library = try temporary(), moved = library.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: moved) }
        _ = try job(root)
        let destination = try location(library)
        let backend = RecordingRecovery(stagingRoot: root, snapshotReady: { _ in
            try FileManager.default.moveItem(at: library, to: moved)
            try FileManager.default.createDirectory(at: library, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        })
        let scanned = try await backend.scan(), item = try XCTUnwrap(scanned.first)
        do { _ = try await backend.saveCopy(item, to: destination); XCTFail("Published into replacement library") } catch {}
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: library.path).isEmpty)
        XCTAssertTrue(try LocalStore(root: moved, createIfMissing: false).inventory().sessions.isEmpty)
    }
    func testMutationDuringSnapshotRejectsAndLeavesSource() async throws {
        let root = try temporary(), original = try job(root), target = try location(temporary()), changed = wav(frames: 101)
        let backend = RecordingRecovery(stagingRoot: root, snapshotReady: { _ in try changed.write(to: original.wav) })
        let scanned = try await backend.scan(), item = try XCTUnwrap(scanned.first)
        do { _ = try await backend.saveCopy(item, to: target); XCTFail("Published changed source") } catch {}
        XCTAssertEqual(try Data(contentsOf: original.wav), changed)
        XCTAssertTrue(try target.open().inventory().sessions.isEmpty)
    }
    func testReplacedTemporaryFolderIsPreservedAndFailureIsExplicit() async throws {
        let root = try temporary(), original = try job(root), target = try location(temporary()), moved = try temporary()
        let captured = RecoveryPathCapture()
        addTeardownBlock { if let url = captured.get() { try? FileManager.default.removeItem(at: url) } }
        let backend = RecordingRecovery(stagingRoot: root, snapshotReady: { snapshot in
            captured.set(snapshot)
            let bytes = try Data(contentsOf: snapshot.appendingPathComponent("recording.wav"))
            try FileManager.default.moveItem(at: snapshot, to: moved.appendingPathComponent("owned"))
            try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            try bytes.write(to: snapshot.appendingPathComponent("recording.wav"))
        })
        let scanned = try await backend.scan(), item = try XCTUnwrap(scanned.first)
        do { _ = try await backend.saveCopy(item, to: target); XCTFail("Accepted replaced temporary snapshot") }
        catch {
            let foreign = try XCTUnwrap(captured.get())
            XCTAssertEqual(error as? RecordingRecoveryError, .cleanupIncomplete(path: foreign.path))
            XCTAssertTrue(error.localizedDescription.contains(foreign.path))
        }
        XCTAssertTrue(try target.open().inventory().sessions.isEmpty)
        let foreign = try XCTUnwrap(captured.get())
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.appendingPathComponent("recording.wav").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.wav.path))
    }

}
