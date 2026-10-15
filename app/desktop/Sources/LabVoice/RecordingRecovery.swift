import Foundation
import Darwin
import LocalStore

enum RecordingRecoveryEligibility: Equatable, Sendable { case finalized, invalid(String) }
struct RecoverableRecording: Identifiable, Equatable, Sendable {
    let id: UUID
    let directory: URL
    let startedAt: Date
    let frames: UInt64
    let eligibility: RecordingRecoveryEligibility
    fileprivate let admission: RecoveryAdmission?
    init(id: UUID, directory: URL, startedAt: Date, frames: UInt64, eligibility: RecordingRecoveryEligibility) {
        self.id = id; self.directory = directory; self.startedAt = startedAt; self.frames = frames; self.eligibility = eligibility; admission = nil
    }
    fileprivate init(id: UUID, directory: URL, startedAt: Date, frames: UInt64, eligibility: RecordingRecoveryEligibility, admission: RecoveryAdmission?) {
        self.id = id; self.directory = directory; self.startedAt = startedAt; self.frames = frames; self.eligibility = eligibility; self.admission = admission
    }
    var title: String { admission == nil ? "Retained recording" : "Recovered recording " + startedAt.formatted(date: .abbreviated, time: .shortened) }
    var durationSeconds: Double { Double(frames) / 48000 }
}
protocol RecordingRecoveryServing: Sendable {
    func scan() async throws -> [RecoverableRecording]
    func saveCopy(_ candidate: RecoverableRecording, to location: LibraryLocationSnapshot) async throws -> RecordingSave
}
enum RecordingRecoveryError: Error, Equatable, LocalizedError {
    case invalidSource, invalidMetadata, sourceChanged
    case cleanupIncomplete(path: String)
    var errorDescription: String? {
        switch self {
        case .invalidSource: return "The retained recording is not a private, finalized 48 kHz stereo PCM16 WAV."
        case .invalidMetadata: return "The retained recording metadata is invalid or does not match its folder."
        case .sourceChanged: return "The retained recording changed. Review it again before saving a copy."
        case let .cleanupIncomplete(path): return "The copy did not complete, and temporary cleanup could not be confirmed. Inspect the temporary folder at \(path). The retained source remains unchanged."
        }
    }
}

/// Recovery preserves staging evidence. It does not repair partial WAV files or migrate libraries.
actor RecordingRecovery: RecordingRecoveryServing {
    private let root: URL
    private let snapshotReady: @Sendable (URL) throws -> Void
    // The checkpoint permits deterministic filesystem-failure tests without real recordings.
    init(stagingRoot: URL? = nil, snapshotReady: @escaping @Sendable (URL) throws -> Void = { _ in }) {
        self.snapshotReady = snapshotReady
        root = stagingRoot ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lab Voice/recording-staging", isDirectory: true)
    }
    func scan() throws -> [RecoverableRecording] {
        var info = stat()
        guard root.path.withCString({ Darwin.lstat($0, &info) }) == 0 else {
            if errno == ENOENT { return [] }
            throw RecordingRecoveryError.invalidSource
        }
        _ = try RecoveryFile(root, directory: true)
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .compactMap { directory -> RecoverableRecording? in
                guard let id = UUID(uuidString: directory.lastPathComponent) else { return nil }
                do {
                    let admitted = try admit(directory)
                    return .init(id: id, directory: directory, startedAt: admitted.startedAt, frames: admitted.frames,
                                 eligibility: .finalized, admission: admitted)
                } catch {
                    return .init(id: id, directory: directory, startedAt: Date(timeIntervalSince1970: 0), frames: 0,
                                 eligibility: .invalid("No unchanged, finalized private 48 kHz stereo PCM16 recording is available."), admission: nil)
                }
            }.sorted { $0.directory.lastPathComponent < $1.directory.lastPathComponent }
    }
    func saveCopy(_ candidate: RecoverableRecording, to location: LibraryLocationSnapshot) throws -> RecordingSave {
        guard candidate.directory.deletingLastPathComponent().standardizedFileURL.path == root.standardizedFileURL.path,
              UUID(uuidString: candidate.directory.lastPathComponent) == candidate.id,
              candidate.eligibility == .finalized, let previous = candidate.admission else { throw RecordingRecoveryError.invalidSource }
        // Retain the admitted destination instance through the whole copy/save operation.
        let store = try location.open()
        let current = try admit(candidate.directory)
        guard current == previous else { throw RecordingRecoveryError.sourceChanged }
        let input = try RecoveryFile(candidate.directory.appendingPathComponent("recording.wav"), directory: false)
        guard input.fingerprint == previous.audio else { throw RecordingRecoveryError.sourceChanged }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let ownedTemporary = try RecoveryFile(temporary, directory: true).fingerprint
        func cleanup() -> Bool {
            var current = stat()
            guard temporary.path.withCString({ Darwin.lstat($0, &current) }) == 0,
                  current.st_mode & S_IFMT == S_IFDIR,
                  current.st_dev == ownedTemporary.device, current.st_ino == ownedTemporary.inode else { return false }
            do { try FileManager.default.removeItem(at: temporary); return true } catch { return false }
        }
        do {
        let snapshot = temporary.appendingPathComponent("recording.wav")
        let descriptor = snapshot.path.withCString { Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600) }
        guard descriptor >= 0 else { throw StoreError.io(operation: "recovery snapshot", code: errno) }
        let output = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            var remaining = previous.audio.size
            while remaining > 0 {
                let bytes = try input.read(offset: UInt64(previous.audio.size - remaining), count: min(65536, Int(remaining)))
                try output.write(contentsOf: bytes); remaining -= Int64(bytes.count)
            }
            try output.synchronize(); try output.close()
        } catch { try? output.close(); throw error }
        let snapshotAdmission = try RecoveryFile(snapshot, directory: false)
        try snapshotReady(temporary)
        let currentTemporary = try RecoveryFile(temporary, directory: true).fingerprint
        guard currentTemporary.device == ownedTemporary.device, currentTemporary.inode == ownedTemporary.inode,
              try snapshotAdmission.unchanged() else { throw RecordingRecoveryError.sourceChanged }
        guard try input.unchanged(), try admit(candidate.directory) == previous else { throw RecordingRecoveryError.sourceChanged }
        let session = try store.save(title: candidate.title, startedAt: candidate.startedAt, durationSeconds: candidate.durationSeconds,
                                     transcript: [], recording: snapshot)
        let cleaned = cleanup()
        return RecordingSave(session: session, cleanupWarning: cleaned ? nil : "Copy saved. Temporary cleanup could not be confirmed. Inspect the temporary folder at \(temporary.path).")
        } catch {
            guard cleanup() else { throw RecordingRecoveryError.cleanupIncomplete(path: temporary.path) }
            throw error
        }
    }
    private func admit(_ directory: URL) throws -> RecoveryAdmission {
        let base = try RecoveryFile(root, directory: true)
        let folder = try RecoveryFile(directory, directory: true)
        let metadata = try RecoveryFile(directory.appendingPathComponent("job.json"), directory: false)
        guard metadata.fingerprint.size > 0, metadata.fingerprint.size <= 65536 else { throw RecordingRecoveryError.invalidMetadata }
        let job: RecordingJob
        do { job = try JSONDecoder().decode(RecordingJob.self, from: metadata.read(offset: 0, count: Int(metadata.fingerprint.size))) }
        catch { throw RecordingRecoveryError.invalidMetadata }
        guard job.directory.isFileURL, job.directory.standardizedFileURL.path == directory.standardizedFileURL.path,
              job.startedAt.timeIntervalSince1970.isFinite else { throw RecordingRecoveryError.invalidMetadata }
        let audio = try RecoveryFile(directory.appendingPathComponent("recording.wav"), directory: false)
        let frames = try audio.frames()
        guard try metadata.unchanged(), try audio.unchanged(), try folder.unchanged(), try base.unchanged() else { throw RecordingRecoveryError.sourceChanged }
        return .init(root: base.fingerprint, directory: folder.fingerprint, metadata: metadata.fingerprint,
                     audio: audio.fingerprint, startedAt: job.startedAt, frames: frames)
    }
}
fileprivate struct RecoveryAdmission: Equatable, Sendable {
    let root: RecoveryFingerprint
    let directory: RecoveryFingerprint
    let metadata: RecoveryFingerprint
    let audio: RecoveryFingerprint
    let startedAt: Date
    let frames: UInt64
}
fileprivate struct RecoveryFingerprint: Equatable, Sendable {
    let device: Int32
    let inode: UInt64
    let size: Int64
    let modifiedSeconds: Int64
    let modifiedNanos: Int64
    let changedSeconds: Int64
    let changedNanos: Int64
    init(_ value: stat) {
        device = value.st_dev; inode = value.st_ino; size = value.st_size
        modifiedSeconds = Int64(value.st_mtimespec.tv_sec); modifiedNanos = Int64(value.st_mtimespec.tv_nsec)
        changedSeconds = Int64(value.st_ctimespec.tv_sec); changedNanos = Int64(value.st_ctimespec.tv_nsec)
    }
}
private final class RecoveryFile {
    let fingerprint: RecoveryFingerprint
    private let descriptor: Int32
    private let url: URL
    init(_ url: URL, directory: Bool) throws {
        self.url = url
        descriptor = url.path.withCString { Darwin.open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | (directory ? O_DIRECTORY : 0)) }
        guard descriptor >= 0 else { throw RecordingRecoveryError.invalidSource }
        var info = stat()
        guard Darwin.fstat(descriptor, &info) == 0, info.st_uid == Darwin.geteuid(),
              info.st_mode & S_IFMT == (directory ? S_IFDIR : S_IFREG),
              info.st_mode & 0o7777 == (directory ? 0o700 : 0o600) else {
            Darwin.close(descriptor); throw RecordingRecoveryError.invalidSource
        }
        fingerprint = RecoveryFingerprint(info)
    }
    deinit { Darwin.close(descriptor) }
    func unchanged() throws -> Bool {
        var descriptorInfo = stat(), pathInfo = stat()
        return Darwin.fstat(descriptor, &descriptorInfo) == 0 && url.path.withCString({ Darwin.lstat($0, &pathInfo) }) == 0 &&
            RecoveryFingerprint(descriptorInfo) == fingerprint && RecoveryFingerprint(pathInfo) == fingerprint
    }
    func read(offset: UInt64, count: Int) throws -> Data {
        var result = Data(count: count), done = 0
        while done < count {
            let received = result.withUnsafeMutableBytes { Darwin.pread(descriptor, $0.baseAddress!.advanced(by: done), count - done, off_t(offset) + off_t(done)) }
            if received < 0 && errno == EINTR { continue }
            guard received > 0 else { throw RecordingRecoveryError.sourceChanged }
            done += received
        }
        return result
    }
    func frames() throws -> UInt64 {
        guard fingerprint.size >= 44, UInt64(fingerprint.size) <= UInt64(UInt32.max) + 8 else { throw RecordingRecoveryError.invalidSource }
        func word(_ data: Data, _ offset: Int, _ count: Int) -> UInt32 {
            (0..<count).reduce(0) { $0 | UInt32(data[offset + $1]) << (8 * $1) }
        }
        let header = try read(offset: 0, count: 12)
        guard header.prefix(4) == Data("RIFF".utf8), header.suffix(4) == Data("WAVE".utf8),
              UInt64(word(header, 4, 4)) + 8 == UInt64(fingerprint.size) else { throw RecordingRecoveryError.invalidSource }
        var offset: UInt64 = 12, foundFormat = false, audioBytes: UInt32?
        while offset < UInt64(fingerprint.size) {
            guard UInt64(fingerprint.size) - offset >= 8 else { throw RecordingRecoveryError.invalidSource }
            let chunk = try read(offset: offset, count: 8), length = word(chunk, 4, 4)
            let end = offset + 8 + UInt64(length) + UInt64(length % 2)
            guard end <= UInt64(fingerprint.size) else { throw RecordingRecoveryError.invalidSource }
            if chunk.prefix(4) == Data("fmt ".utf8) {
                guard !foundFormat, length == 16 || length == 18 else { throw RecordingRecoveryError.invalidSource }
                let format = try read(offset: offset + 8, count: Int(length))
                guard word(format, 0, 2) == 1, word(format, 2, 2) == 2, word(format, 4, 4) == 48000,
                      word(format, 8, 4) == 192000, word(format, 12, 2) == 4, word(format, 14, 2) == 16,
                      length == 16 || word(format, 16, 2) == 0 else { throw RecordingRecoveryError.invalidSource }
                foundFormat = true
            } else if chunk.prefix(4) == Data("data".utf8) {
                guard audioBytes == nil, length > 0, length % 4 == 0 else { throw RecordingRecoveryError.invalidSource }
                audioBytes = length
            }
            offset = end
        }
        guard foundFormat, let audioBytes else { throw RecordingRecoveryError.invalidSource }
        return UInt64(audioBytes) / 4
    }
}
