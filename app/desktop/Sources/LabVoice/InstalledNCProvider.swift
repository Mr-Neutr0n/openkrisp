import Foundation
import CryptoKit
import Darwin

enum NoiseProvider: String, CaseIterable, Identifiable {
    case rnnoise, installedKrisp = "installed-krisp"
    var id: String { rawValue }
    var title: String { title(for: .outbound) }
    func title(for role: InstalledNCModelRole) -> String {
        self == .rnnoise ? "Independent RNNoise" : (role == .outboundHVC ? "Installed Krisp background voice" : "Installed Krisp \(role.rawValue) NC")
    }
}
enum InstalledMicrophoneMode: String, CaseIterable, Identifiable {
    case ordinaryNC, backgroundVoice
    var id: String { rawValue }
    var title: String { self == .ordinaryNC ? "Background voice off" : "Automatic background voice (experimental)" }
}
enum InstalledNCModelRole: String, Sendable {
    case outbound, inbound, outboundHVC = "outbound-hvc-lfb"
    var modelFile: String {
        switch self {
        case .outbound: return "c8.f.m.528d1f-1.0.1_1.0.kef"
        case .inbound: return "c8.w.m.d15e29_1.0.kef"
        case .outboundHVC: return "hs.c6.f.m.75df8f.berlin.kef"
        }
    }
    var modelSHA256: String {
        switch self {
        case .outbound: return InstalledNCConfiguration.modelSHA256
        case .inbound: return InstalledNCConfiguration.inboundModelSHA256
        case .outboundHVC: return "54e2913ea45734adc3323407e43f55b14afade256ab4da6226c2b6e30604cbf4"
        }
    }
}
struct InstalledNCConfiguration: Equatable, Sendable {
    let nodePath, workerPath, addonPath, modelPath, adapterPath, libraryPath: String
    let nodeSHA256, adapterSHA256: String
    var modelRole: InstalledNCModelRole = .outbound
    var selectedModelSHA256: String { modelRole.modelSHA256 }
    static let addonSHA256 = "adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755"
    static let modelSHA256 = "12110c114a3c6c4e2a00c26b22d06463239d096da9f7b71a948fd3a7005b355d"
    static let inboundModelSHA256 = "d1e4e2a94fe27dec1a8fd5a7b36cfac38d183a110f738156d85d1317f98fac8a"
    static let reviewedNodeSHA256 = "1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040"
    var arguments: [String] { arguments(speaker: false) }
    func arguments(speaker: Bool) -> [String] {
        let prefix = speaker ? "--speaker-provider-" : "--provider-"
        var args = [speaker ? "--speaker-provider" : "--microphone-provider", "installed-krisp",
         prefix + "node", nodePath, prefix + "worker", workerPath, prefix + "addon", addonPath,
         prefix + "model", modelPath, prefix + "adapter", adapterPath, prefix + "library", libraryPath,
         prefix + "node-sha256", nodeSHA256, prefix + "adapter-sha256", adapterSHA256]
        if !speaker { args += ["--provider-model-role", modelRole.rawValue] }
        return args
    }
}
enum InstalledNCError: Error, LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let reason) = self { return reason }; return nil }
}
struct InstalledRuntimeManifest: Decodable {
    let schemaVersion: Int
    let nodeSha256: String
    let files: [String: String]
}
// The actor hashes selected files off the main actor. Selection never loads a
// native library, starts a child, requests microphone access or copies assets.
actor InstalledNCResolver {
    static let runtimeFiles: Set<String> = ["native-probe.node", "audio_worker.cjs", "worker_session.cjs", "worker_protocol.cjs"]
    static func packagedDirectory() throws -> URL {
        guard let resources = Bundle.main.resourceURL else { throw InstalledNCError.invalid("Packaged worker resources are unavailable.") }
        return resources.appendingPathComponent("helper/installed-worker", isDirectory: true)
    }
    static func hashFile(_ url: URL) throws -> String {
        let filename = url.path
        var before = stat()
        guard lstat(filename, &before) == 0, before.st_mode & S_IFMT == S_IFREG else {
            throw InstalledNCError.invalid("Expected a regular file without a final symlink: \(filename)")
        }
        let descriptor = open(filename, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw InstalledNCError.invalid("Cannot read selected file: \(filename)") }
        defer { close(descriptor) }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0, opened.st_dev == before.st_dev, opened.st_ino == before.st_ino,
              opened.st_size >= 0, opened.st_size <= 1_073_741_824 else { throw InstalledNCError.invalid("Selected file identity is invalid.") }
        var hash = SHA256(), scratch = [UInt8](repeating: 0, count: 65536)
        var total = 0
        while true {
            let count = read(descriptor, &scratch, scratch.count)
            if count < 0 && errno == EINTR { continue }
            guard count >= 0 else { throw InstalledNCError.invalid("Cannot hash selected file.") }
            if count == 0 { break }
            total += count
            guard total <= opened.st_size else { throw InstalledNCError.invalid("Selected file grew during validation.") }
            hash.update(data: Data(scratch.prefix(count)))
        }
        var after = stat(), current = stat()
        guard total == opened.st_size, fstat(descriptor, &after) == 0, lstat(filename, &current) == 0,
              after.st_dev == opened.st_dev, after.st_ino == opened.st_ino, after.st_size == opened.st_size,
              after.st_mtimespec.tv_sec == opened.st_mtimespec.tv_sec, after.st_mtimespec.tv_nsec == opened.st_mtimespec.tv_nsec,
              after.st_ctimespec.tv_sec == opened.st_ctimespec.tv_sec, after.st_ctimespec.tv_nsec == opened.st_ctimespec.tv_nsec,
              current.st_dev == after.st_dev, current.st_ino == after.st_ino else { throw InstalledNCError.invalid("Selected file changed during validation.") }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func resolve(app: URL, node: URL, runtime: URL, role: InstalledNCModelRole = .outbound,
                 hash: @escaping @Sendable (URL) throws -> String = { try InstalledNCResolver.hashFile($0) }) async throws -> InstalledNCConfiguration {
        try await Task.detached(priority: .utility) {
            try Self.resolveFiles(app: app, node: node, runtime: runtime, role: role, hash: hash)
        }.value
    }
    private static func resolveFiles(app: URL, node: URL, runtime: URL, role: InstalledNCModelRole,
                                     hash: (URL) throws -> String) throws -> InstalledNCConfiguration {
        guard [app, node, runtime].allSatisfy({ $0.isFileURL && $0.path.hasPrefix("/") && !$0.path.contains("\0") }) else {
            throw InstalledNCError.invalid("Choose explicit local paths.")
        }
        // Resolve the user-selected Node symlink once, then hash the exact target.
        let resolvedNode = node.resolvingSymlinksInPath()
        guard access(resolvedNode.path, X_OK) == 0 else { throw InstalledNCError.invalid("Selected Node runtime is not executable.") }
        let addon = app.appendingPathComponent("Contents/Resources/app.asar.unpacked/.vite/build/node_modules/kr-media-sp/build/Release/kr-media-sp.node")
        let model = app.appendingPathComponent("Contents/Resources/resources/models/audio/" + role.modelFile)
        let library = app.appendingPathComponent("Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries")
        guard !library.path.contains(":"), !library.path.contains("\n"), !library.path.contains("\r") else { throw InstalledNCError.invalid("Installed library path is unsupported.") }
        var libraryStat = stat()
        guard lstat(library.path, &libraryStat) == 0, libraryStat.st_mode & S_IFMT == S_IFDIR else {
            throw InstalledNCError.invalid("Installed Electron library directory is unavailable.")
        }
        let manifestURL = runtime.appendingPathComponent("runtime-manifest.json")
        var manifestStat = stat()
        guard lstat(manifestURL.path, &manifestStat) == 0, manifestStat.st_mode & S_IFMT == S_IFREG,
              manifestStat.st_size > 0, manifestStat.st_size <= 65536 else { throw InstalledNCError.invalid("Packaged runtime manifest is missing or invalid.") }
        let manifest = try JSONDecoder().decode(InstalledRuntimeManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.schemaVersion == 1, manifest.nodeSha256 == InstalledNCConfiguration.reviewedNodeSHA256,
              Set(manifest.files.keys) == Self.runtimeFiles,
              manifest.files.values.allSatisfy({ $0.count == 64 && $0.allSatisfy { "0123456789abcdef".contains($0) } }) else { throw InstalledNCError.invalid("Packaged runtime identity is unsupported.") }
        for filename in Self.runtimeFiles {
            guard try hash(runtime.appendingPathComponent(filename)) == manifest.files[filename] else { throw InstalledNCError.invalid("Packaged worker file failed SHA256 validation: \(filename)") }
        }
        guard try hash(resolvedNode) == manifest.nodeSha256 else { throw InstalledNCError.invalid("Choose the reviewed Node runtime. Its SHA256 does not match.") }
        guard try hash(addon) == InstalledNCConfiguration.addonSHA256 else { throw InstalledNCError.invalid("The installed addon is not the reviewed version.") }
        guard try hash(model) == role.modelSHA256 else { throw InstalledNCError.invalid("The exact \(role.rawValue) NC model is missing or changed.") }
        return InstalledNCConfiguration(nodePath: resolvedNode.path, workerPath: runtime.appendingPathComponent("audio_worker.cjs").path,
            addonPath: addon.path, modelPath: model.path, adapterPath: runtime.appendingPathComponent("native-probe.node").path,
            libraryPath: library.path, nodeSHA256: manifest.nodeSha256, adapterSHA256: manifest.files["native-probe.node"]!, modelRole: role)
    }
}
