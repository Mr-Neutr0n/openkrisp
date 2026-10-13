import XCTest
@testable import LocalStore

final class LocalStoreTests: XCTestCase {
    private var temporary: URL!
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: temporary) }

    private func store() throws -> LocalStore { try LocalStore(root: temporary.appendingPathComponent("sessions")) }

    func testRecordedSessionRoundTripAndExport() throws {
        let store = try store()
        let source = temporary.appendingPathComponent("source.wav")
        // A complete mono PCM16 48 kHz WAV with four samples.
        let bytes: [UInt8] = [82,73,70,70,44,0,0,0,87,65,86,69,102,109,116,32,
                             16,0,0,0,1,0,1,0,128,187,0,0,0,119,1,0,2,0,16,0,
                             100,97,116,97,8,0,0,0,0,0,255,127,0,128,0,0]
        let audio = Data(bytes)
        try audio.write(to: source)
        let segment = TranscriptSegment(startSeconds: 0, endSeconds: 0.00005,
                                        speaker: "Speaker 1", text: "An explicitly supplied test transcript.")
        let saved = try store.save(title: "Local session", startedAt: Date(timeIntervalSinceReferenceDate: 800000000.123456),
                                   durationSeconds: 4.0 / 48000, transcript: [segment], recording: source)
        XCTAssertEqual(try store.load(saved.id), saved)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(store.recordingURL(for: saved.id))), audio)
        XCTAssertEqual(try Data(contentsOf: source), audio)
        XCTAssertEqual(try store.search("SUPPLIED").map(\.id), [saved.id])
        XCTAssertEqual(try store.search("speaker 1").map(\.id), [saved.id])
        let export = temporary.appendingPathComponent("transcript.txt")
        try store.exportTranscript(saved.id, to: export)
        let text = try String(contentsOf: export, encoding: .utf8)
        XCTAssertTrue(text.contains("[0.000s] Speaker 1: An explicitly supplied test transcript."))
        XCTAssertThrowsError(try store.exportTranscript(saved.id, to: export))
        XCTAssertEqual(try String(contentsOf: export, encoding: .utf8), text)
        let folder = store.root.appendingPathComponent(saved.id.uuidString)
        for url in [folder.appendingPathComponent("recording.wav"), folder.appendingPathComponent("session.json"), export] {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
        try store.remove(saved.id)
        XCTAssertTrue(try store.inventory().sessions.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testFailedImportStaysOutOfHistoryAndCanBeSeenForRecovery() throws {
        let store = try store()
        let invalid = temporary.appendingPathComponent("unfinished.wav")
        try Data("RIFF".utf8).write(to: invalid)
        XCTAssertThrowsError(try store.save(title: "Unfinished", startedAt: Date(), durationSeconds: 1,
                                          transcript: [], recording: invalid))
        let inventory = try store.inventory()
        XCTAssertTrue(inventory.sessions.isEmpty)
        XCTAssertEqual(inventory.pendingEntries.count, 1)
        XCTAssertEqual(try Data(contentsOf: invalid), Data("RIFF".utf8))
        let reopened = try LocalStore(root: store.root)
        XCTAssertEqual(try reopened.inventory().pendingEntries, inventory.pendingEntries)
    }

    func testCorruptSessionDoesNotHideHealthyTranscriptOnlySession() throws {
        let store = try store()
        let healthy = try store.save(title: "Healthy", startedAt: Date(timeIntervalSince1970: 200),
                                     durationSeconds: 1, transcript: [])
        let broken = try store.save(title: "Broken", startedAt: Date(timeIntervalSince1970: 100),
                                    durationSeconds: 1, transcript: [])
        let manifest = store.root.appendingPathComponent(broken.id.uuidString).appendingPathComponent("session.json")
        try Data("interrupted external edit".utf8).write(to: manifest)
        let inventory = try store.inventory()
        XCTAssertEqual(inventory.sessions.map(\.id), [healthy.id])
        XCTAssertEqual(inventory.unreadableEntries, [broken.id.uuidString])
        XCTAssertNil(try store.recordingURL(for: healthy.id))
    }

    func testInvalidTimingDoesNotPublishSession() throws {
        let store = try store()
        for duration in [-1.0, .infinity, .nan] {
            XCTAssertThrowsError(try store.save(title: "Bad", startedAt: Date(), durationSeconds: duration, transcript: []))
        }
        let invalid = [TranscriptSegment(startSeconds: 2, endSeconds: 1, text: "Reversed"),
                       TranscriptSegment(startSeconds: 0, endSeconds: 2, text: "Beyond duration"),
                       TranscriptSegment(startSeconds: .nan, endSeconds: 1, text: "Not finite")]
        for segment in invalid {
            XCTAssertThrowsError(try store.save(title: "Bad", startedAt: Date(), durationSeconds: 1, transcript: [segment]))
        }
        XCTAssertTrue(try store.inventory().sessions.isEmpty)
        XCTAssertTrue(try store.inventory().pendingEntries.isEmpty)
    }

    func testUntrustedManifestCannotRedirectRecordingOutsideSession() throws {
        let store = try store()
        let saved = try store.save(title: "A", startedAt: Date(), durationSeconds: 1, transcript: [])
        let manifest = store.root.appendingPathComponent(saved.id.uuidString).appendingPathComponent("session.json")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
        json["recordingFilename"] = "../../outside.wav"
        try JSONSerialization.data(withJSONObject: json).write(to: manifest)
        XCTAssertThrowsError(try store.recordingURL(for: saved.id))
        XCTAssertEqual(try store.inventory().unreadableEntries, [saved.id.uuidString])
    }

    func testSourceSymlinkIsRejectedAndHistorySortsNewestFirst() throws {
        let store = try store()
        let first = try store.save(title: "Older", startedAt: Date(timeIntervalSince1970: 100), durationSeconds: 0, transcript: [])
        let second = try store.save(title: "Newer", startedAt: Date(timeIntervalSince1970: 200), durationSeconds: 0, transcript: [])
        XCTAssertEqual(try store.inventory().sessions.map(\.id), [second.id, first.id])
        let source = temporary.appendingPathComponent("target")
        try Data("RIFFxxxxWAVE".utf8).write(to: source)
        let link = temporary.appendingPathComponent("link.wav")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        XCTAssertThrowsError(try store.save(title: "Link", startedAt: Date(), durationSeconds: 0,
                                          transcript: [], recording: link))
    }
}
