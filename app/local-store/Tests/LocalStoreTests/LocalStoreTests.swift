import XCTest
import Darwin
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

    func testStrictExistingMissingLocationDoesNotCreateParents() throws {
        let missing = temporary.appendingPathComponent("absent/library")
        XCTAssertThrowsError(try LocalStore(root: missing, createIfMissing: false))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporary.appendingPathComponent("absent").path))
        let created = try LocalStore(root: missing)
        XCTAssertTrue(try created.inventory().sessions.isEmpty)
    }

    func testTwoSelectedLibrariesReopenWithoutMovingOrChangingContents() throws {
        let first = try LocalStore(root: temporary.appendingPathComponent("first"))
        let second = try LocalStore(root: temporary.appendingPathComponent("second"))
        let a = try first.save(title: "First", startedAt: Date(), durationSeconds: 0, transcript: [])
        let b = try second.save(title: "Second", startedAt: Date(), durationSeconds: 0, transcript: [])
        let unrelated = second.root.appendingPathComponent("user-note.txt")
        try Data("Keep this unrelated file".utf8).write(to: unrelated)
        try FileManager.default.setAttributes([.posixPermissions: 0o750], ofItemAtPath: second.root.path)
        let selectedSecond = try LocalStore(root: second.root, createIfMissing: false)
        XCTAssertEqual(try selectedSecond.inventory().sessions.map(\.id), [b.id])
        let selectedFirst = try LocalStore(root: first.root, createIfMissing: false)
        XCTAssertEqual(try selectedFirst.inventory().sessions.map(\.id), [a.id])
        XCTAssertEqual(try first.load(a.id), a)
        XCTAssertEqual(try String(contentsOf: unrelated, encoding: .utf8), "Keep this unrelated file")
        let permissions = try FileManager.default.attributesOfItem(atPath: second.root.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o750)
    }

    func testStrictReopenKeepsHealthyCorruptAndPendingEntries() throws {
        let created = try store()
        let healthy = try created.save(title: "Healthy", startedAt: Date(), durationSeconds: 0, transcript: [])
        let corrupt = UUID().uuidString
        let corruptFolder = created.root.appendingPathComponent(corrupt)
        try FileManager.default.createDirectory(at: corruptFolder, withIntermediateDirectories: false)
        try Data("broken manifest".utf8).write(to: corruptFolder.appendingPathComponent("session.json"))
        let pending = ".pending-" + UUID().uuidString
        let pendingFolder = created.root.appendingPathComponent(pending)
        try FileManager.default.createDirectory(at: pendingFolder, withIntermediateDirectories: false)
        try Data("partial data".utf8).write(to: pendingFolder.appendingPathComponent("recording.wav"))
        let reopened = try LocalStore(root: created.root, createIfMissing: false)
        let inventory = try reopened.inventory()
        XCTAssertEqual(inventory.sessions.map(\.id), [healthy.id])
        XCTAssertEqual(inventory.unreadableEntries, [corrupt])
        XCTAssertEqual(inventory.pendingEntries, [pending])
        XCTAssertEqual(try Data(contentsOf: pendingFolder.appendingPathComponent("recording.wav")), Data("partial data".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptFolder.path))
    }

    func testFileAndSymlinkLocationsAreRejectedWithoutChangingTargets() throws {
        let file = temporary.appendingPathComponent("file")
        try Data("not a directory".utf8).write(to: file)
        XCTAssertThrowsError(try LocalStore(root: file, createIfMissing: false))
        let target = try store()
        let link = temporary.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target.root)
        XCTAssertThrowsError(try LocalStore(root: link, createIfMissing: false))
        XCTAssertThrowsError(try LocalStore(root: link.appendingPathComponent(""), createIfMissing: false))
        XCTAssertTrue(try target.inventory().sessions.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), Data("not a directory".utf8))
    }

    func testInaccessibleLocationNeverChangesPermissionsOrFallsBack() throws {
        guard geteuid() != 0 else { throw XCTSkip("Permission assertions require an unprivileged process") }
        let opened = try store()
        let location = opened.root
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: location.path) }
        for mode in [0o500, 0o300, 0o600] {
            try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: location.path)
            XCTAssertThrowsError(try LocalStore(root: location, createIfMissing: false))
            XCTAssertThrowsError(try opened.inventory())
            XCTAssertThrowsError(try opened.save(title: "Unavailable", startedAt: Date(), durationSeconds: 0, transcript: []))
            let permissions = try FileManager.default.attributesOfItem(atPath: location.path)[.posixPermissions] as? NSNumber
            XCTAssertEqual(permissions?.intValue, mode)
        }
    }

    func testRemovedOrReplacedRootIsNotRecreatedOrUsed() throws {
        let opened = try store()
        let saved = try opened.save(title: "Existing", startedAt: Date(), durationSeconds: 0, transcript: [])
        let preserved = temporary.appendingPathComponent("preserved")
        try FileManager.default.moveItem(at: opened.root, to: preserved)
        XCTAssertThrowsError(try opened.inventory())
        XCTAssertThrowsError(try opened.save(title: "No recreation", startedAt: Date(), durationSeconds: 0, transcript: []))
        XCTAssertThrowsError(try opened.load(saved.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: opened.root.path))
        try FileManager.default.createSymbolicLink(at: opened.root, withDestinationURL: preserved)
        XCTAssertThrowsError(try opened.inventory())
        XCTAssertThrowsError(try opened.remove(saved.id))
        try FileManager.default.removeItem(at: opened.root)
        let replacement = try LocalStore(root: opened.root)
        let other = try replacement.save(title: "Replacement", startedAt: Date(), durationSeconds: 0, transcript: [])
        XCTAssertThrowsError(try opened.inventory())
        XCTAssertThrowsError(try opened.remove(other.id))
        XCTAssertThrowsError(try opened.save(title: "Wrong library", startedAt: Date(), durationSeconds: 0, transcript: []))
        XCTAssertEqual(try replacement.inventory().sessions.map(\.id), [other.id])
        let original = try LocalStore(root: preserved, createIfMissing: false)
        XCTAssertEqual(try original.inventory().sessions.map(\.id), [saved.id])
    }

}
