import XCTest
import Foundation
import CryptoKit
@testable import LabVoice

private func aecConfiguration() -> InstalledAECConfiguration {
    InstalledAECConfiguration(workerPath: "/fixture/aec-worker", workerSHA256: String(repeating: "a", count: 64), libraryPath: "/fixture/libaec-sdk.dylib")
}
final class InstalledAECResolverTests: XCTestCase {
    func testOwnManifestAndSelectedLibraryAdmission() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("OwnFixture.app"), runtime = root.appendingPathComponent("runtime")
        let library = app.appendingPathComponent("Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries/libaec-sdk.dylib")
        let worker = runtime.appendingPathComponent("aec-worker"), manifestURL = runtime.appendingPathComponent("runtime-manifest.json")
        try FileManager.default.createDirectory(at: library.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
        try Data("own library fixture".utf8).write(to: library)
        try Data("own executable fixture".utf8).write(to: worker)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: worker.path)
        let digest = try InstalledAECResolver.hashFile(worker)
        let manifest: [String: Any] = ["schemaVersion": 1, "files": ["aec-worker": digest], "librarySha256": InstalledAECConfiguration.librarySHA256]
        func write(_ value: [String: Any]) throws { try JSONSerialization.data(withJSONObject: value).write(to: manifestURL) }
        try write(manifest)
        let hash: @Sendable (URL) throws -> String = { url in
            XCTAssertFalse(Thread.isMainThread)
            if url == library { return InstalledAECConfiguration.librarySHA256 }
            return try InstalledAECResolver.hashFile(url)
        }
        let resolver = InstalledAECResolver()
        let config = try await resolver.resolve(app: app, runtime: runtime, hash: hash)
        XCTAssertEqual(config.workerPath, worker.path)
        XCTAssertEqual(config.libraryPath, library.path)
        XCTAssertEqual(config.workerSHA256, digest)
        XCTAssertEqual(config.arguments, ["--aec-provider", "installed-krisp", "--aec-worker", worker.path,
                                         "--aec-worker-sha256", digest, "--aec-library", library.path])
        do { _ = try await resolver.resolve(app: app, runtime: runtime); XCTFail("Own library bytes matched vendor pin") } catch {}
        for target in [worker, library] {
            do {
                _ = try await resolver.resolve(app: app, runtime: runtime, hash: { url in
                    url == target ? String(repeating: "f", count: 64) : try hash(url)
                })
                XCTFail("Accepted changed hash")
            } catch {}
        }
        for change in ["schema", "library", "extra-file", "extra-field", "missing-worker", "uppercase"] {
            var value = manifest
            switch change {
            case "schema": value["schemaVersion"] = 2
            case "library": value["librarySha256"] = digest
            case "extra-file": value["files"] = ["aec-worker": digest, "node": digest]
            case "extra-field": value["nodeSha256"] = digest
            case "missing-worker": value["files"] = [:] as [String: String]
            default: value["files"] = ["aec-worker": digest.uppercased()]
            }
            try write(value)
            do { _ = try await resolver.resolve(app: app, runtime: runtime, hash: hash); XCTFail("Accepted \(change)") } catch {}
        }
        try write(manifest)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: worker.path)
        do { _ = try await resolver.resolve(app: app, runtime: runtime, hash: hash); XCTFail("Accepted nonexecutable worker") } catch {}
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: worker.path)
        do {
            _ = try await resolver.resolve(app: app, runtime: runtime, hash: { url in
                let result = try hash(url)
                if url == library { try Data("changed own fixture".utf8).write(to: worker) }
                return result
            })
            XCTFail("Accepted worker replacement during validation")
        } catch {}
        try Data("own executable fixture".utf8).write(to: worker)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: worker.path)
        let target = root.appendingPathComponent("own-library-target")
        try FileManager.default.moveItem(at: library, to: target)
        try FileManager.default.createSymbolicLink(at: library, withDestinationURL: target)
        do { _ = try await resolver.resolve(app: app, runtime: runtime, hash: hash); XCTFail("Accepted library symlink") } catch {}
    }
    func testActualHasherAndManifestRejectSymlinksAndBounds() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("own-file"), link = root.appendingPathComponent("own-link")
        let bytes = Data("own AEC bytes".utf8); try bytes.write(to: file)
        XCTAssertEqual(try InstalledAECResolver.hashFile(file), SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try InstalledAECResolver.hashFile(link))
        XCTAssertThrowsError(try InstalledAECResolver.hashFile(root))
        XCTAssertThrowsError(try InstalledAECResolver.hashFile(root.appendingPathComponent("missing")))
        let manifest = root.appendingPathComponent("runtime-manifest.json")
        try FileManager.default.createSymbolicLink(at: manifest, withDestinationURL: file)
        let resolver = InstalledAECResolver()
        do { _ = try await resolver.resolve(app: root, runtime: root); XCTFail("Accepted manifest symlink") } catch {}
        try FileManager.default.removeItem(at: manifest)
        try Data(repeating: 32, count: 65537).write(to: manifest)
        do { _ = try await resolver.resolve(app: root, runtime: root); XCTFail("Accepted oversized manifest") } catch {}
    }
}
final class InstalledAECStartupTests: XCTestCase {
    private func expected() -> AudioRouteOptions {
        AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: false, speakerNoise: false, installedAEC: aecConfiguration())
    }
    private func fields(maximum: Int = 4096) -> [String: Any] {
        ["event": "route_started", "input_uid": "mic", "output_uid": "speaker", "microphone_noise": false,
         "speaker_noise": false, "microphone_provider": "installed-krisp-aec", "speaker_provider": "none",
         "aec_provider": "installed-krisp", "aec_worker_sha256": aecConfiguration().workerSHA256,
         "aec_library_sha256": InstalledAECConfiguration.librarySHA256, "aec_delay_samples": ((maximum + 958) / 480 + 2) * 480,
         "aec_maximum_callback_frames": maximum, "aec_scheduling_budget_frames": 2,
         "aec_forward_rate": 48000, "aec_forward_channels": 1, "aec_reference_rate": 48000, "aec_reference_channels": 2]
    }
    private func matches(_ value: [String: Any], _ options: AudioRouteOptions) throws -> Bool {
        try JSONDecoder().decode(AudioStartup.self, from: JSONSerialization.data(withJSONObject: value)).matches(options)
    }
    func testArgumentsAndMicrophoneChainAdmission() {
        let options = expected()
        XCTAssertTrue(options.validProviderRoles)
        XCTAssertEqual(Array(options.arguments.suffix(8)), aecConfiguration().arguments)
        XCTAssertFalse(options.arguments.contains("--provider-node"))
        let conflict = AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: true, speakerNoise: false, installedAEC: aecConfiguration())
        XCTAssertTrue(conflict.validProviderRoles)
    }
    func testStrictAECIdentityFormatsBoundsAndOffPresence() throws {
        for maximum in [1, 480, 512, 4096] { XCTAssertTrue(try matches(fields(maximum: maximum), expected())) }
        let valid = fields()
        let keys = valid.keys.filter { $0.hasPrefix("aec_") }
        for key in keys {
            var value = valid; value.removeValue(forKey: key)
            XCTAssertFalse(try matches(value, expected()), key)
            value = valid; value[key] = NSNull()
            XCTAssertFalse(try matches(value, expected()), key)
        }
        for (key, value) in ["aec_provider": "other", "aec_worker_sha256": String(repeating: "b", count: 64),
                             "aec_library_sha256": String(repeating: "b", count: 64)] {
            var changed = valid; changed[key] = value; XCTAssertFalse(try matches(changed, expected()))
        }
        for (key, value) in [("aec_delay_samples", 5761), ("aec_maximum_callback_frames", 0),
                             ("aec_maximum_callback_frames", 4097), ("aec_scheduling_budget_frames", 3),
                             ("aec_forward_rate", 32000), ("aec_forward_channels", 2),
                             ("aec_reference_rate", 32000), ("aec_reference_channels", 1)] {
            var changed = valid; changed[key] = value; XCTAssertFalse(try matches(changed, expected()))
        }
        for key in ["provider_model_sha256", "provider_delay_samples", "provider_unknown", "aec_unknown"] {
            var changed = valid; changed[key] = NSNull(); XCTAssertFalse(try matches(changed, expected()))
        }
        var off = valid.filter { !$0.key.hasPrefix("aec_") }; off["microphone_provider"] = "none"
        let offOptions = AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: false, speakerNoise: false)
        XCTAssertTrue(try matches(off, offOptions))
        for key in Array(keys) + ["aec_unknown"] {
            var changed = off; changed[key] = NSNull(); XCTAssertFalse(try matches(changed, offOptions))
        }
        let conflict = AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: true, speakerNoise: false, installedAEC: aecConfiguration())
        XCTAssertTrue(conflict.validProviderRoles)
        XCTAssertFalse(try matches(valid, conflict))
    }
    func testChainOrderDelaysAndStrictPresence() throws {
        let mic = InstalledNCConfiguration(nodePath: "/fixture/node", workerPath: "/fixture/worker", addonPath: "/fixture/addon", modelPath: "/fixture/model", adapterPath: "/fixture/adapter", libraryPath: "/fixture/lib", nodeSHA256: InstalledNCConfiguration.reviewedNodeSHA256, adapterSHA256: String(repeating: "c", count: 64))
        let chainKeys = ["microphone_processing_order", "microphone_nc_delay_samples", "microphone_total_delay_samples"]
        for installed in [false, true] { for maximum in [1, 480, 512, 4096] {
            let options = AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: true, speakerNoise: false, installedProvider: installed ? mic : nil, installedAEC: aecConfiguration())
            let delay = ((maximum + 958) / 480 + 2) * 480, nc = installed ? delay : 480
            var value = fields(maximum: maximum); value["microphone_noise"] = true
            value["microphone_provider"] = installed ? "installed-krisp" : "rnnoise"
            value["microphone_processing_order"] = "aec-then-nc"; value["microphone_nc_delay_samples"] = nc; value["microphone_total_delay_samples"] = delay + nc
            if installed {
                value["provider_model_role"] = "outbound"
                value["provider_model_sha256"] = InstalledNCConfiguration.modelSHA256; value["provider_addon_sha256"] = InstalledNCConfiguration.addonSHA256
                value["provider_adapter_sha256"] = mic.adapterSHA256; value["provider_node_sha256"] = mic.nodeSHA256
                value["provider_delay_samples"] = delay; value["provider_maximum_callback_frames"] = maximum
            }
            XCTAssertTrue(try matches(value, options))
            for key in chainKeys {
                var bad = value; bad.removeValue(forKey: key); XCTAssertFalse(try matches(bad, options))
                bad = value; bad[key] = NSNull(); XCTAssertFalse(try matches(bad, options))
            }
            for (key, mutation) in [("microphone_processing_order", "nc-then-aec" as Any), ("microphone_total_delay_samples", delay + nc + 1), ("microphone_nc_delay_samples", nc + 1), ("microphone_nc_unknown", NSNull())] {
                var bad = value; bad[key] = mutation; XCTAssertFalse(try matches(bad, options))
            }
            if installed {
                for roleValue in [NSNull(), "outbound-hvc-lfb"] as [Any] {
                    var bad = value; bad["provider_model_role"] = roleValue; XCTAssertFalse(try matches(bad, options))
                }
                var bad = value; bad.removeValue(forKey: "provider_model_role"); XCTAssertFalse(try matches(bad, options))
            }
            if installed { var bad = value; bad["provider_maximum_callback_frames"] = maximum == 480 ? 512 : 480; XCTAssertFalse(try matches(bad, options)) }
        } }
        let off = AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: false, speakerNoise: false)
        for key in chainKeys + ["microphone_processing_unknown"] {
            var value = fields(); value[key] = NSNull(); XCTAssertFalse(try matches(value, expected()))
            value = fields().filter { !$0.key.hasPrefix("aec_") }; value["microphone_provider"] = "none"; value[key] = NSNull(); XCTAssertFalse(try matches(value, off))
        }
    }
    func testProductionCppChainAcknowledgmentDecodesInSwift() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let worker = temporary.appendingPathComponent("own-worker")
        try Data("#!/bin/sh\nexit 70\n".utf8).write(to: worker)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: worker.path)
        let config = InstalledAECConfiguration(workerPath: worker.path, workerSHA256: try InstalledAECResolver.hashFile(worker), libraryPath: "/unread/fixture-library")
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("audio-host/build/provider-cli-fixture")
        let mic = InstalledNCConfiguration(nodePath: "/fixture/node", workerPath: "/fixture/worker", addonPath: "/fixture/addon", modelPath: "/fixture/model", adapterPath: "/fixture/adapter", libraryPath: "/fixture/lib", nodeSHA256: InstalledNCConfiguration.reviewedNodeSHA256, adapterSHA256: String(repeating: "c", count: 64))
        for mode in 0...2 {
            let options = AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: mode > 0, speakerNoise: false, installedProvider: mode == 2 ? mic : nil, installedAEC: config)
            let process = Process(), pipe = Pipe(); process.executableURL = fixture; process.arguments = options.arguments; process.standardOutput = pipe
            try process.run(); pipe.fileHandleForWriting.closeFile()
            let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
            let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let ack = try XCTUnwrap(envelope["aec_startup"] as? [String: Any])
            var value = fields(); value["microphone_noise"] = mode > 0
            for (key, field) in ack { value[key] = field }
            XCTAssertTrue(try matches(value, options))
        }
    }
    func testSpeakerLaneMatchingRemainsIndependent() throws {
        let speaker = InstalledNCConfiguration(nodePath: "/fixture/node", workerPath: "/fixture/worker", addonPath: "/fixture/addon",
            modelPath: "/fixture/model", adapterPath: "/fixture/adapter", libraryPath: "/fixture/libraries",
            nodeSHA256: InstalledNCConfiguration.reviewedNodeSHA256, adapterSHA256: String(repeating: "c", count: 64), modelRole: .inbound)
        var options = expected(); options.installedSpeakerProvider = speaker
        // Stored noise flags are immutable, so create the explicit enabled profile.
        options = AudioRouteOptions(inputUID: "mic", outputUID: "speaker", microphoneNoise: false, speakerNoise: true,
                                    installedSpeakerProvider: speaker, installedAEC: aecConfiguration())
        var value = fields(); value["speaker_noise"] = true; value["speaker_provider"] = "installed-krisp"
        value["speaker_provider_model_role"] = "inbound"
            value["speaker_provider_model_sha256"] = InstalledNCConfiguration.inboundModelSHA256
        value["speaker_provider_addon_sha256"] = InstalledNCConfiguration.addonSHA256
        value["speaker_provider_node_sha256"] = speaker.nodeSHA256
        value["speaker_provider_adapter_sha256"] = speaker.adapterSHA256
        value["speaker_provider_delay_samples"] = 5760; value["speaker_provider_maximum_callback_frames"] = 4096
        XCTAssertTrue(try matches(value, options))
        value["speaker_provider_maximum_callback_frames"] = 480
        value["speaker_provider_delay_samples"] = 1920
        XCTAssertFalse(try matches(value, options))
        value["speaker_provider_maximum_callback_frames"] = 4096
        value["speaker_provider_delay_samples"] = 5760
        value["speaker_provider_model_sha256"] = InstalledNCConfiguration.modelSHA256
        XCTAssertFalse(try matches(value, options))
        options.installedProvider = speaker
        XCTAssertFalse(options.validProviderRoles)
    }
}
