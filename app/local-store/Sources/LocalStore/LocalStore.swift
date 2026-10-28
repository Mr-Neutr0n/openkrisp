import Foundation
import Darwin

public struct TranscriptSegment: Codable, Equatable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let speaker: String?
    public let text: String

    public init(startSeconds: Double, endSeconds: Double, speaker: String? = nil, text: String) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.speaker = speaker
        self.text = text
    }
}

public struct Session: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: UUID
    public let title: String
    public let startedAt: Date
    public let durationSeconds: Double
    public let transcript: [TranscriptSegment]
    public let recordingFilename: String?
}

public struct StoreInventory: Sendable {
    public let sessions: [Session]
    /// A bad entry does not make other saved sessions disappear.
    public let unreadableEntries: [String]
    /// Incomplete imports are retained for explicit recovery or removal.
    public let pendingEntries: [String]
}

public enum StoreError: Error, Equatable {
    case invalidSession
    case invalidRecording
    case malformedManifest
    case missingSession
    case invalidEntry
    case io(operation: String, code: Int32)
}

/// Disk operations belong off audio callbacks. Each save publishes a complete directory by rename.
/// Unique session IDs permit concurrent saves. Callers serialize removal against reads of that ID.
public struct LocalStore: Sendable {
    public let root: URL

    private let identity: LibraryIdentity

    /// Selected or persisted locations must use false. Only the default location
    /// may be created implicitly. Existing permissions and contents stay unchanged.
    public init(root: URL, createIfMissing: Bool = true) throws {
        guard root.isFileURL, !root.path.utf8.contains(0) else { throw StoreError.invalidEntry }
        self.root = root.standardizedFileURL
        if createIfMissing {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true,
                                                   attributes: [.posixPermissions: 0o700])
        }
        identity = try inspectLibraryRoot(self.root)
    }

    private func validateRoot() throws {
        guard try inspectLibraryRoot(root) == identity else {
            throw StoreError.io(operation: "library location changed", code: ESTALE)
        }
    }

    /// Imports an already finalized WAV file. Does not capture, resample, or transcribe audio.
    /// Source bytes remain unchanged. A recording is optional for transcript-only sessions.
    public func save(title: String, startedAt: Date, durationSeconds: Double,
                     transcript: [TranscriptSegment], recording: URL? = nil) throws -> Session {
        guard durationSeconds.isFinite, durationSeconds >= 0,
              startedAt.timeIntervalSince1970.isFinite,
              transcript.allSatisfy({ segment in
                  segment.startSeconds.isFinite && segment.endSeconds.isFinite &&
                  segment.startSeconds >= 0 && segment.endSeconds >= segment.startSeconds &&
                  segment.endSeconds <= durationSeconds
              }) else { throw StoreError.invalidSession }
        try validateRoot()
        let id = UUID()
        let stage = root.appendingPathComponent(".pending-" + id.uuidString, isDirectory: true)
        let final = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        // Failed saves intentionally retain their staging files, including partial audio imports.
        // They never appear in normal history, and can be inspected through inventory().
        if let recording {
            guard recording.isFileURL else { throw StoreError.invalidRecording }
            let values = try recording.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw StoreError.invalidRecording
            }
            let input = try FileHandle(forReadingFrom: recording)
            defer { try? input.close() }
            let prefix = try input.read(upToCount: 12) ?? Data()
            guard prefix.count == 12, prefix.prefix(4) == Data("RIFF".utf8),
                  prefix.suffix(4) == Data("WAVE".utf8) else { throw StoreError.invalidRecording }
            let destination = stage.appendingPathComponent("recording.wav")
            // Create with private permissions before copying any recording bytes.
            let output = try createPrivateFile(destination)
            defer { try? output.close() }
            try output.write(contentsOf: prefix)
            while let block = try input.read(upToCount: 1024 * 1024), !block.isEmpty {
                try output.write(contentsOf: block)
            }
            try output.synchronize()
        }
        let session = Session(schemaVersion: 1, id: id, title: title, startedAt: startedAt,
                              durationSeconds: durationSeconds, transcript: transcript,
                              recordingFilename: recording == nil ? nil : "recording.wav")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        try writePrivateFile(encoder.encode(session), to: stage.appendingPathComponent("session.json"))
        try validateRoot()
        try FileManager.default.moveItem(at: stage, to: final)
        return session
    }

    public func load(_ id: UUID) throws -> Session {
        try validateRoot()
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else { throw StoreError.missingSession }
        try requirePlainDirectory(folder)
        let manifest = folder.appendingPathComponent("session.json")
        try requirePlainFile(manifest)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let session = try decoder.decode(Session.self, from: Data(contentsOf: manifest))
        guard session.schemaVersion == 1, session.id == id,
              session.durationSeconds.isFinite, session.durationSeconds >= 0,
              session.recordingFilename == nil || session.recordingFilename == "recording.wav",
              session.transcript.allSatisfy({ $0.startSeconds.isFinite && $0.endSeconds.isFinite &&
                  $0.startSeconds >= 0 && $0.endSeconds >= $0.startSeconds &&
                  $0.endSeconds <= session.durationSeconds }) else { throw StoreError.malformedManifest }
        if let filename = session.recordingFilename { try requirePlainFile(folder.appendingPathComponent(filename)) }
        try validateRoot()
        return session
    }

    public func recordingURL(for id: UUID) throws -> URL? {
        let session = try load(id)
        return session.recordingFilename.map { root.appendingPathComponent(id.uuidString).appendingPathComponent($0) }
    }

    public func inventory() throws -> StoreInventory {
        try validateRoot()
        let entries = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        var sessions: [Session] = []
        var unreadable: [String] = []
        var pending: [String] = []
        for entry in entries {
            let name = entry.lastPathComponent
            if name.hasPrefix(".pending-"), UUID(uuidString: String(name.dropFirst(9))) != nil {
                pending.append(name)
            } else if let id = UUID(uuidString: name), id.uuidString == name {
                do { sessions.append(try load(id)) } catch { unreadable.append(name) }
            }
        }
        try validateRoot()
        sessions.sort { $0.startedAt == $1.startedAt ? $0.id.uuidString < $1.id.uuidString : $0.startedAt > $1.startedAt }
        return StoreInventory(sessions: sessions, unreadableEntries: unreadable.sorted(), pendingEntries: pending.sorted())
    }

    public func search(_ query: String) throws -> [Session] {
        let sessions = try inventory().sessions
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(query) ||
            $0.transcript.contains { $0.text.localizedCaseInsensitiveContains(query) ||
                ($0.speaker?.localizedCaseInsensitiveContains(query) ?? false) } }
    }

    /// Explicit user action only. Never call automatic retention or cleanup against this store.
    public func remove(_ id: UUID) throws {
        transcriptReplacementLock.lock()
        defer { transcriptReplacementLock.unlock() }
        try validateRoot()
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try requirePlainDirectory(folder)
        try FileManager.default.removeItem(at: folder)
    }

    /// Exports readable text without replacing an existing file.
    public func exportTranscript(_ id: UUID, to destination: URL) throws {
        guard destination.isFileURL else { throw StoreError.invalidEntry }
        let session = try load(id)
        var lines = [session.title, ""]
        for segment in session.transcript {
            let time = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), segment.startSeconds)
            lines.append("[\(time)s] " + (segment.speaker.map { $0 + ": " } ?? "") + segment.text)
        }
        try writePrivateFile(Data((lines.joined(separator: "\n") + "\n").utf8), to: destination)
    }
}

private struct LibraryIdentity: Equatable, Sendable {
    let device: dev_t
    let inode: ino_t
}

private func inspectLibraryRoot(_ url: URL) throws -> LibraryIdentity {
    // Strip a trailing slash so O_NOFOLLOW applies to the selected final component.
    var path = url.path
    while path.count > 1, path.hasSuffix("/") { path.removeLast() }
    let descriptor = path.withCString { Darwin.open($0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC) }
    guard descriptor >= 0 else { throw StoreError.io(operation: "open library location", code: errno) }
    defer { Darwin.close(descriptor) }
    var info = stat()
    guard Darwin.fstat(descriptor, &info) == 0 else {
        throw StoreError.io(operation: "inspect library location", code: errno)
    }
    // Check real permissions, including ACLs, without writing a probe file or chmod.
    guard Darwin.faccessat(descriptor, ".", R_OK | W_OK | X_OK, 0) == 0 else {
        throw StoreError.io(operation: "access library location", code: errno)
    }
    return LibraryIdentity(device: info.st_dev, inode: info.st_ino)
}

private func requirePlainDirectory(_ url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else { throw StoreError.invalidEntry }
}

private func requirePlainFile(_ url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else { throw StoreError.invalidEntry }
}

private func createPrivateFile(_ url: URL) throws -> FileHandle {
    let descriptor = url.path.withCString { Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600) }
    guard descriptor >= 0 else { throw StoreError.io(operation: "create", code: errno) }
    return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
}

private func writePrivateFile(_ data: Data, to url: URL) throws {
    let handle = try createPrivateFile(url)
    defer { try? handle.close() }
    try handle.write(contentsOf: data)
    try handle.synchronize()
}
