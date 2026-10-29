import XCTest
import Foundation
import CryptoKit
@testable import ModelCatalog

final class ModelCatalogTests: XCTestCase {
    private func fixture(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
    private func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
    private func asset(_ file: String, hash: String, license: LicenseMetadata = LicenseMetadata()) -> ModelAsset {
        ModelAsset(id: "fixture-model", feature: "noise-suppression", localFile: file, sha256: hash, license: license)
    }
    func testManifestAndVerifiedAssetRemainUnavailableForInference() throws {
        try fixture { root in
            let bytes = Data("fixture weights, not a real model".utf8)
            try bytes.write(to: root.appendingPathComponent("weights.bin"))
            let manifest = ProviderManifest(providerID: "independent", models: [asset("weights.bin", hash: digest(bytes),
                license: LicenseMetadata(identifier: "test-only", source: "fixture", redistribution: .permitted))])
            try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("provider.json"))
            let loaded = try ModelCatalog.loadIndependentManifest(root: root, relativeFile: "provider.json")
            let report = try ModelCatalog.validate(loaded, root: root)[0]
            XCTAssertEqual(report.integrity, .verified)
            XCTAssertTrue(report.detected)
            XCTAssertFalse(report.unknownLicense)
            XCTAssertFalse(report.inferenceReady)
            XCTAssertEqual(report.observedSHA256, digest(bytes))
        }
    }
    func testMissingCorruptAndUnknownLicense() throws {
        try fixture { root in
            let bytes = Data("expected".utf8)
            let manifest = ProviderManifest(providerID: "independent", models: [asset("model.bin", hash: digest(bytes))])
            XCTAssertEqual(try ModelCatalog.validate(manifest, root: root)[0].integrity, .missing)
            try Data("corrupt".utf8).write(to: root.appendingPathComponent("model.bin"))
            let corrupt = try ModelCatalog.validate(manifest, root: root)[0]
            XCTAssertEqual(corrupt.integrity, .hashMismatch)
            XCTAssertTrue(corrupt.unknownLicense)
            try bytes.write(to: root.appendingPathComponent("model.bin"))
            XCTAssertTrue(try ModelCatalog.validate(manifest, root: root)[0].unknownLicense)
        }
    }
    func testPathsAndSymlinksCannotEscapeRoot() throws {
        try fixture { root in
            let hash = digest(Data())
            for path in ["../secret", "/tmp/secret", "a/../b", "a//b", "./b", "a\\b", "a\0b"] {
                XCTAssertThrowsError(try ModelCatalog.validate(ProviderManifest(providerID: "independent", models: [asset(path, hash: hash)]), root: root))
            }
            let real = root.appendingPathComponent("real")
            try FileManager.default.createDirectory(at: real, withIntermediateDirectories: false)
            try Data().write(to: real.appendingPathComponent("weights"))
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: real)
            let directoryLink = ProviderManifest(providerID: "independent", models: [asset("link/weights", hash: hash)])
            XCTAssertEqual(try ModelCatalog.validate(directoryLink, root: root)[0].integrity, .unreadable)
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("weight-link"), withDestinationURL: real.appendingPathComponent("weights"))
            let fileLink = ProviderManifest(providerID: "independent", models: [asset("weight-link", hash: hash)])
            XCTAssertEqual(try ModelCatalog.validate(fileLink, root: root)[0].integrity, .unreadable)
            let directory = ProviderManifest(providerID: "independent", models: [asset("real", hash: hash)])
            XCTAssertEqual(try ModelCatalog.validate(directory, root: root)[0].integrity, .notRegularFile)
        }
    }
    func testIndependentManifestRequiresHashAndUniqueID() throws {
        try fixture { root in
            let noHash = ModelAsset(id: "fixture", feature: "asr", localFile: "weights", sha256: nil, license: LicenseMetadata())
            let manifests = [ProviderManifest(providerID: "independent", models: [noHash]),
                            ProviderManifest(providerID: "independent", models: [asset("a", hash: digest(Data())), asset("b", hash: digest(Data()))])]
            for manifest in manifests {
                try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("provider.json"))
                XCTAssertThrowsError(try ModelCatalog.loadIndependentManifest(root: root, relativeFile: "provider.json"))
            }
        }
    }
    func testInstalledExpectationsAndBothLocationsUseFixturesOnly() throws {
        try fixture { root in
            let models = try ModelCatalog.installedExpectations()
            XCTAssertEqual(models.count, 11)
            XCTAssertEqual(models.filter { $0.sha256 != nil }.count, 9)
            let downloaded = root.appendingPathComponent("downloaded", isDirectory: true)
            let app = root.appendingPathComponent("app", isDirectory: true)
            try FileManager.default.createDirectory(at: downloaded, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
            let asr = try XCTUnwrap(models.first { $0.id == "asr" })
            try Data("KEF fixture only".utf8).write(to: downloaded.appendingPathComponent(asr.localFile))
            let reports = try ModelCatalog.discoverInstalled(appBundle: app, downloadedModels: downloaded)
            XCTAssertEqual(reports.count, 22)
            let found = try XCTUnwrap(reports.first { $0.asset.id == "asr" && $0.location == "downloaded-model-directory" })
            XCTAssertEqual(found.integrity, .hashMismatch)
            XCTAssertTrue(found.detected)
            XCTAssertTrue(found.unknownLicense)
            XCTAssertFalse(found.inferenceReady)
            XCTAssertEqual(reports.filter { $0.integrity == .missing }.count, 21)
        }
    }
}
