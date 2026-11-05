import Foundation
import Darwin

struct InstalledAccentConfiguration: Equatable, Sendable {
    let nodePath, workerPath, addonPath, modelPath, adapterPath, libraryPath, adapterSHA256: String
    static let modelFilename = "ar_outbound_wb_c_ma_3.11.0_1.0.kef"
    static let modelSHA256 = "8ada1e4c3d2b3ef3c1440e39dfdfb825c7b0a4c0695c9e0ba6b06b576f124855"
    static let addonSHA256 = "adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755"
    static let nodeSHA256 = "1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040"
    var arguments: [String] {
        ["--accent-node", nodePath, "--accent-worker", workerPath, "--accent-addon", addonPath,
         "--accent-model", modelPath, "--accent-adapter", adapterPath, "--accent-library", libraryPath,
         "--accent-adapter-sha256", adapterSHA256]
    }
}
// Admission only hashes user-selected local files. It never opens the model,
// starts a worker, requests capture or copies installed vendor resources.
actor InstalledAccentResolver {
    static let runtimeFiles: Set<String> = ["accent-probe.node", "worker.cjs", "wire.cjs", "identity.cjs"]
    static func packagedDirectory() throws -> URL {
        guard let resources = Bundle.main.resourceURL else { throw InstalledNCError.invalid("Packaged accent resources are unavailable.") }
        return resources.appendingPathComponent("helper/accent-worker", isDirectory: true)
    }
    func resolve(app: URL, node: URL, model: URL, runtime: URL,
                 hash: @escaping @Sendable (URL) throws -> String = { try InstalledNCResolver.hashFile($0) }) async throws -> InstalledAccentConfiguration {
        try await Task.detached(priority: .utility) {
            guard [app,node,model,runtime].allSatisfy({ $0.isFileURL && $0.path.hasPrefix("/") && !$0.path.contains("\0") }) else {
                throw InstalledNCError.invalid("Choose explicit local files for accent conversion.")
            }
            guard model.lastPathComponent == InstalledAccentConfiguration.modelFilename else {
                throw InstalledNCError.invalid("Choose the outbound accent model with its installed filename: " + InstalledAccentConfiguration.modelFilename)
            }
            let node = node.resolvingSymlinksInPath()
            guard access(node.path, X_OK) == 0 else { throw InstalledNCError.invalid("Selected Node runtime is not executable.") }
            let addon = app.appendingPathComponent("Contents/Resources/app.asar.unpacked/.vite/build/node_modules/kr-media-sp/build/Release/kr-media-sp.node")
            let library = app.appendingPathComponent("Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries")
            var info = stat()
            guard !library.path.contains(":"), !library.path.contains("\n"), !library.path.contains("\r"),
                  lstat(library.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
                throw InstalledNCError.invalid("Installed accent dependency directory is unavailable.")
            }
            let manifestURL = runtime.appendingPathComponent("runtime-manifest.json")
            guard lstat(manifestURL.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
                  info.st_size > 0, info.st_size <= 65536 else { throw InstalledNCError.invalid("Packaged accent manifest is unavailable.") }
            let manifest = try JSONDecoder().decode(InstalledRuntimeManifest.self, from: Data(contentsOf: manifestURL))
            guard manifest.schemaVersion == 1, manifest.nodeSha256 == InstalledAccentConfiguration.nodeSHA256,
                  Set(manifest.files.keys) == Self.runtimeFiles,
                  manifest.files.values.allSatisfy({ $0.count == 64 && $0.allSatisfy { "0123456789abcdef".contains($0) } }) else {
                throw InstalledNCError.invalid("Packaged accent identity is unsupported.")
            }
            for name in Self.runtimeFiles {
                guard try hash(runtime.appendingPathComponent(name)) == manifest.files[name] else {
                    throw InstalledNCError.invalid("Packaged accent resource changed: \(name)")
                }
            }
            guard try hash(node) == InstalledAccentConfiguration.nodeSHA256,
                  try hash(addon) == InstalledAccentConfiguration.addonSHA256 else {
                throw InstalledNCError.invalid("The selected app or Node runtime is not the reviewed version.")
            }
            guard try hash(model) == InstalledAccentConfiguration.modelSHA256 else {
                throw InstalledNCError.invalid("Choose the reviewed outbound accent model. Its SHA256 does not match.")
            }
            return InstalledAccentConfiguration(nodePath: node.path, workerPath: runtime.appendingPathComponent("worker.cjs").path,
                addonPath: addon.path, modelPath: model.path, adapterPath: runtime.appendingPathComponent("accent-probe.node").path,
                libraryPath: library.path, adapterSHA256: manifest.files["accent-probe.node"]!)
        }.value
    }
}

struct AccentStartup: Decodable, Sendable {
    private let values: [String: Value]
    private enum Value: Decodable, Sendable {
        case text(String), number(Int), other
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let text = try? value.decode(String.self) { self = .text(text) }
            else if let number = try? value.decode(Int.self) { self = .number(number) }
            else { self = .other }
        }
    }
    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        var fields: [String: Value] = [:]
        for key in container.allKeys where key.stringValue.hasPrefix("accent_") {
            fields[key.stringValue] = try container.decode(Value.self, forKey: key)
        }
        values = fields
    }
    func matches(_ expected: InstalledAccentConfiguration?) -> Bool {
        guard let expected else { return values.isEmpty }
        func text(_ key: String) -> String? { if case .text(let result) = values["accent_" + key] { return result }; return nil }
        func number(_ key: String) -> Int? { if case .number(let result) = values["accent_" + key] { return result }; return nil }
        let required: Set<String> = ["direction", "target", "backend", "model_sha256", "addon_sha256", "node_sha256", "adapter_sha256", "sample_rate", "frame_samples", "scheduling_budget_frames", "maximum_callback_frames", "transport_delay_samples", "empty_policy"]
        guard Set(values.keys) == Set(required.map { "accent_" + $0 }),
              text("direction") == "outbound", text("target") == "us", text("backend") == "accent-direct",
              text("model_sha256") == InstalledAccentConfiguration.modelSHA256,
              text("addon_sha256") == InstalledAccentConfiguration.addonSHA256,
              text("node_sha256") == InstalledAccentConfiguration.nodeSHA256,
              text("adapter_sha256") == expected.adapterSHA256,
              number("sample_rate") == 48000, number("frame_samples") == 480,
              number("scheduling_budget_frames") == 2, text("empty_policy") == "silence-time-slot",
              let maximum = number("maximum_callback_frames"), (1...4096).contains(maximum),
              number("transport_delay_samples") == ((maximum + 958) / 480 + 2) * 480 else { return false }
        return true
    }
}
