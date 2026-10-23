import Foundation
import CryptoKit
import Darwin

struct InstalledAECConfiguration: Equatable, Sendable {
    let workerPath: String
    let workerSHA256: String
    let libraryPath: String
    static let librarySHA256 = "bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a"
    var arguments: [String] {
        ["--aec-provider", "installed-krisp", "--aec-worker", workerPath,
         "--aec-worker-sha256", workerSHA256, "--aec-library", libraryPath]
    }
}
enum InstalledAECError: Error, LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let reason) = self { return reason }; return nil }
}
private struct InstalledAECManifest: Decodable {
    let schemaVersion: Int
    let files: [String: String]
    let librarySha256: String
}
// Selection hashes on a utility task. It never loads the library or starts audio.
actor InstalledAECResolver {
    static let runtimeFiles: Set<String> = ["aec-worker"]
    static func packagedDirectory() throws -> URL {
        guard let resources = Bundle.main.resourceURL else { throw InstalledAECError.invalid("Packaged AEC resources are unavailable.") }
        return resources.appendingPathComponent("helper/aec-worker", isDirectory: true)
    }
    private static func same(_ a: stat, _ b: stat) -> Bool {
        a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_size == b.st_size && a.st_mode == b.st_mode &&
        a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec &&
        a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec
    }
    private static func snapshot(_ url: URL, maximum: Int = 67_108_864) throws -> stat {
        var value = stat()
        guard url.isFileURL, url.path.hasPrefix("/"), !url.path.contains("\0"),
              lstat(url.path, &value) == 0, value.st_mode & S_IFMT == S_IFREG,
              value.st_size > 0, value.st_size <= maximum else {
            throw InstalledAECError.invalid("Expected a bounded regular file without a final symlink: \(url.path)")
        }
        return value
    }
    private static func readFile(_ url: URL, maximum: Int) throws -> Data {
        let before = try snapshot(url, maximum: maximum)
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else { throw InstalledAECError.invalid("Cannot open selected AEC file.") }
        defer { close(descriptor) }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0, same(before, opened) else { throw InstalledAECError.invalid("AEC file identity changed before reading.") }
        var bytes = Data(), scratch = [UInt8](repeating: 0, count: 65536)
        bytes.reserveCapacity(Int(opened.st_size))
        while true {
            let count = read(descriptor, &scratch, scratch.count)
            if count < 0 && errno == EINTR { continue }
            guard count >= 0, bytes.count + max(count, 0) <= opened.st_size else { throw InstalledAECError.invalid("AEC file changed while reading.") }
            if count == 0 { break }
            bytes.append(contentsOf: scratch.prefix(count))
        }
        var after = stat()
        let named = try snapshot(url, maximum: maximum)
        guard bytes.count == opened.st_size, fstat(descriptor, &after) == 0,
              same(opened, after), same(after, named) else { throw InstalledAECError.invalid("AEC file changed during validation.") }
        return bytes
    }
    static func hashFile(_ url: URL) throws -> String {
        SHA256.hash(data: try readFile(url, maximum: 67_108_864)).map { String(format: "%02x", $0) }.joined()
    }
    func resolve(app: URL, runtime: URL,
                 hash: @escaping @Sendable (URL) throws -> String = { try InstalledAECResolver.hashFile($0) }) async throws -> InstalledAECConfiguration {
        try await Task.detached(priority: .utility) { try Self.resolveFiles(app: app, runtime: runtime, hash: hash) }.value
    }
    private static func resolveFiles(app: URL, runtime: URL, hash: (URL) throws -> String) throws -> InstalledAECConfiguration {
        guard [app, runtime].allSatisfy({ $0.isFileURL && $0.path.hasPrefix("/") && !$0.path.contains("\0") }) else {
            throw InstalledAECError.invalid("Choose explicit local AEC paths.")
        }
        let manifestURL = runtime.appendingPathComponent("runtime-manifest.json")
        let manifestBytes = try readFile(manifestURL, maximum: 65536)
        guard let object = try JSONSerialization.jsonObject(with: manifestBytes) as? [String: Any],
              Set(object.keys) == ["schemaVersion", "files", "librarySha256"] else { throw InstalledAECError.invalid("Packaged AEC manifest fields are unsupported.") }
        let manifest = try JSONDecoder().decode(InstalledAECManifest.self, from: manifestBytes)
        guard manifest.schemaVersion == 1, Set(manifest.files.keys) == runtimeFiles,
              manifest.librarySha256 == InstalledAECConfiguration.librarySHA256,
              let workerSHA = manifest.files["aec-worker"], workerSHA.count == 64,
              workerSHA.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw InstalledAECError.invalid("Packaged AEC identity is unsupported.") }
        let worker = runtime.appendingPathComponent("aec-worker")
        let library = app.appendingPathComponent("Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries/libaec-sdk.dylib")
        let workerBefore = try snapshot(worker), libraryBefore = try snapshot(library)
        guard workerBefore.st_mode & 0o111 != 0, access(worker.path, X_OK) == 0 else { throw InstalledAECError.invalid("Packaged AEC worker is not executable.") }
        guard try hash(worker) == workerSHA else { throw InstalledAECError.invalid("Packaged AEC worker failed SHA256 validation.") }
        guard try hash(library) == InstalledAECConfiguration.librarySHA256 else { throw InstalledAECError.invalid("The installed AEC library is not the reviewed version.") }
        guard same(workerBefore, try snapshot(worker)), same(libraryBefore, try snapshot(library)) else {
            throw InstalledAECError.invalid("Selected AEC files changed during validation.")
        }
        guard try readFile(manifestURL, maximum: 65536) == manifestBytes else { throw InstalledAECError.invalid("Packaged AEC manifest changed during validation.") }
        return InstalledAECConfiguration(workerPath: worker.path, workerSHA256: workerSHA, libraryPath: library.path)
    }
}
