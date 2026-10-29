import XCTest
@testable import LocalStore

final class RecordingSourceTests: XCTestCase {
    func testProvenanceSurvivesSaveTranscriptReplacementAndLegacyLoad() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: base) }
        let store = try LocalStore(root: base.appendingPathComponent("history"))
        let wav = base.appendingPathComponent("own.wav")
        try Data("RIFF0000WAVEown fixture".utf8).write(to: wav)
        let source = RecordingSource(appName: "Own fixture", appID: "own.fixture", responsiblePID: 123,
                                     processes: [.init(objectID: 3, actualPID: 456)])
        let saved = try store.save(title: "Selected app audio", startedAt: Date(), durationSeconds: 1,
                                   transcript: [], recording: wav, recordingSource: source)
        XCTAssertEqual(try store.load(saved.id).recordingSource, source)
        let snapshot = try store.transcriptionSnapshot(for: saved.id)
        let changed = try store.replaceTranscript([.init(startSeconds: 0, endSeconds: 1, text: "Own words")], expected: snapshot)
        XCTAssertEqual(changed.recordingSource, source)
        let manifest = store.root.appendingPathComponent(saved.id.uuidString).appendingPathComponent("session.json")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
        json.removeValue(forKey: "recordingSource")
        try JSONSerialization.data(withJSONObject: json).write(to: manifest)
        XCTAssertNil(try store.load(saved.id).recordingSource)
        XCTAssertThrowsError(try store.save(title: "No audio", startedAt: Date(), durationSeconds: 0,
                                          transcript: [], recordingSource: source))
    }
    func testMicrophoneProvenanceRoundTripAndRejectsInconsistentPolicy() throws {
        let source = RecordingSource(appName: "Own", appID: "own", responsiblePID: 9,
            processes: [.init(objectID: 7, actualPID: 9)], microphoneUID: "own.mic", microphoneObjectID: 11)
        XCTAssertTrue(source.isValid)
        XCTAssertEqual(source.kind, "selected_app_output_and_microphone")
        XCTAssertEqual(try JSONDecoder().decode(RecordingSource.self, from: JSONEncoder().encode(source)), source)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
        for (key, value) in [("mixPolicy", "unknown"), ("timelinePolicy", "unknown"), ("microphoneUID", ""), ("kind", "selected_app_output")] {
            var malformed = json; malformed[key] = value
            XCTAssertFalse(try JSONDecoder().decode(RecordingSource.self, from: JSONSerialization.data(withJSONObject: malformed)).isValid)
        }
        json["microphoneObjectID"] = 0
        XCTAssertFalse(try JSONDecoder().decode(RecordingSource.self, from: JSONSerialization.data(withJSONObject: json)).isValid)
        let pending = RecordingSource(appName: "Own", appID: "own", responsiblePID: 9,
            processes: [.init(objectID: 7, actualPID: 9)], microphoneUID: "own.mic")
        XCTAssertTrue(pending.isValid)
    }
    func testInvalidAndDuplicateTargetsAreRejected() throws {
        let process = RecordingSource.Process(objectID: 7, actualPID: 9)
        XCTAssertFalse(RecordingSource(appName: "Own", appID: "own", responsiblePID: 9, processes: []).isValid)
        XCTAssertFalse(RecordingSource(appName: "Own", appID: "own", responsiblePID: 9, processes: [process, process]).isValid)
        let valid = RecordingSource(appName: "Own", appID: "own", responsiblePID: 9, processes: [process])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any])
        json["kind"] = "global_audio"
        XCTAssertFalse(try JSONDecoder().decode(RecordingSource.self, from: JSONSerialization.data(withJSONObject: json)).isValid)
    }
}
