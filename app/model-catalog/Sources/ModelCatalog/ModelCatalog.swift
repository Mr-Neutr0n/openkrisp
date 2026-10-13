import Foundation
import CryptoKit
import Darwin

public enum Redistribution: String, Codable, Sendable { case unknown, permitted, prohibited }
public struct LicenseMetadata: Codable, Equatable, Sendable {
    public let identifier: String?
    public let source: String?
    public let redistribution: Redistribution
    public init(identifier: String? = nil, source: String? = nil, redistribution: Redistribution = .unknown) {
        self.identifier = identifier; self.source = source; self.redistribution = redistribution
    }
    public var isUnknown: Bool { identifier?.isEmpty != false || source?.isEmpty != false || redistribution == .unknown }
}
public struct ModelAsset: Codable, Equatable, Sendable {
    public let id: String
    public let feature: String
    public let localFile: String
    public let sha256: String?
    public let license: LicenseMetadata
    public let configuredType: Int?
    public init(id: String, feature: String, localFile: String, sha256: String?,
                license: LicenseMetadata, configuredType: Int? = nil) {
        self.id = id; self.feature = feature; self.localFile = localFile; self.sha256 = sha256
        self.license = license; self.configuredType = configuredType
    }
}
public struct ProviderManifest: Codable, Sendable {
    public let schemaVersion: Int
    public let providerID: String
    public let models: [ModelAsset]
    public init(providerID: String, models: [ModelAsset]) {
        schemaVersion = 1; self.providerID = providerID; self.models = models
    }
}
public enum AssetIntegrity: String, Sendable {
    case missing, invalidPath, unreadable, notRegularFile, changedDuringRead, hashMismatch, hashUnverified, verified
}
public struct ModelAssessment: Sendable {
    public let asset: ModelAsset
    public let location: String
    public let integrity: AssetIntegrity
    public let observedSHA256: String?
    public var detected: Bool { integrity == .verified || integrity == .hashUnverified || integrity == .hashMismatch }
    public var unknownLicense: Bool { asset.license.isUnknown }
    // Asset validation does not implement or certify inference.
    public var inferenceReady: Bool { false }
    public var inferenceBlocker: String { "No inference backend integrated" }
}
public enum CatalogError: Error { case invalidManifest, invalidPath, fileTooLarge, missingResource, unreadable(Int32) }

public enum ModelCatalog {
    public static func loadIndependentManifest(root: URL, relativeFile: String) throws -> ProviderManifest {
        let fd = try openConfined(root: root, relativeFile: relativeFile)
        defer { Darwin.close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { throw CatalogError.invalidManifest }
        guard info.st_size <= 1_048_576 else { throw CatalogError.fileTooLarge }
        var bytes = Data()
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        while let chunk = try handle.read(upToCount: 65536), !chunk.isEmpty {
            guard bytes.count + chunk.count <= 1_048_576 else { throw CatalogError.fileTooLarge }
            bytes.append(chunk)
        }
        let manifest = try JSONDecoder().decode(ProviderManifest.self, from: bytes)
        try requireValid(manifest)
        return manifest
    }
    private static func requireValid(_ manifest: ProviderManifest) throws {
        guard manifest.schemaVersion == 1, validID(manifest.providerID), !manifest.models.isEmpty,
              manifest.models.count <= 1024, Set(manifest.models.map(\.id)).count == manifest.models.count,
              manifest.models.allSatisfy({ validID($0.id) && !$0.feature.isEmpty &&
                  validPath($0.localFile) && validHash($0.sha256) }) else { throw CatalogError.invalidManifest }
    }
    public static func validate(_ manifest: ProviderManifest, root: URL) throws -> [ModelAssessment] {
        try requireValid(manifest)
        return manifest.models.map { assess($0, root: root, location: manifest.providerID) }
    }
    public static func installedExpectations() throws -> [ModelAsset] {
        let appResources = Bundle.main.resourceURL.flatMap {
            Bundle(url: $0.appendingPathComponent("ModelCatalog_ModelCatalog.bundle"))
        }
        // Signed macOS apps keep resource bundles under Contents/Resources.
        // SwiftPM's generated accessor expects the bundle beside the executable
        // package layout, so use it only outside a packaged .app.
        let url = appResources?.url(forResource: "installed-expectations", withExtension: "json") ??
            (Bundle.main.bundleURL.pathExtension == "app" ? nil :
                Bundle.module.url(forResource: "installed-expectations", withExtension: "json"))
        guard let url else { throw CatalogError.missingResource }
        return try JSONDecoder().decode([ModelAsset].self, from: Data(contentsOf: url))
    }
    // Explicit caller-selected app bundle and dedicated model directory only.
    // No recursive filesystem scan, defaults, downloads, or configuration changes.
    public static func discoverInstalled(appBundle: URL?, downloadedModels: URL?) throws -> [ModelAssessment] {
        let expected = try installedExpectations()
        var result: [ModelAssessment] = []
        for asset in expected {
            if let appBundle {
                let bundleAsset = ModelAsset(id: asset.id, feature: asset.feature,
                    localFile: "Contents/Resources/resources/models/audio/" + asset.localFile,
                    sha256: asset.sha256, license: asset.license, configuredType: asset.configuredType)
                result.append(assess(bundleAsset, root: appBundle, location: "installed-app-bundle"))
            }
            if let downloadedModels { result.append(assess(asset, root: downloadedModels, location: "downloaded-model-directory")) }
        }
        return result
    }
    private static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy {
            ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || [45, 46, 95].contains($0)
        }
    }
    private static func validHash(_ hash: String?) -> Bool {
        guard let hash, hash.utf8.count == 64 else { return false }
        return hash.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }
    }
    private static func validPath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.utf8.contains(0) && !path.contains("\\") &&
        path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
    private static func openConfined(root: URL, relativeFile: String) throws -> Int32 {
        guard root.isFileURL, !root.path.utf8.contains(0), validPath(relativeFile) else { throw CatalogError.invalidPath }
        var directory = root.path.withCString { Darwin.open($0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC) }
        guard directory >= 0 else { throw CatalogError.unreadable(errno) }
        defer { Darwin.close(directory) }
        let components = relativeFile.split(separator: "/").map(String.init)
        for component in components.dropLast() {
            let next = component.withCString { openat(directory, $0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC) }
            guard next >= 0 else { throw CatalogError.unreadable(errno) }
            Darwin.close(directory); directory = next
        }
        let fd = components.last!.withCString { openat(directory, $0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK) }
        guard fd >= 0 else { throw CatalogError.unreadable(errno) }
        return fd
    }
    private static func assess(_ asset: ModelAsset, root: URL, location: String) -> ModelAssessment {
        func result(_ status: AssetIntegrity, _ hash: String? = nil) -> ModelAssessment {
            ModelAssessment(asset: asset, location: location, integrity: status, observedSHA256: hash)
        }
        guard validPath(asset.localFile), asset.sha256 == nil || validHash(asset.sha256) else { return result(.invalidPath) }
        let fd: Int32
        do { fd = try openConfined(root: root, relativeFile: asset.localFile) }
        catch CatalogError.invalidPath { return result(.invalidPath) }
        catch CatalogError.unreadable(let code) { return result(code == ENOENT ? .missing : .unreadable) }
        catch { return result(.unreadable) }
        defer { Darwin.close(fd) }
        var before = stat(), after = stat()
        guard fstat(fd, &before) == 0 else { return result(.unreadable) }
        guard (before.st_mode & S_IFMT) == S_IFREG else { return result(.notRegularFile) }
        var hash = SHA256()
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        do {
            while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
        } catch { return result(.unreadable) }
        guard fstat(fd, &after) == 0 else { return result(.unreadable) }
        guard before.st_size == after.st_size, before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
              before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else { return result(.changedDuringRead) }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard let expected = asset.sha256 else { return result(.hashUnverified, digest) }
        return result(digest == expected ? .verified : .hashMismatch, digest)
    }
}
