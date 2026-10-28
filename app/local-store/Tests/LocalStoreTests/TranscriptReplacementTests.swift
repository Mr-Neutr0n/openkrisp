import XCTest
@testable import LocalStore

final class TranscriptReplacementTests: XCTestCase {
    private func fixture() throws -> (LocalStore, Session, URL) {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }
        let audio = base.appendingPathComponent("source.wav")
        try Data("RIFF0000WAVEown fixture".utf8).write(to: audio)
        let store = try LocalStore(root: base.appendingPathComponent("sessions"))
        let session = try store.save(title: "Keep title", startedAt: Date(timeIntervalSince1970: 1_234), durationSeconds: 10,
                                    transcript: [.init(startSeconds: 0, endSeconds: 1, text: "prior")], recording: audio)
        return (store, session, base)
    }
    func testReplaceKeepsSessionAndAudioAndUpdatesSearchExport() throws {
        let (store, prior, base) = try fixture()
        let snapshot = try store.transcriptionSnapshot(for: prior.id)
        let audio = try Data(contentsOf: snapshot.recordingURL)
        let changed = try store.replaceTranscript([.init(startSeconds: 1.25, endSeconds: 2.5, text: "reviewed words")], expected: snapshot)
        XCTAssertEqual(changed.id, prior.id); XCTAssertEqual(changed.title, prior.title)
        XCTAssertEqual(changed.startedAt, prior.startedAt); XCTAssertEqual(changed.durationSeconds, prior.durationSeconds)
        XCTAssertEqual(changed.recordingFilename, prior.recordingFilename)
        XCTAssertEqual(try Data(contentsOf: snapshot.recordingURL), audio)
        XCTAssertEqual(try store.inventory().sessions, [changed])
        XCTAssertEqual(try store.search("reviewed").map(\.id), [prior.id])
        let output = base.appendingPathComponent("export.txt")
        try store.exportTranscript(prior.id, to: output)
        XCTAssertTrue(try String(contentsOf: output, encoding: .utf8).contains("[1.250s] reviewed words"))
        let folder = store.root.appendingPathComponent(prior.id.uuidString)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: folder.path)), ["recording.wav", "session.json"])
        let permissions = try FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent("session.json").path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
    }
    func testStaleReviewCannotReplaceNewTranscript() throws {
        let (store, session, _) = try fixture()
        let snapshot = try store.transcriptionSnapshot(for: session.id)
        let first = try store.replaceTranscript([.init(startSeconds: 0, endSeconds: 2, text: "first")], expected: snapshot)
        XCTAssertThrowsError(try store.replaceTranscript([], expected: snapshot))
        XCTAssertEqual(try store.load(session.id), first)
    }
    func testRecordingMutationAndIdenticalManifestReplacementReject() throws {
        for audioChange in [true, false] {
            let (store, session, _) = try fixture()
            let snapshot = try store.transcriptionSnapshot(for: session.id)
            let manifest = store.root.appendingPathComponent(session.id.uuidString).appendingPathComponent("session.json")
            if audioChange {
                let handle = try FileHandle(forWritingTo: snapshot.recordingURL)
                try handle.seek(toOffset: 12); try handle.write(contentsOf: Data("new fixture".utf8)); try handle.close()
            } else { try Data(contentsOf: manifest).write(to: manifest, options: .atomic) }
            XCTAssertThrowsError(try store.replaceTranscript([], expected: snapshot))
            XCTAssertEqual(try store.load(session.id), session)
        }
    }
    func testReplacementDirectoryAndDifferentLibraryReject() throws {
        let (store, session, base) = try fixture()
        let snapshot = try store.transcriptionSnapshot(for: session.id)
        let folder = store.root.appendingPathComponent(session.id.uuidString)
        let old = base.appendingPathComponent("old")
        try FileManager.default.moveItem(at: folder, to: old)
        try FileManager.default.copyItem(at: old, to: folder)
        XCTAssertThrowsError(try store.replaceTranscript([], expected: snapshot))
        let other = try LocalStore(root: base.appendingPathComponent("other"))
        XCTAssertThrowsError(try other.replaceTranscript([], expected: snapshot))
        XCTAssertEqual(try store.load(session.id), session)
    }
    func testInvalidSegmentsAndMissingSessionPreservePrior() throws {
        let (store, session, _) = try fixture()
        let snapshot = try store.transcriptionSnapshot(for: session.id)
        for segment in [TranscriptSegment(startSeconds: -1, endSeconds: 2, text: "bad"),
                        .init(startSeconds: 0, endSeconds: 11, text: "bad"),
                        .init(startSeconds: .nan, endSeconds: 1, text: "bad")] {
            XCTAssertThrowsError(try store.replaceTranscript([segment], expected: snapshot))
            XCTAssertEqual(try store.load(session.id), session)
        }
        try store.remove(session.id)
        XCTAssertThrowsError(try store.replaceTranscript([], expected: snapshot))
    }
    func testConcurrentStoresAdmitOnlyOneExpectedRevision() async throws {
        let (store, session, _) = try fixture()
        let snapshot = try store.transcriptionSnapshot(for: session.id)
        let secondStore = try LocalStore(root: store.root, createIfMissing: false)
        let outcomes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for (index, selected) in [store, secondStore].enumerated() {
                group.addTask {
                    do { _ = try selected.replaceTranscript([.init(startSeconds: 0, endSeconds: 1, text: "writer \(index)")], expected: snapshot); return true }
                    catch { return false }
                }
            }
            var values: [Bool] = []
            for await result in group { values.append(result) }
            return values
        }
        XCTAssertEqual(outcomes.filter { $0 }.count, 1)
        XCTAssertEqual(try store.inventory().sessions.count, 1)
    }
}
