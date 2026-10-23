import XCTest
import Foundation
import LocalStore
import LocalTranscription
@testable import LabVoice

@MainActor final class TranscriptImportTimingTests: XCTestCase {
    private func ready(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Expected import transition did not arrive")
    }
    func testPreservesTimingsThroughRecognitionControllerAndRealLibraryImport() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let domain = "LabVoice-timed-import-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let library = root.appendingPathComponent("library")
        _ = try LocalStore(root: library)
        let location = LibraryLocation(defaults: defaults, defaultRoot: library)
        let file = root.appendingPathComponent("selected.wav")
        try recordingFixtureWAV(frames: 96000).write(to: file)
        let recognized = OfflineTranscript(text: "Hello world.", localeIdentifier: "en_US", segments: [
            RecognizedSegment(text: "Hello", startSeconds: 0.25, durationSeconds: 0.2, confidence: 0.9),
            RecognizedSegment(text: "world", startSeconds: 0.9, durationSeconds: 0.3, confidence: 0.8)
        ])
        let flow = ImportTranscription(authorization: { .authorized }, requestAuthorization: { XCTFail("No prompt expected"); return .authorized }, recognize: { _, _ in recognized }, cancelRecognition: {}, location: location)
        flow.start(file: file, locale: "en_US")
        try await ready { !flow.busy }
        let model = LibraryModel(location: location)
        let imported = await model.importWAV(file, title: "Timed recognition", transcript: flow.draft(file: file, text: try XCTUnwrap(flow.completedText)), expectedRevision: location.snapshot.revision)
        XCTAssertTrue(imported)
        let saved = try XCTUnwrap(model.sessions.first)
        model.query = "hello world"
        XCTAssertEqual(model.filtered.map(\.id), [saved.id])
        XCTAssertEqual(saved.transcript, [TranscriptSegment(startSeconds: 0.25, endSeconds: 0.45, text: "Hello"), TranscriptSegment(startSeconds: 0.9, endSeconds: 1.2, text: "world")])
        let exported = root.appendingPathComponent("transcript.txt")
        await model.export(saved.id, to: exported, expectedRevision: location.snapshot.revision)
        XCTAssertEqual(try String(contentsOf: exported, encoding: .utf8), "Timed recognition\n\n[0.250s] Hello\n[0.900s] world\n")
    }
    private func withFixture(_ body: @MainActor (URL, LibraryLocation, URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let domain = "LabVoice-timed-import-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let library = root.appendingPathComponent("library")
        _ = try LocalStore(root: library)
        let location = LibraryLocation(defaults: defaults, defaultRoot: library)
        let file = root.appendingPathComponent("selected.wav")
        try recordingFixtureWAV(frames: 96000).write(to: file)
        try await body(root, location, file)
    }
    private var recognized: OfflineTranscript {
        OfflineTranscript(text: "Hello world.", localeIdentifier: "en_US", segments: [
            RecognizedSegment(text: "Hello", startSeconds: 0.25, durationSeconds: 0.2, confidence: 0.9),
            RecognizedSegment(text: "world", startSeconds: 0.9, durationSeconds: 0.3, confidence: 0.8)
        ])
    }
    private func flow(_ location: LibraryLocation, result: OfflineTranscript) -> ImportTranscription {
        ImportTranscription(authorization: { .authorized }, requestAuthorization: { XCTFail("No prompt expected"); return .authorized }, recognize: { _, _ in result }, cancelRecognition: {}, location: location)
    }
    func testEditedTextInvalidatesTimingsEvenAfterRevertingAndManualImportStillWorks() async throws {
        try await withFixture { _, location, file in
            let flow = self.flow(location, result: self.recognized)
            flow.start(file: file, locale: "en_US"); try await self.ready { !flow.busy }
            XCTAssertTrue(flow.hasTimings(file: file, text: self.recognized.text))
            // Exact comparison: a trailing space is an edit despite trim equality.
            flow.reviewTextChanged(self.recognized.text + " ")
            flow.reviewTextChanged(self.recognized.text)
            XCTAssertFalse(flow.hasTimings(file: file, text: self.recognized.text))
            let model = LibraryModel(location: location)
            let imported = await model.importWAV(file, title: "Edited", transcript: flow.draft(file: file, text: self.recognized.text))
            XCTAssertTrue(imported)
            XCTAssertEqual(model.sessions.first?.transcript, [TranscriptSegment(startSeconds: 0, endSeconds: 2, text: self.recognized.text)])
            let manual = await model.importWAV(file, title: "Manual", transcript: "  Manual text  ")
            XCTAssertTrue(manual)
            XCTAssertEqual(model.sessions.first(where: { $0.title == "Manual" })?.transcript, [TranscriptSegment(startSeconds: 0, endSeconds: 2, text: "Manual text")])
        }
    }
    func testRecognitionWithoutSegmentsUsesPlainTextFallback() async throws {
        try await withFixture { _, location, file in
            let result = OfflineTranscript(text: "Recognized without timings", localeIdentifier: "en_US", segments: [])
            let flow = self.flow(location, result: result)
            flow.start(file: file, locale: "en_US"); try await self.ready { !flow.busy }
            XCTAssertFalse(flow.hasTimings(file: file, text: result.text))
            let model = LibraryModel(location: location)
            let imported = await model.importWAV(file, title: "Untimed", transcript: flow.draft(file: file, text: result.text))
            XCTAssertTrue(imported)
            XCTAssertEqual(model.sessions.first?.transcript, [TranscriptSegment(startSeconds: 0, endSeconds: 2, text: result.text)])
        }
    }
    func testInvalidRecognitionNeverReplacesCandidateAndOutOfBoundsImportPublishesNothing() async throws {
        try await withFixture { _, location, file in
            let invalid: [RecognizedSegment] = [
                .init(text: "Bad", startSeconds: .nan, durationSeconds: 0.1, confidence: 1),
                .init(text: "Bad", startSeconds: -1, durationSeconds: 0.1, confidence: 1),
                .init(text: "Bad", startSeconds: 0, durationSeconds: -1, confidence: 1),
                .init(text: "Bad", startSeconds: .greatestFiniteMagnitude, durationSeconds: .greatestFiniteMagnitude, confidence: 1),
                .init(text: "Bad", startSeconds: 0, durationSeconds: 0.1, confidence: .nan)
            ]
            for segment in invalid {
                let result = OfflineTranscript(text: "Invalid", localeIdentifier: "en_US", segments: [segment])
                let flow = self.flow(location, result: result)
                flow.start(file: file, locale: "en_US"); try await self.ready { !flow.busy }
                XCTAssertNil(flow.completedText); XCTAssertNotNil(flow.error)
            }
            let result = OfflineTranscript(text: "Beyond file", localeIdentifier: "en_US", segments: [.init(text: "Beyond", startSeconds: 1.9, durationSeconds: 0.2, confidence: 1)])
            let flow = self.flow(location, result: result)
            flow.start(file: file, locale: "en_US"); try await self.ready { !flow.busy }
            XCTAssertEqual(flow.completedText, result.text) // Duration is checked at actual import.
            let model = LibraryModel(location: location)
            let imported = await model.importWAV(file, title: "Invalid timing", transcript: flow.draft(file: file, text: result.text))
            XCTAssertFalse(imported); XCTAssertNotNil(model.error)
            let inventory = try location.snapshot.open().inventory()
            XCTAssertTrue(inventory.sessions.isEmpty); XCTAssertTrue(inventory.pendingEntries.isEmpty)
        }
    }
    func testZeroDurationAndOriginalSegmentOrderArePreservedWithoutInventedSpeakers() async throws {
        try await withFixture { _, location, file in
            let result = OfflineTranscript(text: "Original formatting.", localeIdentifier: "en_US", segments: [
                .init(text: "later", startSeconds: 1, durationSeconds: 0, confidence: 1),
                .init(text: "earlier", startSeconds: 0.25, durationSeconds: 0.2, confidence: 1)
            ])
            let flow = self.flow(location, result: result)
            flow.start(file: file, locale: "en_US"); try await self.ready { !flow.busy }
            let model = LibraryModel(location: location)
            let imported = await model.importWAV(file, title: "Original order", transcript: flow.draft(file: file, text: result.text))
            XCTAssertTrue(imported)
            XCTAssertEqual(model.sessions.first?.transcript, [.init(startSeconds: 1, endSeconds: 1, text: "later"), .init(startSeconds: 0.25, endSeconds: 0.45, text: "earlier")])
            XCTAssertTrue(model.sessions.first?.transcript.allSatisfy { $0.speaker == nil } == true)
        }
    }
    func testFailedAndCancelledReplacementKeepCandidateButNewFileAndLateResultDoNot() async throws {
        try await withFixture { root, location, file in
            var attempt = 0
            var pending: CheckedContinuation<OfflineTranscript, Error>?
            let flow = ImportTranscription(authorization: { .authorized }, requestAuthorization: { .authorized }, recognize: { _, _ in
                attempt += 1
                if attempt == 1 { return self.recognized }
                if attempt == 2 { throw TranscriptionFailure.invalidResult }
                return try await withCheckedThrowingContinuation { pending = $0 }
            }, cancelRecognition: {}, location: location)
            flow.start(file: file, locale: "en_US"); try await self.ready { !flow.busy }
            flow.start(file: file, locale: "en_US"); try await self.ready { !flow.busy }
            XCTAssertNotNil(flow.error); XCTAssertNil(flow.completedText)
            XCTAssertTrue(flow.hasTimings(file: file, text: self.recognized.text))
            flow.start(file: file, locale: "en_US"); try await self.ready { pending != nil }
            flow.cancel()
            XCTAssertTrue(flow.hasTimings(file: file, text: self.recognized.text))
            flow.fileDidChange()
            XCTAssertFalse(flow.hasTimings(file: file, text: self.recognized.text))
            let other = root.appendingPathComponent("other.wav")
            try recordingFixtureWAV(frames: 96000).write(to: other)
            XCTAssertFalse(flow.hasTimings(file: other, text: self.recognized.text))
            pending?.resume(returning: self.recognized); pending = nil
            try await Task.sleep(nanoseconds: 5_000_000)
            XCTAssertNil(flow.completedText)
            XCTAssertFalse(flow.hasTimings(file: other, text: self.recognized.text))
        }
    }
    func testStaleLibraryRevisionRejectsTimedImport() async throws {
        try await withFixture { root, location, file in
            let flow = self.flow(location, result: self.recognized)
            flow.start(file: file, locale: "en_US"); try await self.ready { !flow.busy }
            let old = location.snapshot
            let other = root.appendingPathComponent("other-library")
            _ = try LocalStore(root: other)
            let chosen = await location.choose(other); XCTAssertTrue(chosen)
            let model = LibraryModel(location: location)
            let imported = await model.importWAV(file, title: "Stale", transcript: flow.draft(file: file, text: self.recognized.text), expectedRevision: old.revision)
            XCTAssertFalse(imported)
            XCTAssertTrue(try old.open().inventory().sessions.isEmpty)
            XCTAssertTrue(try location.snapshot.open().inventory().sessions.isEmpty)
        }
    }

}
