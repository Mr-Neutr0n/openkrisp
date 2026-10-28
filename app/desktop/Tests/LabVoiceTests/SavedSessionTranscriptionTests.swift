import XCTest
import Foundation
import LocalStore
import LocalTranscription
@testable import LabVoice

@MainActor final class SavedSessionTranscriptionTests: XCTestCase {
    private func ready(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Fixture did not progress")
    }
    private var result: OfflineTranscript {
        .init(text: "Hello world.", localeIdentifier: "en_US", segments: [
            .init(text: "Hello", startSeconds: 0.25, durationSeconds: 0.2, confidence: 0.9),
            .init(text: "world", startSeconds: 0.9, durationSeconds: 0.3, confidence: 0.8)])
    }
    private func fixture(_ body: (URL, LibraryLocation, LibraryModel, Session) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let domain = UUID().uuidString, defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let library = root.appendingPathComponent("sessions")
        _ = try LocalStore(root: library)
        let location = LibraryLocation(defaults: defaults, defaultRoot: library)
        let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"))
        let job = try await storage.prepare(operationID: UUID(), location: location.snapshot)
        try recordingFixtureWAV(frames: 96000).write(to: job.wav)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: job.wav.path)
        let saved = try await storage.saveCompleted(job, path: job.wav.path, frames: 96000, sampleRate: 48000, channels: 2)
        let model = LibraryModel(location: location); await model.load(); model.selection = saved.session.id
        try await body(root, location, model, saved.session)
    }
    private func flow(_ location: LibraryLocation, recognize: @escaping (UserSelectedWAV, String) async throws -> OfflineTranscript) -> ImportTranscription {
        .init(authorization: { .authorized }, requestAuthorization: { XCTFail("No OS prompt"); return .authorized }, recognize: recognize, cancelRecognition: {}, location: location)
    }
    func testRecordedHistoryRecognizesReviewsAndSavesSameSessionWithTimedSearchAndExport() async throws {
        try await fixture { root, location, model, original in
            let store = try location.snapshot.open(), audio = try XCTUnwrap(store.recordingURL(for: original.id))
            let bytes = try Data(contentsOf: audio), attributes = try FileManager.default.attributesOfItem(atPath: audio.path)
            let flow = self.flow(location) { file, locale in XCTAssertEqual(file.url, audio); XCTAssertEqual(locale, "en_US"); return self.result }
            let review = SavedSessionTranscription(model: model, session: original, transcription: flow)
            await review.prepare(); XCTAssertTrue(review.canTranscribe)
            XCTAssertFalse(location.canSwitch); XCTAssertFalse(review.canSave)
            review.start(locale: "en_US"); try await self.ready { !flow.busy }
            XCTAssertEqual(review.text, self.result.text); XCTAssertTrue(review.hasTimings)
            XCTAssertEqual(try store.load(original.id), original) // Recognition never writes history.
            let saved = await review.save(); XCTAssertTrue(saved)
            let updated = try store.load(original.id)
            XCTAssertEqual(updated.id, original.id); XCTAssertEqual(updated.title, original.title)
            XCTAssertEqual(updated.startedAt, original.startedAt); XCTAssertEqual(updated.durationSeconds, original.durationSeconds)
            XCTAssertEqual(updated.recordingFilename, original.recordingFilename)
            XCTAssertEqual(updated.transcript, [.init(startSeconds: 0.25, endSeconds: 0.45, text: "Hello"), .init(startSeconds: 0.9, endSeconds: 1.2, text: "world")])
            XCTAssertEqual(try Data(contentsOf: audio), bytes)
            let after = try FileManager.default.attributesOfItem(atPath: audio.path)
            XCTAssertEqual(after[.modificationDate] as? Date, attributes[.modificationDate] as? Date)
            XCTAssertEqual(after[.systemFileNumber] as? NSNumber, attributes[.systemFileNumber] as? NSNumber)
            XCTAssertEqual(try store.inventory().sessions.count, 1)
            model.query = "hello world"; XCTAssertEqual(model.filtered.map(\.id), [original.id])
            let export = root.appendingPathComponent("transcript.txt")
            await model.export(original.id, to: export, expectedRevision: location.snapshot.revision)
            XCTAssertEqual(try String(contentsOf: export), original.title + "\n\n[0.250s] Hello\n[0.900s] world\n")
            XCTAssertTrue(location.canSwitch)
        }
    }
    func testFailedCancelledAndLateRecognitionPreserveSavedTranscriptAndPreviousReview() async throws {
        try await fixture { _, location, model, original in
            let store = try location.snapshot.open(), snapshot = try store.transcriptionSnapshot(for: original.id)
            let existing = try store.replaceTranscript([.init(startSeconds: 0, endSeconds: 2, text: "Saved text")], expected: snapshot)
            await model.load()
            var attempt = 0, pending: CheckedContinuation<OfflineTranscript, Error>?
            let flow = self.flow(location) { _, _ in
                attempt += 1
                if attempt == 1 { return self.result }
                if attempt == 2 { throw TranscriptionFailure.recognizerUnavailable }
                return try await withCheckedThrowingContinuation { pending = $0 }
            }
            let review = SavedSessionTranscription(model: model, session: existing, transcription: flow)
            await review.prepare(); review.start(locale: "en_US"); try await self.ready { !flow.busy }
            review.start(locale: "en_US"); try await self.ready { !flow.busy }
            XCTAssertEqual(review.text, self.result.text); XCTAssertTrue(review.hasTimings)
            review.start(locale: "en_US"); try await self.ready { pending != nil }
            review.cancelRecognition(); XCTAssertEqual(review.text, self.result.text)
            pending?.resume(returning: .init(text: "Late text", localeIdentifier: "en_US", segments: []))
            await Task.yield()
            XCTAssertEqual(review.text, self.result.text); XCTAssertEqual(try store.load(original.id), existing)
            review.cancel(); XCTAssertEqual(try store.load(original.id), existing); XCTAssertFalse(review.canSave)
            XCTAssertTrue(location.canSwitch)
        }
    }
    func testEditedReviewLosesWordTimingsAndInvalidDurationNeverChangesSavedTranscript() async throws {
        try await fixture { _, location, model, original in
            let flow = self.flow(location) { _, _ in self.result }
            let review = SavedSessionTranscription(model: model, session: original, transcription: flow)
            await review.prepare(); review.start(locale: "en_US"); try await self.ready { !flow.busy }
            review.text += " Edited"; review.text = self.result.text
            XCTAssertFalse(review.hasTimings)
            let saved = await review.save(); XCTAssertTrue(saved)
            let updated = try location.snapshot.open().load(original.id)
            XCTAssertEqual(updated.transcript, [.init(startSeconds: 0, endSeconds: 2, text: self.result.text)])
            let invalid = self.flow(location) { _, _ in .init(text: "Beyond recording", localeIdentifier: "en_US", segments: [.init(text: "Beyond", startSeconds: 1.9, durationSeconds: 0.2, confidence: 1)]) }
            let invalidReview = SavedSessionTranscription(model: model, session: updated, transcription: invalid)
            await invalidReview.prepare(); invalidReview.start(locale: "en_US"); try await self.ready { !invalid.busy }
            let rejected = await invalidReview.save(); XCTAssertFalse(rejected); XCTAssertNotNil(invalidReview.error)
            XCTAssertEqual(try location.snapshot.open().load(original.id), updated)
            invalidReview.cancel()
        }
    }
    func testSelectionAwayAndBackRejectsLateRecognition() async throws {
        try await fixture { _, location, model, original in
            var pending: CheckedContinuation<OfflineTranscript, Error>?
            let flow = self.flow(location) { _, _ in try await withCheckedThrowingContinuation { pending = $0 } }
            let review = SavedSessionTranscription(model: model, session: original, transcription: flow)
            await review.prepare(); review.start(locale: "en_US"); try await self.ready { pending != nil }
            model.selection = nil; model.selection = original.id
            XCTAssertTrue(review.invalidated); XCTAssertFalse(review.canSave); XCTAssertFalse(review.canTranscribe)
            pending?.resume(returning: self.result); await Task.yield()
            XCTAssertEqual(review.text, ""); XCTAssertEqual(try location.snapshot.open().load(original.id), original)
        }
    }
    func testChangedRecordingOrManifestRejectsReviewedSave() async throws {
        try await fixture { _, location, model, original in
            let store = try location.snapshot.open(), audio = try XCTUnwrap(store.recordingURL(for: original.id))
            let flow = self.flow(location) { _, _ in self.result }
            let review = SavedSessionTranscription(model: model, session: original, transcription: flow)
            await review.prepare(); review.start(locale: "en_US"); try await self.ready { !flow.busy }
            var changed = try Data(contentsOf: audio); changed[changed.count - 1] ^= 1; try changed.write(to: audio)
            let rejected = await review.save(); XCTAssertFalse(rejected); XCTAssertNotNil(review.error)
            XCTAssertEqual(try store.load(original.id), original)
            review.cancel()
        }
    }
    func testStaleManifestAtOpenOrSaveNeverOverwritesNewerSavedText() async throws {
        for changeBeforeOpen in [true, false] {
            try await fixture { _, location, model, original in
                let store = try location.snapshot.open()
                let flow = self.flow(location) { _, _ in self.result }
                let review = SavedSessionTranscription(model: model, session: original, transcription: flow)
                if !changeBeforeOpen { await review.prepare() }
                let expected = try store.transcriptionSnapshot(for: original.id)
                let newer = try store.replaceTranscript([.init(startSeconds: 0, endSeconds: 2, text: "Newer saved text")], expected: expected)
                if changeBeforeOpen {
                    await review.prepare(); XCTAssertFalse(review.canTranscribe); XCTAssertNotNil(review.error)
                } else {
                    review.start(locale: "en_US"); try await self.ready { !flow.busy }
                    let saved = await review.save(); XCTAssertFalse(saved); XCTAssertNotNil(review.error)
                }
                XCTAssertEqual(try store.load(original.id), newer)
                review.cancel()
            }
        }
    }
    func testPreparationCancellationFencesLateOldLibraryAndSaveLocksSelection() async throws {
        try await fixture { root, location, model, original in
            let worker = PausingSavedTranscriptWorker()
            worker.pausePrepare = true
            let flow = self.flow(location) { _, _ in self.result }
            let review = SavedSessionTranscription(model: model, session: original, transcription: flow, worker: worker)
            let preparation = Task { await review.prepare() }; try await self.ready { worker.prepareGate != nil }
            review.cancel()
            let other = root.appendingPathComponent("other"); _ = try LocalStore(root: other)
            let changed = await location.choose(other); XCTAssertTrue(changed)
            worker.prepareGate?.resume(); await preparation.value
            XCTAssertTrue(review.invalidated); XCTAssertFalse(review.canTranscribe)
        }
        try await fixture { _, location, model, original in
            let worker = PausingSavedTranscriptWorker(); worker.pauseSave = true
            let flow = self.flow(location) { _, _ in self.result }
            let review = SavedSessionTranscription(model: model, session: original, transcription: flow, worker: worker)
            await review.prepare(); review.start(locale: "en_US"); try await self.ready { !flow.busy }
            let saving = Task { await review.save() }; try await self.ready { worker.saveGate != nil }
            XCTAssertTrue(model.busy); XCTAssertFalse(location.canSwitch)
            model.selection = nil; XCTAssertEqual(model.selection, original.id)
            review.cancel(); XCTAssertTrue(review.saving)
            worker.saveGate?.resume(); let saved = await saving.value; XCTAssertTrue(saved)
            XCTAssertFalse(model.busy); XCTAssertTrue(location.canSwitch)
        }
    }
}

@MainActor private final class PausingSavedTranscriptWorker: SavedTranscriptWorking {
    var pausePrepare = false, pauseSave = false
    var prepareGate: CheckedContinuation<Void, Never>?, saveGate: CheckedContinuation<Void, Never>?
    private let worker = SavedTranscriptWorker()
    func prepare(session: Session, location: LibraryLocationSnapshot) async throws -> TranscriptionSessionSnapshot {
        if pausePrepare { await withCheckedContinuation { prepareGate = $0 } }
        return try await worker.prepare(session: session, location: location)
    }
    func save(_ draft: ImportTranscriptDraft, expected: TranscriptionSessionSnapshot, location: LibraryLocationSnapshot) async throws -> Session {
        if pauseSave { await withCheckedContinuation { saveGate = $0 } }
        return try await worker.save(draft, expected: expected, location: location)
    }
}
