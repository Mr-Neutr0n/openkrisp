import Foundation
import Darwin

/// A review snapshot. File identities detect ordinary replacement and mutation;
/// this is not a cryptographic snapshot of recording bytes.
public struct TranscriptionSessionSnapshot: Sendable {
    public let session: Session
    public let recordingURL: URL
    fileprivate let root: URL
    fileprivate let identities: [TranscriptFileIdentity]
}

let transcriptReplacementLock = NSLock()

extension LocalStore {
    /// Requires an existing recording. The caller must retain its library lease
    /// through recognition/review. In-process deletion shares the commit lock.
    public func transcriptionSnapshot(for id: UUID) throws -> TranscriptionSessionSnapshot {
        transcriptReplacementLock.lock()
        defer { transcriptReplacementLock.unlock() }
        return try readTranscriptionSnapshot(id)
    }

    /// Atomically replaces only the manifest. All instances in this process
    /// serialize expected-check and publication. Arbitrary external writers are
    /// not a compare-and-swap participant. Power-loss directory durability is not
    /// promised beyond the filesystem's rename semantics.
    public func replaceTranscript(_ transcript: [TranscriptSegment], expected: TranscriptionSessionSnapshot) throws -> Session {
        transcriptReplacementLock.lock()
        defer { transcriptReplacementLock.unlock() }
        guard transcript.allSatisfy({ $0.startSeconds.isFinite && $0.endSeconds.isFinite &&
            $0.startSeconds >= 0 && $0.endSeconds >= $0.startSeconds &&
            $0.endSeconds <= expected.session.durationSeconds }) else { throw StoreError.invalidSession }
        try checkTranscriptionSnapshot(expected)
        let old = expected.session
        let updated = Session(schemaVersion: old.schemaVersion, id: old.id, title: old.title,
                              startedAt: old.startedAt, durationSeconds: old.durationSeconds,
                              transcript: transcript, recordingFilename: old.recordingFilename, recordingSource: old.recordingSource)
        let directory = root.appendingPathComponent(old.id.uuidString)
        let temporary = directory.appendingPathComponent(".transcript-" + UUID().uuidString)
        let descriptor = Darwin.open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw StoreError.io(operation: "create transcript", code: errno) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: temporary) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try handle.write(contentsOf: encoder.encode(updated))
        try handle.synchronize()
        try checkTranscriptionSnapshot(expected)
        let destination = directory.appendingPathComponent("session.json")
        guard Darwin.rename(temporary.path, destination.path) == 0 else {
            throw StoreError.io(operation: "publish transcript", code: errno)
        }
        return updated
    }

    private func checkTranscriptionSnapshot(_ expected: TranscriptionSessionSnapshot) throws {
        guard root == expected.root else { throw StoreError.io(operation: "transcription library changed", code: ESTALE) }
        let current = try readTranscriptionSnapshot(expected.session.id)
        guard current.session == expected.session, current.identities == expected.identities else {
            throw StoreError.io(operation: "transcription source changed", code: ESTALE)
        }
    }

    private func readTranscriptionSnapshot(_ id: UUID) throws -> TranscriptionSessionSnapshot {
        let session = try load(id)
        guard let filename = session.recordingFilename else { throw StoreError.invalidRecording }
        let directory = root.appendingPathComponent(id.uuidString)
        let recording = directory.appendingPathComponent(filename)
        func identities() throws -> [TranscriptFileIdentity] {
            try [TranscriptFileIdentity(root, directory: true), TranscriptFileIdentity(directory, directory: true),
                 TranscriptFileIdentity(directory.appendingPathComponent("session.json"), directory: false),
                 TranscriptFileIdentity(recording, directory: false)]
        }
        let before = try identities()
        guard try load(id) == session, try identities() == before else {
            throw StoreError.io(operation: "transcription source changed", code: ESTALE)
        }
        return .init(session: session, recordingURL: recording, root: root, identities: before)
    }
}

fileprivate struct TranscriptFileIdentity: Equatable, Sendable {
    let device: dev_t
    let inode: ino_t
    let size: off_t
    let modifiedSeconds: Int
    let modifiedNanoseconds: Int
    let changedSeconds: Int
    let changedNanoseconds: Int
    init(_ url: URL, directory: Bool) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw StoreError.io(operation: "inspect transcription source", code: errno) }
        guard info.st_mode & S_IFMT == (directory ? S_IFDIR : S_IFREG) else { throw StoreError.invalidEntry }
        device = info.st_dev; inode = info.st_ino
        // Our own temporary manifest changes directory timestamps. Directory
        // identity is inode-based; files also bind size and nanosecond times.
        size = directory ? 0 : info.st_size
        modifiedSeconds = directory ? 0 : info.st_mtimespec.tv_sec
        modifiedNanoseconds = directory ? 0 : info.st_mtimespec.tv_nsec
        changedSeconds = directory ? 0 : info.st_ctimespec.tv_sec
        changedNanoseconds = directory ? 0 : info.st_ctimespec.tv_nsec
    }
}
