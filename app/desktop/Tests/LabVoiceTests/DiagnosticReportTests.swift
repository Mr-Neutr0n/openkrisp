import XCTest
import Darwin
@testable import LabVoice

@MainActor final class DiagnosticReportTests: XCTestCase {
    private func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func report(text: String = "Explicit issue", system: DiagnosticSystemMetadata? = nil) throws -> DiagnosticReport {
        try .make(appVersion: "1", build: "2", issue: .init(category: .audio, text: text, occurredAt: Date(timeIntervalSince1970: 10)),
                  status: .init(audio: .running, recording: .idle, library: .ready, microphoneTest: .idle, controls: .ready, sessionCount: 2),
                  events: .init(events: [], droppedCount: 0), system: system, createdAt: Date(timeIntervalSince1970: 20))
    }
    private func wav(frames: Int = 100, channels: UInt16 = 1) -> Data {
        var data = Data()
        func string(_ value: String) { data.append(contentsOf: value.utf8) }
        func word(_ value: UInt32, _ count: Int) { for n in 0..<count { data.append(UInt8(truncatingIfNeeded: value >> (8 * n))) } }
        let bytes = UInt32(frames) * UInt32(channels) * 2
        string("RIFF"); word(36 + bytes, 4); string("WAVEfmt "); word(16, 4); word(1, 2)
        word(UInt32(channels), 2); word(48000, 4); word(48000 * UInt32(channels) * 2, 4)
        word(UInt32(channels) * 2, 2); word(16, 2); string("data"); word(bytes, 4)
        for n in 0..<Int(bytes) { data.append(UInt8(truncatingIfNeeded: n)) }
        return data
    }
    private func mode(_ url: URL) throws -> Int { try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber).intValue }

    func testTypedLogIsBoundedAndSnapshotsDoNotChange() throws {
        let log = DiagnosticEventLog(maximumEvents: 2)
        log.append(component: .audio, code: .started, severity: .info, at: Date(timeIntervalSince1970: 1))
        let earlier = log.snapshot()
        log.append(component: .library, code: .locationChanged, severity: .info)
        log.append(component: .recording, code: .operationFailed, severity: .error)
        XCTAssertFalse(log.append(component: .app, code: .started, severity: .info, at: Date(timeIntervalSince1970: .nan)))
        XCTAssertEqual(earlier.events.count, 1)
        XCTAssertEqual(log.snapshot().events.map(\.sequence), [2, 3])
        XCTAssertEqual(log.snapshot().droppedCount, 2)
        let large = DiagnosticEventLog(maximumEvents: 1000)
        for _ in 0..<150 { large.append(component: .app, code: .stateChanged, severity: .info) }
        XCTAssertEqual(large.snapshot().events.count, 128)
    }
    func testReportBoundsAndExplicitOptions() throws {
        XCTAssertNoThrow(try report(text: String(repeating: "é", count: 4096)))
        XCTAssertThrowsError(try report(text: String(repeating: "é", count: 4097)))
        let basic = String(decoding: try JSONEncoder().encode(report()), as: UTF8.self)
        XCTAssertTrue(basic.contains("occurredAt")); XCTAssertFalse(basic.contains("osVersion"))
        let optional = String(decoding: try JSONEncoder().encode(report(system: .init(osVersion: "test", architecture: .arm64))), as: UTF8.self)
        XCTAssertTrue(optional.contains("arm64")); XCTAssertTrue(optional.contains("osVersion"))
        XCTAssertThrowsError(try report(system: .init(osVersion: String(repeating: "x", count: 129), architecture: .unknown)))
    }
    func testDeterministicPrivateExportAndNoOverwrite() throws {
        let root = try temporary(), first = root.appendingPathComponent("first"), second = root.appendingPathComponent("second")
        try DiagnosticReportExporter.write(report(), to: first)
        try DiagnosticReportExporter.write(report(), to: second)
        let json = first.appendingPathComponent("report.json"), bytes = try Data(contentsOf: json)
        XCTAssertEqual(bytes, try Data(contentsOf: second.appendingPathComponent("report.json")))
        XCTAssertEqual(try mode(first), 0o700); XCTAssertEqual(try mode(json), 0o600)
        XCTAssertThrowsError(try DiagnosticReportExporter.write(report(text: "changed"), to: first))
        XCTAssertEqual(bytes, try Data(contentsOf: json))
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains(root.path))
    }
    func testSelectedSampleIsCopiedExactlyWithMetadata() throws {
        let root = try temporary(), source = root.appendingPathComponent("selected.wav"), target = root.appendingPathComponent("report")
        let bytes = wav(frames: 239, channels: 2); try bytes.write(to: source)
        try DiagnosticReportExporter.write(report(), to: target, sample: source)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("sample.wav")), bytes)
        XCTAssertEqual(try mode(target.appendingPathComponent("sample.wav")), 0o600)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: target.appendingPathComponent("report.json"))) as? [String: Any])
        let sample = try XCTUnwrap(json["sample"] as? [String: Any])
        XCTAssertEqual(sample["frames"] as? Int, 239); XCTAssertEqual(sample["channels"] as? Int, 2)
        XCTAssertEqual(sample["filename"] as? String, "sample.wav")
        XCTAssertFalse(String(describing: json).contains("selected.wav"))
    }
    func testMalformedAndSymlinkSamplesNeverCreateDestination() throws {
        let root = try temporary()
        var malformed = [Data("not wave".utf8), wav()]
        malformed[1][20] = 3 // IEEE float is outside this explicitly supported format.
        var truncated = wav(); truncated.removeLast(); malformed.append(truncated)
        var alignment = wav(); alignment[32] = 4; malformed.append(alignment)
        for (index, bytes) in malformed.enumerated() {
            let source = root.appendingPathComponent("source\(index)"), target = root.appendingPathComponent("target\(index)")
            try bytes.write(to: source)
            XCTAssertThrowsError(try DiagnosticReportExporter.write(report(), to: target, sample: source))
            XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        }
        let source = root.appendingPathComponent("valid"), link = root.appendingPathComponent("link"), target = root.appendingPathComponent("symlink-result")
        try wav().write(to: source); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        XCTAssertThrowsError(try DiagnosticReportExporter.write(report(), to: target, sample: link))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }
    func testCancellationBeforeAndDuringCopyRemovesOnlyOwnedOutput() throws {
        let root = try temporary(), source = root.appendingPathComponent("source"), target = root.appendingPathComponent("target")
        let bytes = wav(frames: 150000); try bytes.write(to: source)
        XCTAssertThrowsError(try DiagnosticReportExporter.write(report(), to: target, cancelled: { true })) { XCTAssertEqual($0 as? DiagnosticExportError, .cancelled) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        let sample = target.appendingPathComponent("sample.wav")
        XCTAssertThrowsError(try DiagnosticReportExporter.write(report(), to: target, sample: source, cancelled: {
            let size = (try? FileManager.default.attributesOfItem(atPath: sample.path)[.size] as? NSNumber)?.intValue ?? 0
            return size >= 65536
        })) { XCTAssertEqual($0 as? DiagnosticExportError, .cancelled) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }
    func testForeignCollisionIsPreservedAndCleanupFailureIsExplicit() throws {
        let root = try temporary(), target = root.appendingPathComponent("target"), foreign = target.appendingPathComponent("report.json")
        XCTAssertThrowsError(try DiagnosticReportExporter.write(report(), to: target, cancelled: {
            if FileManager.default.fileExists(atPath: target.path), !FileManager.default.fileExists(atPath: foreign.path) {
                try? Data("foreign".utf8).write(to: foreign, options: .withoutOverwriting)
            }
            return false
        })) { XCTAssertEqual($0 as? DiagnosticExportError, .cleanupIncomplete) }
        XCTAssertEqual(try Data(contentsOf: foreign), Data("foreign".utf8))
    }
    func testMissingParentAndExistingFileFailWithoutMutation() throws {
        let root = try temporary(), file = root.appendingPathComponent("file")
        try Data("keep".utf8).write(to: file)
        XCTAssertThrowsError(try DiagnosticReportExporter.write(report(), to: file))
        XCTAssertEqual(try Data(contentsOf: file), Data("keep".utf8))
        XCTAssertThrowsError(try DiagnosticReportExporter.write(report(), to: root.appendingPathComponent("missing/child")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("missing").path))
    }
    func testSpecialSampleAndInaccessibleParentFailWithoutOutput() throws {
        let root = try temporary(), fifo = root.appendingPathComponent("fifo"), target = root.appendingPathComponent("result")
        XCTAssertEqual(Darwin.mkfifo(fifo.path, 0o600), 0)
        XCTAssertThrowsError(try DiagnosticReportExporter.write(report(), to: target, sample: fifo))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        guard Darwin.geteuid() != 0 else { throw XCTSkip("Permission admission requires an unprivileged user") }
        let parent = root.appendingPathComponent("restricted")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        XCTAssertEqual(Darwin.chmod(parent.path, 0o500), 0)
        defer { _ = Darwin.chmod(parent.path, 0o700) }
        XCTAssertThrowsError(try DiagnosticReportExporter.write(report(), to: parent.appendingPathComponent("new")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: parent.appendingPathComponent("new").path))
    }

    func testRenamedOwnedFolderCannotReportSuccess() throws {
        let root = try temporary(), target = root.appendingPathComponent("target"), moved = root.appendingPathComponent("moved")
        XCTAssertThrowsError(try DiagnosticReportExporter.write(report(), to: target, cancelled: {
            if FileManager.default.fileExists(atPath: target.appendingPathComponent("report.json").path) {
                try? FileManager.default.moveItem(at: target, to: moved)
            }
            return false
        }))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: moved.appendingPathComponent("report.json").path))
    }

}
