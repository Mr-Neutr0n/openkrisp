import Foundation
import Darwin

enum DiagnosticComponent: String, Codable, Sendable { case app, audio, recording, library, microphoneTest, transcription }
enum DiagnosticCode: String, Codable, Sendable {
    case started, stopped, stateChanged, operationFailed, permissionDenied
    case exportStarted, exportCompleted, exportFailed, locationChanged
}
enum DiagnosticSeverity: String, Codable, Sendable { case info, warning, error }
enum DiagnosticState: String, Codable, Sendable {
    case idle, starting, running, stopping, failed, unavailable, busy, ready, paused, pending, unknown
}
enum DiagnosticCategory: String, Codable, Sendable { case audio, recording, library, transcription, other }
enum DiagnosticArchitecture: String, Codable, Sendable { case arm64, x86_64, unknown }

struct DiagnosticEvent: Codable, Equatable, Sendable {
    let sequence: UInt64
    let at: Date
    let component: DiagnosticComponent
    let code: DiagnosticCode
    let severity: DiagnosticSeverity
}
struct DiagnosticEventSnapshot: Codable, Equatable, Sendable {
    let events: [DiagnosticEvent]
    let droppedCount: UInt64
}

/// Fixed codes only. Never append helper output, error text, paths, UIDs, or user content.
@MainActor final class DiagnosticEventLog {
    static let shared = DiagnosticEventLog()
    static let hardLimit = 128
    private let capacity: Int
    private var events: [DiagnosticEvent] = []
    private var dropped: UInt64 = 0
    private var sequence: UInt64 = 0
    init(maximumEvents: Int = 128) { capacity = min(Self.hardLimit, max(1, maximumEvents)) }
    @discardableResult func append(component: DiagnosticComponent, code: DiagnosticCode,
                                   severity: DiagnosticSeverity, at: Date = Date()) -> Bool {
        guard at.timeIntervalSince1970.isFinite else { incrementDropped(); return false }
        if events.count == capacity { events.removeFirst(); incrementDropped() }
        if sequence < 9_007_199_254_740_991 { sequence += 1 }
        events.append(DiagnosticEvent(sequence: sequence, at: at, component: component, code: code, severity: severity))
        return true
    }
    func snapshot() -> DiagnosticEventSnapshot { .init(events: events, droppedCount: dropped) }
    private func incrementDropped() { if dropped < 9_007_199_254_740_991 { dropped += 1 } }
}

struct DiagnosticStatusSnapshot: Codable, Equatable, Sendable {
    let audio: DiagnosticState
    let recording: DiagnosticState
    let library: DiagnosticState
    let microphoneTest: DiagnosticState
    let controls: DiagnosticState
    let sessionCount: Int
}
struct DiagnosticIssue: Codable, Equatable, Sendable {
    let category: DiagnosticCategory
    let text: String
    let occurredAt: Date?
    init(category: DiagnosticCategory, text: String, occurredAt: Date? = nil) {
        self.category = category; self.text = text; self.occurredAt = occurredAt
    }
}
struct DiagnosticSystemMetadata: Codable, Equatable, Sendable {
    let osVersion: String
    let architecture: DiagnosticArchitecture
}
struct DiagnosticSampleMetadata: Codable, Equatable, Sendable {
    let filename: String
    let encoding: String
    let channels: UInt16
    let sampleRate: UInt32
    let frames: UInt64
    let byteCount: UInt64
}

struct DiagnosticReport: Codable, Equatable, Sendable {
    static let maximumIssueBytes = 8192
    let schemaVersion: Int
    let appVersion: String
    let build: String
    let createdAt: Date
    let issue: DiagnosticIssue
    let status: DiagnosticStatusSnapshot
    let events: [DiagnosticEvent]
    let droppedEventCount: UInt64
    let system: DiagnosticSystemMetadata?
    let sample: DiagnosticSampleMetadata?

    static func make(appVersion: String, build: String, issue: DiagnosticIssue,
                     status: DiagnosticStatusSnapshot, events: DiagnosticEventSnapshot,
                     system: DiagnosticSystemMetadata? = nil, createdAt: Date = Date()) throws -> Self {
        let report = Self(schemaVersion: 1, appVersion: appVersion, build: build, createdAt: createdAt,
                          issue: issue, status: status, events: events.events,
                          droppedEventCount: events.droppedCount, system: system, sample: nil)
        try report.validate()
        return report
    }
    fileprivate func attaching(_ sample: DiagnosticSampleMetadata?) -> Self {
        Self(schemaVersion: schemaVersion, appVersion: appVersion, build: build, createdAt: createdAt,
             issue: issue, status: status, events: events, droppedEventCount: droppedEventCount,
             system: system, sample: sample)
    }
    fileprivate func validate() throws {
        guard schemaVersion == 1, !appVersion.isEmpty, !build.isEmpty,
              appVersion.utf8.count <= 128, build.utf8.count <= 128 else { throw DiagnosticExportError.invalidReport }
        guard issue.text.utf8.count <= Self.maximumIssueBytes,
              createdAt.timeIntervalSince1970.isFinite,
              issue.occurredAt?.timeIntervalSince1970.isFinite != false,
              events.count <= 128, events.allSatisfy({ $0.at.timeIntervalSince1970.isFinite }),
              status.sessionCount >= 0 else { throw DiagnosticExportError.invalidReport }
        if let system { guard !system.osVersion.isEmpty, system.osVersion.utf8.count <= 128 else { throw DiagnosticExportError.invalidReport } }
    }
}

enum DiagnosticExportError: Error, Equatable, LocalizedError {
    case invalidReport, invalidDestination, invalidSample, cancelled, cleanupIncomplete
    case io(operation: String, code: Int32)
    var errorDescription: String? {
        switch self {
        case .invalidReport: return "The report contains an invalid or oversized field."
        case .invalidDestination: return "Choose a new local report folder."
        case .invalidSample: return "The optional sample must be a finalized PCM16 mono or stereo RIFF/WAVE file."
        case .cancelled: return "Diagnostic export was cancelled."
        case .cleanupIncomplete: return "Export did not complete. A partial folder remains at the selected destination."
        case let .io(operation, code): return "Diagnostic export failed during \(operation) (error \(code))."
        }
    }
}

/// Synchronous bounded-memory work. Call from the desktop's export worker, never an audio callback.
enum DiagnosticReportExporter {
    @discardableResult static func write(_ report: DiagnosticReport, to folder: URL,
                                         sample: URL? = nil,
                                         cancelled: @Sendable () -> Bool = { false }) throws -> URL {
        try report.validate()
        guard folder.isFileURL, !folder.path.utf8.contains(0), !folder.path.isEmpty else { throw DiagnosticExportError.invalidDestination }
        try checkCancellation(cancelled)
        let source = try sample.map { try SampleSource($0, cancelled: cancelled) }
        defer { source?.close() }
        let complete = report.attaching(source?.metadata)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        var json = try encoder.encode(complete); json.append(10)
        guard json.count <= 128 * 1024 else { throw DiagnosticExportError.invalidReport }
        try checkCancellation(cancelled)
        guard folder.path.withCString({ Darwin.mkdir($0, 0o700) }) == 0 else {
            throw DiagnosticExportError.io(operation: "create folder", code: errno)
        }
        let directory = folder.path.withCString { Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW) }
        guard directory >= 0 else { throw DiagnosticExportError.cleanupIncomplete }
        defer { Darwin.close(directory) }
        var directoryInfo = stat()
        guard Darwin.fstat(directory, &directoryInfo) == 0 else { throw DiagnosticExportError.cleanupIncomplete }
        var owned: [(String, FileIdentity)] = []
        do {
            guard Darwin.fchmod(directory, 0o700) == 0 else { throw io("set folder permissions") }
            try checkCancellation(cancelled)
            if let source {
                let descriptor = try create("sample.wav", in: directory, owned: &owned)
                do {
                    try source.copy(to: descriptor, cancelled: cancelled)
                    guard Darwin.fsync(descriptor) == 0 else { throw io("synchronize sample") }
                } catch { Darwin.close(descriptor); throw error }
                guard Darwin.close(descriptor) == 0 else { throw io("close sample") }
            }
            let descriptor = try create("report.json", in: directory, owned: &owned)
            do {
                try writeAll(json, to: descriptor, cancelled: cancelled)
                guard Darwin.fsync(descriptor) == 0 else { throw io("synchronize report") }
            } catch { Darwin.close(descriptor); throw error }
            guard Darwin.close(descriptor) == 0 else { throw io("close report") }
            try checkCancellation(cancelled)
            guard Darwin.fsync(directory) == 0 else { throw io("synchronize folder") }
            var finalInfo = stat()
            guard folder.path.withCString({ Darwin.lstat($0, &finalInfo) }) == 0,
                  FileIdentity(finalInfo) == FileIdentity(directoryInfo) else {
                throw DiagnosticExportError.invalidDestination
            }
            return folder
        } catch {
            guard cleanup(directory: directory, folder: folder, identity: FileIdentity(directoryInfo), owned: owned) else {
                throw DiagnosticExportError.cleanupIncomplete
            }
            throw error
        }
    }
    private static func create(_ name: String, in directory: Int32, owned: inout [(String, FileIdentity)]) throws -> Int32 {
        let descriptor = name.withCString { Darwin.openat(directory, $0, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600) }
        guard descriptor >= 0 else { throw io("create file") }
        var info = stat()
        guard Darwin.fstat(descriptor, &info) == 0 else { Darwin.close(descriptor); throw DiagnosticExportError.cleanupIncomplete }
        owned.append((name, FileIdentity(info)))
        guard Darwin.fchmod(descriptor, 0o600) == 0 else { Darwin.close(descriptor); throw io("set file permissions") }
        return descriptor
    }
    private static func cleanup(directory: Int32, folder: URL, identity: FileIdentity,
                                owned: [(String, FileIdentity)]) -> Bool {
        var okay = true
        for (name, expected) in owned.reversed() {
            var info = stat()
            let found = name.withCString { Darwin.fstatat(directory, $0, &info, AT_SYMLINK_NOFOLLOW) }
            if found != 0 { if errno != ENOENT { okay = false }; continue }
            guard FileIdentity(info) == expected else { okay = false; continue }
            if name.withCString({ Darwin.unlinkat(directory, $0, 0) }) != 0 { okay = false }
        }
        var current = stat()
        guard folder.path.withCString({ Darwin.lstat($0, &current) }) == 0 else { return errno == ENOENT && okay }
        guard FileIdentity(current) == identity else { return false }
        if folder.path.withCString({ Darwin.rmdir($0) }) != 0 { okay = false }
        return okay
    }
    private static func io(_ operation: String) -> DiagnosticExportError { .io(operation: operation, code: errno) }
}

private struct FileIdentity: Equatable {
    let device: dev_t
    let inode: ino_t
    init(_ value: stat) { device = value.st_dev; inode = value.st_ino }
}
private func checkCancellation(_ cancelled: () -> Bool) throws {
    if cancelled() { throw DiagnosticExportError.cancelled }
}
private func writeAll(_ data: Data, to descriptor: Int32, cancelled: () -> Bool) throws {
    try data.withUnsafeBytes { buffer in
        var offset = 0
        while offset < buffer.count {
            try checkCancellation(cancelled)
            let count = Darwin.write(descriptor, buffer.baseAddress!.advanced(by: offset), min(65536, buffer.count - offset))
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { throw DiagnosticExportError.io(operation: "write file", code: errno) }
            offset += count
        }
    }
}

private final class SampleSource {
    private var descriptor: Int32
    private let initial: stat
    let metadata: DiagnosticSampleMetadata
    init(_ url: URL, cancelled: () -> Bool) throws {
        guard url.isFileURL, !url.path.utf8.contains(0) else { throw DiagnosticExportError.invalidSample }
        descriptor = url.path.withCString { Darwin.open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK) }
        guard descriptor >= 0 else { throw DiagnosticExportError.io(operation: "open optional sample", code: errno) }
        var info = stat()
        guard Darwin.fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_size >= 44, UInt64(info.st_size) <= UInt64(UInt32.max) + 8 else {
            Darwin.close(descriptor); descriptor = -1; throw DiagnosticExportError.invalidSample
        }
        initial = info
        do { metadata = try Self.inspect(descriptor, size: UInt64(info.st_size), cancelled: cancelled) }
        catch { Darwin.close(descriptor); descriptor = -1; throw error }
    }
    func close() { if descriptor >= 0 { Darwin.close(descriptor); descriptor = -1 } }
    deinit { close() }
    func copy(to output: Int32, cancelled: () -> Bool) throws {
        guard Darwin.lseek(descriptor, 0, SEEK_SET) == 0 else { throw DiagnosticExportError.io(operation: "seek sample", code: errno) }
        var remaining = UInt64(initial.st_size)
        var buffer = [UInt8](repeating: 0, count: 65536)
        while remaining > 0 {
            try checkCancellation(cancelled)
            let count = Darwin.read(descriptor, &buffer, min(buffer.count, Int(remaining)))
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { throw DiagnosticExportError.io(operation: "read sample", code: errno) }
            try writeAll(Data(buffer.prefix(count)), to: output, cancelled: cancelled)
            remaining -= UInt64(count)
        }
        var current = stat()
        guard Darwin.fstat(descriptor, &current) == 0, FileIdentity(initial) == FileIdentity(current),
              current.st_size == initial.st_size, current.st_mtimespec.tv_sec == initial.st_mtimespec.tv_sec,
              current.st_mtimespec.tv_nsec == initial.st_mtimespec.tv_nsec else { throw DiagnosticExportError.invalidSample }
    }
    private static func inspect(_ descriptor: Int32, size: UInt64, cancelled: () -> Bool) throws -> DiagnosticSampleMetadata {
        func read(_ offset: UInt64, _ count: Int) throws -> [UInt8] {
            try checkCancellation(cancelled)
            var data = [UInt8](repeating: 0, count: count)
            var done = 0
            while done < count {
                let received = data.withUnsafeMutableBytes { Darwin.pread(descriptor, $0.baseAddress!.advanced(by: done), count - done, off_t(offset) + off_t(done)) }
                if received < 0, errno == EINTR { continue }
                guard received > 0 else { throw DiagnosticExportError.invalidSample }
                done += received
            }
            return data
        }
        func word(_ bytes: [UInt8], _ at: Int, _ count: Int) -> UInt32 {
            (0..<count).reduce(UInt32(0)) { $0 | UInt32(bytes[at + $1]) << ($1 * 8) }
        }
        let header = try read(0, 12)
        guard Array(header[0..<4]) == Array("RIFF".utf8), Array(header[8..<12]) == Array("WAVE".utf8),
              UInt64(word(header, 4, 4)) + 8 == size else { throw DiagnosticExportError.invalidSample }
        var offset: UInt64 = 12, format: (UInt16, UInt32, UInt16)?, dataBytes: UInt32?
        while offset < size {
            guard size - offset >= 8 else { throw DiagnosticExportError.invalidSample }
            let chunk = try read(offset, 8), length = word(chunk, 4, 4)
            let end = offset + 8 + UInt64(length)
            guard end <= size, end + UInt64(length % 2) <= size else { throw DiagnosticExportError.invalidSample }
            if Array(chunk[0..<4]) == Array("fmt ".utf8) {
                guard format == nil, length == 16 || length == 18 else { throw DiagnosticExportError.invalidSample }
                let f = try read(offset + 8, Int(length))
                let channels = word(f, 2, 2), rate = word(f, 4, 4), alignment = word(f, 12, 2)
                guard word(f, 0, 2) == 1, channels == 1 || channels == 2, rate > 0,
                      word(f, 14, 2) == 16, alignment == channels * 2,
                      UInt64(word(f, 8, 4)) == UInt64(rate) * UInt64(alignment),
                      length == 16 || word(f, 16, 2) == 0 else { throw DiagnosticExportError.invalidSample }
                format = (UInt16(channels), rate, UInt16(alignment))
            } else if Array(chunk[0..<4]) == Array("data".utf8) {
                guard dataBytes == nil, length > 0 else { throw DiagnosticExportError.invalidSample }
                dataBytes = length
            }
            offset = end + UInt64(length % 2)
        }
        guard let format, let dataBytes, dataBytes % UInt32(format.2) == 0 else { throw DiagnosticExportError.invalidSample }
        return DiagnosticSampleMetadata(filename: "sample.wav", encoding: "PCM16", channels: format.0,
                                        sampleRate: format.1, frames: UInt64(dataBytes) / UInt64(format.2), byteCount: size)
    }
}
