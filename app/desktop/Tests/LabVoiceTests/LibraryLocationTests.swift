import XCTest
import Foundation
import LocalStore
import LocalTranscription
@testable import LabVoice

private actor SuspendedLibraryWorker: LibraryWorking {
    let base = LibraryWorker()
    var pending: CheckedContinuation<StoreInventory, Error>?
    var old: StoreInventory?
    var first = true
    let suspendImports: Bool
    var pendingImport: CheckedContinuation<Void, Never>?
    init(suspendImports: Bool = false) { self.suspendImports = suspendImports; if suspendImports { first = false } }
    func importSuspended() -> Bool { pendingImport != nil }
    func resumeImport() { pendingImport?.resume(); pendingImport = nil }
    func inventory(_ location: LibraryLocationSnapshot) async throws -> StoreInventory {
        if first {
            first = false; old = try location.open().inventory()
            return try await withCheckedThrowingContinuation { pending = $0 }
        }
        return try await base.inventory(location)
    }
    func suspended() -> Bool { pending != nil }
    func resume(failing: Bool) {
        if failing { pending?.resume(throwing: StoreError.io(operation: "old read", code: 13)) }
        else { pending?.resume(returning: old!) }
        pending = nil
    }
    func importWAV(_ url: URL, title: String, transcript: ImportTranscriptDraft, location: LibraryLocationSnapshot) async throws {
        if suspendImports { await withCheckedContinuation { pendingImport = $0 } }
        try await base.importWAV(url, title: title, transcript: transcript, location: location)
    }
    func remove(_ id: UUID, location: LibraryLocationSnapshot) async throws { try await base.remove(id, location: location) }
    func export(_ id: UUID, to url: URL, location: LibraryLocationSnapshot) async throws { try await base.export(id, to: url, location: location) }
    func play(_ id: UUID, location: LibraryLocationSnapshot) async throws { XCTFail("Playback must not run in location tests") }
    func stop(revision: UUID?) async { await base.stop(revision: revision) }
    func isPlaying(revision: UUID) async -> Bool { false }
}

@MainActor final class LibraryLocationTests: XCTestCase {
    private func fixture() throws -> (URL, UserDefaults, String) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let name = "LabVoice-location-fixture-" + UUID().uuidString
        return (root, try XCTUnwrap(UserDefaults(suiteName: name)), name)
    }
    private func seed(_ root: URL, title: String) throws -> Session {
        try LocalStore(root: root).save(title: title, startedAt: Date(), durationSeconds: 1,
            transcript: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: title + " transcript")])
    }
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        throw NSError(domain: "Location fixture timed out", code: 1)
    }
    func testChooseReopenImportsRecordingDestinationAndPersistenceWithoutMigration() async throws {
        let (root, prefs, domain) = try fixture()
        defer { prefs.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("A"), b = root.appendingPathComponent("B")
        let first = try seed(a, title: "A"), second = try seed(b, title: "B")
        let location = LibraryLocation(defaults: prefs, defaultRoot: a)
        let model = LibraryModel(location: location)
        let choseA = await location.choose(a); XCTAssertTrue(choseA)
        await model.load(); XCTAssertEqual(model.sessions.map(\.id), [first.id])
        let old = location.snapshot
        let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"))
        let recording = try await storage.prepare(operationID: UUID(), location: old)
        let choseB = await location.choose(b); XCTAssertTrue(choseB)
        await model.load(); try await wait { model.sessions.contains { $0.id == second.id } }
        let wav = root.appendingPathComponent("import.wav")
        try recordingFixtureWAV().write(to: wav)
        let imported = await model.importWAV(wav, title: "Imported into B", transcript: "New text", expectedRevision: location.snapshot.revision)
        XCTAssertTrue(imported)
        try recordingFixtureWAV().write(to: recording.wav)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: recording.wav.path)
        let saved = try await storage.saveCompleted(recording, path: recording.wav.path, frames: 480, sampleRate: 48000, channels: 2)
        XCTAssertEqual(try old.open().load(saved.session.id), saved.session)
        XCTAssertEqual(try old.open().load(first.id), first)
        XCTAssertEqual(try location.snapshot.open().inventory().sessions.count, 2)
        let restarted = LibraryLocation(defaults: prefs, defaultRoot: root.appendingPathComponent("unused"))
        XCTAssertEqual(restarted.snapshot.root, b.standardizedFileURL); XCTAssertFalse(restarted.snapshot.createIfMissing)
    }
    func testFailedAndInvalidSavedLocationsNeverFallBackAndAllowRecovery() async throws {
        let (root, prefs, domain) = try fixture()
        defer { prefs.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let valid = root.appendingPathComponent("valid"); _ = try seed(valid, title: "Valid")
        let location = LibraryLocation(defaults: prefs, defaultRoot: valid)
        let selected = await location.choose(valid); XCTAssertTrue(selected)
        let original = location.snapshot
        let rejected = await location.choose(root.appendingPathComponent("absent"))
        XCTAssertFalse(rejected); XCTAssertEqual(location.snapshot, original)
        XCTAssertEqual(prefs.string(forKey: LibraryLocation.preferenceKey), valid.path)
        try FileManager.default.removeItem(at: valid)
        let reopened = LibraryLocation(defaults: prefs, defaultRoot: root.appendingPathComponent("fallback"))
        let model = LibraryModel(location: reopened)
        await model.load(); XCTAssertNotNil(model.error); XCTAssertNotNil(reopened.error)
        XCTAssertFalse(FileManager.default.fileExists(atPath: valid.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("fallback").path))
        _ = try seed(valid, title: "Restored")
        await model.load(); XCTAssertNil(model.error); XCTAssertNil(reopened.error)
        for invalid: Any in [42, "", "relative"] {
            prefs.set(invalid, forKey: LibraryLocation.preferenceKey)
            let invalidLocation = LibraryLocation(defaults: prefs, defaultRoot: root.appendingPathComponent("fallback"))
            XCTAssertThrowsError(try invalidLocation.snapshot.open())
            let recovered = await invalidLocation.choose(valid); XCTAssertTrue(recovered)
        }
    }
    func testLateOldInventoryOrFailureCannotReplaceNewLibrary() async throws {
        for failing in [false, true] {
            let (root, prefs, domain) = try fixture()
            defer { prefs.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
            let a = root.appendingPathComponent("A"), b = root.appendingPathComponent("B")
            _ = try seed(a, title: "A"); let second = try seed(b, title: "B")
            let location = LibraryLocation(defaults: prefs, defaultRoot: a), worker = SuspendedLibraryWorker()
            let model = LibraryModel(location: location, worker: worker)
            let loading = Task { await model.load() }
            for _ in 0..<1000 { if await worker.suspended() { break }; try await Task.sleep(nanoseconds: 1_000_000) }
            let changed = await location.choose(b); XCTAssertTrue(changed)
            await worker.resume(failing: failing); await loading.value
            XCTAssertFalse(model.sessions.contains { $0.title == "A" })
            try await wait { model.sessions.map(\.id) == [second.id] }
            XCTAssertNil(model.error); XCTAssertNil(location.error)
        }
    }
    func testStaleDialogActionsCannotDeleteExportOrImportIntoNewLibraryCopy() async throws {
        let (root, prefs, domain) = try fixture()
        defer { prefs.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("A"), b = root.appendingPathComponent("B")
        let session = try seed(a, title: "Same ID")
        try FileManager.default.copyItem(at: a, to: b)
        let location = LibraryLocation(defaults: prefs, defaultRoot: a)
        let scoped = LibraryModel(location: location)
        let old = location.snapshot.revision
        let chosen = await location.choose(b); XCTAssertTrue(chosen)
        await scoped.delete(session.id, expectedRevision: old)
        let exported = root.appendingPathComponent("wrong.txt")
        await scoped.export(session.id, to: exported, expectedRevision: old)
        let imported = await scoped.importWAV(root.appendingPathComponent("unused.wav"), title: "Wrong", transcript: "", expectedRevision: old)
        XCTAssertFalse(imported); XCTAssertFalse(FileManager.default.fileExists(atPath: exported.path))
        XCTAssertEqual(try location.snapshot.open().load(session.id), session)
    }
    func testRecordingRejectsMissingDestinationBeforeStartAndRejectsReplacementAtSave() async throws {
        let (root, prefs, domain) = try fixture()
        defer { prefs.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("library"); _ = try seed(destination, title: "Original")
        let location = LibraryLocation(defaults: prefs, defaultRoot: destination)
        let chosen = await location.choose(destination); XCTAssertTrue(chosen)
        let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"))
        let job = try await storage.prepare(operationID: UUID(), location: location.snapshot)
        try FileManager.default.moveItem(at: destination, to: root.appendingPathComponent("renamed"))
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        try recordingFixtureWAV().write(to: job.wav)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: job.wav.path)
        do { _ = try await storage.saveCompleted(job, path: job.wav.path, frames: 480, sampleRate: 48000, channels: 2); XCTFail("Saved into replacement root") } catch { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: destination.path).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: job.wav.path))
        try FileManager.default.removeItem(at: destination)
        let recorder = RecordingController(storage: storage, location: location)
        var commands = 0
        recorder.attach(operationID: UUID()) { _ in commands += 1 }
        recorder.start(); try await wait { recorder.error != nil }
        XCTAssertEqual(commands, 0); XCTAssertTrue(location.activities.isEmpty)
    }
    func testActivityAndCaptureLocksKeepPreferenceAndLeaseIdentity() async throws {
        let (root, prefs, domain) = try fixture()
        defer { prefs.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("A"), b = root.appendingPathComponent("B")
        _ = try seed(a, title: "A"); _ = try seed(b, title: "B")
        let location = LibraryLocation(defaults: prefs, defaultRoot: a)
        let old = try location.begin("Old transcription")
        let blocked = await location.choose(b); XCTAssertFalse(blocked)
        location.end(old)
        let newer = try location.begin("New transcription")
        location.end(old); XCTAssertFalse(location.canSwitch)
        location.end(newer)
        let capture = UUID(); XCTAssertTrue(AudioCaptureAdmission.shared.acquire(capture, owner: .microphoneTest))
        let captured = await location.choose(b); XCTAssertFalse(captured)
        AudioCaptureAdmission.shared.release(capture)
        let accepted = await location.choose(b); XCTAssertTrue(accepted)
    }
    func testActualImportPinsRootAndBlocksSwitchUntilSaved() async throws {
        let (root, prefs, domain) = try fixture()
        defer { prefs.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("A"), b = root.appendingPathComponent("B")
        _ = try seed(a, title: "A"); _ = try seed(b, title: "B")
        let location = LibraryLocation(defaults: prefs, defaultRoot: a), worker = SuspendedLibraryWorker(suspendImports: true)
        let model = LibraryModel(location: location, worker: worker)
        let wav = root.appendingPathComponent("source.wav"); try recordingFixtureWAV().write(to: wav)
        let importing = Task { await model.importWAV(wav, title: "Pinned import", transcript: "Pinned text") }
        for _ in 0..<1000 { if await worker.importSuspended() { break }; try await Task.sleep(nanoseconds: 1_000_000) }
        let changed = await location.choose(b); XCTAssertFalse(changed)
        await worker.resumeImport()
        let saved = await importing.value; XCTAssertTrue(saved)
        XCTAssertTrue(try LocalStore(root: a, createIfMissing: false).inventory().sessions.contains { $0.title == "Pinned import" })
        XCTAssertFalse(try LocalStore(root: b, createIfMissing: false).inventory().sessions.contains { $0.title == "Pinned import" })
        XCTAssertTrue(location.activities.isEmpty)
    }
    func testCancelledPermissionLeaseCannotBlockOrReleaseNewTranscription() async throws {
        let (root, prefs, domain) = try fixture()
        defer { prefs.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("A"), b = root.appendingPathComponent("B")
        _ = try seed(a, title: "A"); _ = try seed(b, title: "B")
        let location = LibraryLocation(defaults: prefs, defaultRoot: a)
        let wav = root.appendingPathComponent("source.wav"); try recordingFixtureWAV(frames: 480, channels: 1).write(to: wav)
        var old: CheckedContinuation<SpeechAuthorization, Never>?, new: CheckedContinuation<SpeechAuthorization, Never>?, requests = 0, recognitions = 0
        let transcription = ImportTranscription(authorization: { .notDetermined }, requestAuthorization: {
            requests += 1
            return await withCheckedContinuation { if requests == 1 { old = $0 } else { new = $0 } }
        }, recognize: { _, _ in recognitions += 1; throw TranscriptionFailure.recognizerUnavailable }, cancelRecognition: {}, location: location)
        transcription.start(file: wav, locale: "en-US"); try await wait { old != nil }
        transcription.cancel(); XCTAssertTrue(location.canSwitch)
        let selected = await location.choose(b); XCTAssertTrue(selected)
        transcription.start(file: wav, locale: "en-US"); try await wait { new != nil }
        old?.resume(returning: .authorized)
        try await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertEqual(recognitions, 0); XCTAssertEqual(location.activities.count, 1); XCTAssertFalse(location.canSwitch)
        new?.resume(returning: .denied)
        try await wait { !transcription.busy }
        XCTAssertTrue(location.activities.isEmpty)
    }

}
