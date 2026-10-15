import Foundation
import AVFoundation
import Darwin
import LocalStore

struct RecordingJob: Codable, Equatable, Sendable {
    let id: UUID
    let operationID: UUID
    let directory: URL
    let startedAt: Date
    let libraryLocation: LibraryLocationSnapshot?
    var wav: URL { directory.appendingPathComponent("recording.wav") }
    var title: String { "Route recording " + startedAt.formatted(date: .abbreviated, time: .shortened) }
}

struct RecordingSave: Sendable {
    let session: Session
    let cleanupWarning: String?
}

enum RecordingStorageError: Error { case invalidDirectory, invalidCompletion }

protocol RecordingStoring: Sendable {
    func prepare(operationID: UUID, location: LibraryLocationSnapshot) async throws -> RecordingJob
    func releaseDestination(_ job: RecordingJob) async
    func retainedDirectories() async throws -> [String]
    func retainFailure(_ job: RecordingJob, message: String) async throws
    func saveCompleted(_ job: RecordingJob, path: String, frames: UInt64, sampleRate: Double, channels: UInt32) async throws -> RecordingSave
}

extension RecordingStoring { func releaseDestination(_ job: RecordingJob) async {} }

/// All filesystem and AVAudioFile work stays on this actor, away from the main thread.
actor RecordingStorage: RecordingStoring {
    private var destinations: [UUID: LocalStore] = [:]
    private let applicationSupportOverride: URL?
    private let stagingOverride: URL?
    private let storeOverride: URL?
    init(stagingRoot: URL? = nil, storeRoot: URL? = nil, applicationSupportRoot: URL? = nil) {
        applicationSupportOverride = applicationSupportRoot
        stagingOverride = stagingRoot; storeOverride = storeRoot
    }
    private func base() throws -> URL {
        let support = try applicationSupportOverride ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let root = support.appendingPathComponent("Lab Voice", isDirectory: true)
        if !FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false,
                                                   attributes: [.posixPermissions: 0o700])
        }
        try plainDirectory(root)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        return root
    }
    func prepare(operationID: UUID) throws -> RecordingJob { try prepareJob(operationID: operationID, location: nil) }
    func prepare(operationID: UUID, location: LibraryLocationSnapshot) throws -> RecordingJob {
        try prepareJob(operationID: operationID, location: location)
    }
    private func prepareJob(operationID: UUID, location: LibraryLocationSnapshot?) throws -> RecordingJob {
        let admitted = try storeOverride == nil ? location?.open() : nil
        let root = try stagingOverride ?? base().appendingPathComponent("recording-staging", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        try plainDirectory(root)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        let job = RecordingJob(id: UUID(), operationID: operationID, directory: directory, startedAt: Date(), libraryLocation: location)
        try privateWrite(JSONEncoder().encode(job), to: directory.appendingPathComponent("job.json"))
        if let admitted { destinations[job.id] = admitted }
        return job
    }
    func releaseDestination(_ job: RecordingJob) { destinations.removeValue(forKey: job.id) }
    func retainedDirectories() throws -> [String] {
        let root = try stagingOverride ?? base().appendingPathComponent("recording-staging", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        try plainDirectory(root)
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            .filter { url in
                guard UUID(uuidString: url.lastPathComponent) != nil,
                      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
                return values.isDirectory == true && values.isSymbolicLink != true
            }.map(\.path).sorted()
    }
    func retainFailure(_ job: RecordingJob, message: String) throws {
        try plainDirectory(job.directory)
        try privateWrite(Data(message.utf8), to: job.directory.appendingPathComponent("failure-" + UUID().uuidString + ".txt"))
    }
    func saveCompleted(_ job: RecordingJob, path: String, frames: UInt64, sampleRate: Double, channels: UInt32) throws -> RecordingSave {
        defer { destinations.removeValue(forKey: job.id) }
        guard path == job.wav.path, frames > 0, frames <= UInt64(Int64.max), sampleRate == 48000, channels == 2 else {
            throw RecordingStorageError.invalidCompletion
        }
        try plainDirectory(job.directory)
        let attributes = try FileManager.default.attributesOfItem(atPath: job.wav.path)
        guard (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 else { throw RecordingStorageError.invalidCompletion }
        let values = try job.wav.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size >= 44 else { throw RecordingStorageError.invalidCompletion }
        let input = try FileHandle(forReadingFrom: job.wav)
        defer { try? input.close() }
        let header = try input.read(upToCount: 12) ?? Data()
        guard header.count == 12, header.prefix(4) == Data("RIFF".utf8), header.suffix(4) == Data("WAVE".utf8) else {
            throw RecordingStorageError.invalidCompletion
        }
        let declaredSize = header[4..<8].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
        guard UInt64(declaredSize) + 8 == UInt64(size) else { throw RecordingStorageError.invalidCompletion }
        let audio = try AVAudioFile(forReading: job.wav)
        guard audio.length == Int64(frames), audio.fileFormat.sampleRate == sampleRate,
              audio.fileFormat.channelCount == channels, audio.fileFormat.commonFormat == .pcmFormatInt16 else { throw RecordingStorageError.invalidCompletion }
        let store: LocalStore
        if let storeOverride { store = try LocalStore(root: storeOverride) }
        else if let admitted = destinations[job.id] { store = admitted }
        else { throw RecordingStorageError.invalidCompletion }
        let session = try store.save(title: job.title, startedAt: job.startedAt,
            durationSeconds: Double(frames) / sampleRate, transcript: [], recording: job.wav)
        var warning: String?
        do { try FileManager.default.removeItem(at: job.directory) }
        catch { warning = "Session saved. Staging cleanup failed; a duplicate remains at \(job.directory.path)." }
        return RecordingSave(session: session, cleanupWarning: warning)
    }
    private func plainDirectory(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw RecordingStorageError.invalidDirectory }
    }
    private func privateWrite(_ bytes: Data, to url: URL) throws {
        let descriptor = url.path.withCString { Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600) }
        guard descriptor >= 0 else { throw StoreError.io(operation: "recording metadata", code: errno) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: bytes); try handle.synchronize()
    }
}

extension Notification.Name { static let localRecordingSaved = Notification.Name("LabVoice.localRecordingSaved") }
