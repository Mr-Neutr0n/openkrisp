import Foundation
import Darwin

// Only explicit imports populate this independent cache. No vendor paths or network lookup.
struct LocalHeadsetCompatibilityStore {
    static let byteLimit = 1_048_576
    let directory: URL
    var cacheURL: URL { directory.appendingPathComponent("compatibility.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lab Voice/headset-compatibility", isDirectory: true)
    }

    func load(preserving previous: LocalHeadsetLists) -> LocalHeadsetCacheLoad {
        do {
            try validateDirectory(create: false)
            return LocalHeadsetPolicy.loadCache(try read(cacheURL), preserving: previous)
        } catch { return failure("Cannot load saved compatibility list: \(error.localizedDescription)", previous) }
    }

    func importFile(at url: URL, preserving previous: LocalHeadsetLists) -> LocalHeadsetCacheLoad {
        do {
            let data = try read(url)
            let result = LocalHeadsetPolicy.loadCache(data, preserving: previous)
            guard result.loaded else { return result }
            try validateDirectory(create: true)
            try rejectUnsafeSavedFile()
            try data.write(to: cacheURL, options: [.atomic])
            return result
        } catch { return failure("Cannot import compatibility list: \(error.localizedDescription)", previous) }
    }

    func clear(preserving previous: LocalHeadsetLists) -> LocalHeadsetCacheLoad {
        do {
            if FileManager.default.fileExists(atPath: directory.path) {
                try validateDirectory(create: false)
                try rejectUnsafeSavedFile()
                if FileManager.default.fileExists(atPath: cacheURL.path) {
                    try FileManager.default.removeItem(at: cacheURL)
                }
            }
            return .init(lists: .init(manual: previous.manual), loaded: true, failure: nil)
        } catch { return failure("Cannot clear saved compatibility list: \(error.localizedDescription)", previous) }
    }

    private func failure(_ message: String, _ previous: LocalHeadsetLists) -> LocalHeadsetCacheLoad {
        .init(lists: previous, loaded: false, failure: message)
    }

    private func validateDirectory(create: Bool) throws {
        if create {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory,
              directory.standardizedFileURL.resolvingSymlinksInPath() == directory.standardizedFileURL else {
            throw StoreError.invalidDirectory
        }
    }

    private func rejectUnsafeSavedFile() throws {
        // attributesOfItem also detects dangling links, which fileExists omits.
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: cacheURL.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else { throw StoreError.notRegular }
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) {
            return
        }
    }

    private func read(_ url: URL) throws -> Data {
        guard url.isFileURL else { throw StoreError.notRegular }
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        guard info.st_mode & S_IFMT == S_IFREG else { throw StoreError.notRegular }
        guard info.st_size <= Self.byteLimit else { throw StoreError.tooLarge }
        // Read one excess byte to detect a file that grows after fstat, without unbounded allocation.
        var data = Data()
        while data.count <= Self.byteLimit {
            let chunk = try handle.read(upToCount: min(65_536, Self.byteLimit + 1 - data.count)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
        }
        guard data.count <= Self.byteLimit else { throw StoreError.tooLarge }
        return data
    }

    private enum StoreError: LocalizedError {
        case notRegular, tooLarge, invalidDirectory
        var errorDescription: String? {
            switch self {
            case .notRegular: return "Select a regular JSON file, not a link or special file."
            case .tooLarge: return "Compatibility JSON exceeds the 1 MiB import limit."
            case .invalidDirectory: return "The saved compatibility folder must be a real directory without symbolic links."
            }
        }
    }
}
