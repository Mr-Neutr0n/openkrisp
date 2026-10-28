import Foundation
import Combine
import SwiftUI
import LocalStore

protocol SavedTranscriptWorking: Sendable {
    func prepare(session: Session, location: LibraryLocationSnapshot) async throws -> TranscriptionSessionSnapshot
    func save(_ draft: ImportTranscriptDraft, expected: TranscriptionSessionSnapshot, location: LibraryLocationSnapshot) async throws -> Session
}
actor SavedTranscriptWorker: SavedTranscriptWorking {
    func prepare(session: Session, location: LibraryLocationSnapshot) throws -> TranscriptionSessionSnapshot {
        let snapshot = try location.open().transcriptionSnapshot(for: session.id)
        guard snapshot.session == session else { throw StoreError.invalidSession }
        return snapshot
    }
    func save(_ draft: ImportTranscriptDraft, expected: TranscriptionSessionSnapshot, location: LibraryLocationSnapshot) throws -> Session {
        let segments = try draft.segments(duration: expected.session.durationSeconds)
        return try location.open().replaceTranscript(segments, expected: expected)
    }
}

// Recognition changes only a review draft. The explicit Save action replaces the
// manifest of the selected session, using the original source identity snapshot.
@MainActor final class SavedSessionTranscription: ObservableObject {
    let session: Session
    let transcription: ImportTranscription
    @Published var text: String { didSet { transcription.reviewTextChanged(text) } }
    @Published private(set) var preparing = false
    @Published private(set) var saving = false
    @Published private(set) var saved = false
    @Published private(set) var invalidated = false
    @Published private(set) var error: String?
    private let model: LibraryModel
    private let worker: any SavedTranscriptWorking
    private let revision: UUID
    private let selectionRevision: UUID
    private var source: TranscriptionSessionSnapshot?
    private var activity: LibraryActivity?
    private var operationID = UUID()
    private var receivedRecognition = false
    private var observations: [AnyCancellable] = []
    private var originalText: String { session.transcript.map(\.text).joined(separator: " ") }
    var current: Bool {
        !invalidated && model.location.snapshot.revision == revision &&
        model.selectionRevision == selectionRevision && model.selected == session
    }
    var busy: Bool { preparing || saving || transcription.busy }
    var canTranscribe: Bool { current && source != nil && !busy && !model.busy && !saved }
    var canSave: Bool {
        current && source != nil && !busy && !model.busy && !saved &&
        (receivedRecognition || text != originalText) && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var hasTimings: Bool { source.map { transcription.hasTimings(file: $0.recordingURL, text: text) } ?? false }
    var status: String { transcription.status.replacingOccurrences(of: "before importing.", with: "before saving.") }
    init(model: LibraryModel, session: Session, transcription: ImportTranscription? = nil,
         worker: any SavedTranscriptWorking = SavedTranscriptWorker()) {
        self.model = model; self.session = session; self.worker = worker
        self.transcription = transcription ?? ImportTranscription(location: model.location)
        revision = model.location.snapshot.revision; selectionRevision = model.selectionRevision
        text = session.transcript.map(\.text).joined(separator: " ")
        observations.append(self.transcription.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() })
        observations.append(self.transcription.$completedText.sink { [weak self] value in
            guard let self, let value, self.current, !self.saved else { return }
            self.text = value; self.receivedRecognition = true
        })
        observations.append(model.$selectionRevision.sink { [weak self] next in
            guard let self, next != self.selectionRevision else { return }; self.invalidate()
        })
        observations.append(model.location.$snapshot.sink { [weak self] next in
            guard let self, next.revision != self.revision else { return }; self.invalidate()
        })
        observations.append(model.$sessions.sink { [weak self] sessions in
            guard let self, !self.saving, !self.saved,
                  sessions.first(where: { $0.id == session.id }) != session else { return }
            self.invalidate()
        })
    }
    private func invalidate() {
        guard !saving else { return }
        invalidated = true; cancel()
        error = "The session or library changed. Close this review and select the recording again."
    }
    func prepare() async {
        guard current, source == nil, !preparing, !model.busy, !saved else { return }
        guard let activity = try? model.location.begin("Saved transcript review") else {
            error = "Finish changing the library folder before transcribing."; return
        }
        self.activity = activity
        let id = UUID(); operationID = id; preparing = true; error = nil
        defer { if operationID == id { preparing = false } }
        do {
            let source = try await worker.prepare(session: session, location: activity.location)
            guard operationID == id, current else { return }
            self.source = source
        } catch {
            guard operationID == id, current else { return }
            self.error = "Cannot open this saved recording. Its transcript is unchanged. \(error.localizedDescription)"
            releaseActivity()
        }
    }
    func start(locale: String) {
        guard canTranscribe, let source else { return }
        error = nil
        transcription.start(file: source.recordingURL, locale: locale)
    }
    func cancelRecognition() { transcription.cancel() }
    func save() async -> Bool {
        guard canSave, let source, let activity,
              model.beginTranscriptSave(session: session, revision: revision, selectionRevision: selectionRevision) else { return false }
        saving = true; error = nil
        let id = operationID
        var updated: Session?
        defer { model.finishTranscriptSave(updated); saving = false }
        do {
            let draft = transcription.draft(file: source.recordingURL, text: text)
            let result = try await worker.save(draft, expected: source, location: activity.location)
            guard operationID == id, current else { return false }
            updated = result; saved = true; releaseActivity()
            return true
        } catch {
            guard operationID == id, current else { return false }
            self.error = "Cannot save the transcript. The saved transcript is unchanged. \(error.localizedDescription)"
            return false
        }
    }
    func cancel() {
        guard !saving else { return }
        operationID = UUID(); preparing = false
        transcription.cancel(); source = nil
        releaseActivity()
    }
    private func releaseActivity() {
        if let activity { model.location.end(activity); self.activity = nil }
    }
}

struct SavedSessionTranscriptionView: View {
    @ObservedObject var model: LibraryModel
    @StateObject private var review: SavedSessionTranscription
    @Environment(\.dismiss) private var dismiss
    @State private var locale = ""
    @State private var languages: [TranscriptionLanguage] = []
    @State private var replacing = false
    init(model: LibraryModel, session: Session) {
        self.model = model
        _review = StateObject(wrappedValue: SavedSessionTranscription(model: model, session: session))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transcribe saved recording").font(.title2)
            Text(review.session.title).font(.headline)
            Picker("Transcription language", selection: $locale) {
                Text("Choose a language").tag("")
                ForEach(languages) { Text($0.name).tag($0.id) }
            }.disabled(review.busy || review.invalidated)
            HStack {
                Button("Transcribe on this Mac") {
                    if review.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { review.start(locale: locale) }
                    else { replacing = true }
                }.disabled(!review.canTranscribe || locale.isEmpty)
                if review.transcription.busy {
                    ProgressView().controlSize(.small)
                    Button("Cancel transcription") { review.cancelRecognition() }
                }
            }
            Text("Uses only this saved WAV and on-device Speech recognition. Speech permission is requested when you start. Review the result before saving. The recording stays unchanged.")
                .font(.caption).foregroundColor(.secondary)
            if !review.status.isEmpty { Text(review.status).font(.caption) }
            TextEditor(text: $review.text).frame(height: 180).border(Color.secondary.opacity(0.3))
                .disabled(review.busy || review.invalidated)
            Text(review.hasTimings ? "Word timestamps will be saved. Export lists each word on its own line." : "Edited text will use the recording-wide time range.")
                .font(.caption).foregroundColor(.secondary)
            if let error = review.error ?? review.transcription.error { Text(error).font(.caption).foregroundColor(.red) }
            HStack {
                Button("Cancel") { review.cancel(); dismiss() }.disabled(review.saving)
                Spacer()
                if review.preparing || review.saving { ProgressView().controlSize(.small) }
                Button("Save transcript") { Task { if await review.save() { dismiss() } } }.disabled(!review.canSave)
            }
        }.padding(24).frame(width: 560)
        .interactiveDismissDisabled(review.saving)
        .task { languages = TranscriptionLanguage.supported(); await review.prepare() }
        .onDisappear { review.cancel() }
        .alert("Replace review text?", isPresented: $replacing) {
            Button("Cancel", role: .cancel) { }
            Button("Transcribe and replace") { review.start(locale: locale) }
        } message: {
            Text("The current review stays until recognition succeeds. The saved transcript changes only when you choose Save transcript.")
        }
    }
}
