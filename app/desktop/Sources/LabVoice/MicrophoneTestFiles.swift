import Foundation
import AVFoundation
import Darwin

struct MicrophoneTestJob: Codable, Equatable, Sendable {
    let id: UUID
    let directory: URL
    var original: URL { directory.appendingPathComponent("original.wav") }
    var processed: URL { directory.appendingPathComponent("processed.wav") }
}
struct MicrophoneTestPreparationFailure: Error { let job: MicrophoneTestJob; let underlying: Error }
protocol MicrophoneTestStoring: Sendable {
    func prepare(id: UUID, inputUID: String) async throws -> MicrophoneTestJob
    func validate(_ job: MicrophoneTestJob, frames: UInt64, originalPath: String, processedPath: String) async throws
    func remove(_ job: MicrophoneTestJob) async throws
    func retained() async throws -> [String]
}
actor MicrophoneTestFiles: MicrophoneTestStoring {
    private let rootOverride: URL?
    private var owned = Set<UUID>()
    init(root: URL? = nil) { rootOverride = root }
    private func root() throws -> URL {
        if let rootOverride { return rootOverride }
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let app = support.appendingPathComponent("Lab Voice", isDirectory: true)
        if !FileManager.default.fileExists(atPath: app.path) {
            try FileManager.default.createDirectory(at: app, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        try plainDirectory(app)
        return app.appendingPathComponent("microphone-tests", isDirectory: true)
    }
    func prepare(id: UUID, inputUID: String) throws -> MicrophoneTestJob {
        let base = try root()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try plainDirectory(base)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: base.path)
        let job = MicrophoneTestJob(id: id, directory: base.appendingPathComponent(id.uuidString, isDirectory: true))
        try FileManager.default.createDirectory(at: job.directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        owned.insert(id)
        do {
            let manifest = try JSONSerialization.data(withJSONObject: ["operationID": id.uuidString, "inputUID": inputUID, "purpose": "temporary microphone comparison"])
            let descriptor = job.directory.appendingPathComponent("job.json").path.withCString { Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600) }
            guard descriptor >= 0 else { throw AudioHelperError.inventoryFailed("Cannot create private test manifest, OS error \(errno).") }
            let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? file.close() }
            try file.write(contentsOf: manifest); try file.synchronize()
            return job
        } catch { throw MicrophoneTestPreparationFailure(job: job, underlying: error) }
    }
    func validate(_ job: MicrophoneTestJob, frames: UInt64, originalPath: String, processedPath: String) throws {
        let base = try root()
        guard job.directory.standardizedFileURL == base.appendingPathComponent(job.id.uuidString).standardizedFileURL,
              owned.contains(job.id), frames >= 240000, frames <= 2880000,
              originalPath == job.original.path, processedPath == job.processed.path else { throw MicrophoneTestError.invalidFiles }
        try plainDirectory(job.directory)
        for url in [job.original, job.processed] {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize, size >= 44,
                  (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 else { throw MicrophoneTestError.invalidFiles }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let header = try file.read(upToCount: 12) ?? Data()
            guard header.count == 12, header.prefix(4) == Data("RIFF".utf8), header.suffix(4) == Data("WAVE".utf8) else { throw MicrophoneTestError.invalidFiles }
            let sizeInHeader = header[4..<8].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
            guard UInt64(sizeInHeader) + 8 == UInt64(size) else { throw MicrophoneTestError.invalidFiles }
            let audio = try AVAudioFile(forReading: url)
            guard audio.length == Int64(frames), audio.fileFormat.sampleRate == 48000,
                  audio.fileFormat.channelCount == 1, audio.fileFormat.commonFormat == .pcmFormatInt16 else { throw MicrophoneTestError.invalidFiles }
        }
    }
    func remove(_ job: MicrophoneTestJob) throws {
        let base = try root()
        guard owned.contains(job.id), job.directory.standardizedFileURL == base.appendingPathComponent(job.id.uuidString).standardizedFileURL else { throw MicrophoneTestError.invalidFiles }
        try plainDirectory(base); try plainDirectory(job.directory)
        try FileManager.default.removeItem(at: job.directory)
        owned.remove(job.id)
    }
    func retained() throws -> [String] {
        let base = try root()
        guard FileManager.default.fileExists(atPath: base.path) else { return [] }
        try plainDirectory(base)
        return try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            .filter { url in
                guard UUID(uuidString: url.lastPathComponent) != nil,
                      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
                return values.isDirectory == true && values.isSymbolicLink != true
            }.map(\.path).sorted()
    }
    private func plainDirectory(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw MicrophoneTestError.invalidFiles }
    }
}
enum MicrophoneTestError: Error { case invalidFiles, unavailable }
