import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import LocalStore
import ModelCatalog
import Combine

protocol LibraryWorking: Sendable {
    func inventory(_ location: LibraryLocationSnapshot) async throws -> StoreInventory
    func importWAV(_ url: URL, title: String, transcript: ImportTranscriptDraft, location: LibraryLocationSnapshot) async throws
    func remove(_ id: UUID, location: LibraryLocationSnapshot) async throws
    func export(_ id: UUID, to url: URL, location: LibraryLocationSnapshot) async throws
    func play(_ id: UUID, location: LibraryLocationSnapshot) async throws
    func play(_ id: UUID, location: LibraryLocationSnapshot, powerRevision: UUID) async throws
    func stop(revision: UUID?) async
    func isPlaying(revision: UUID) async -> Bool
}
extension LibraryWorking {
    func play(_ id: UUID, location: LibraryLocationSnapshot, powerRevision: UUID) async throws {
        guard PowerAdmission.shared.allowed, PowerAdmission.shared.revision == powerRevision else { return }
        try await play(id, location: location)
    }
}
actor LibraryWorker: LibraryWorking {
    private var player: AVAudioPlayer?
    private var playerRevision: UUID?
    func inventory(_ location: LibraryLocationSnapshot) throws -> StoreInventory { try location.open().inventory() }
    func importWAV(_ url: URL, title: String, transcript: ImportTranscriptDraft, location: LibraryLocationSnapshot) throws {
        let file = try AVAudioFile(forReading: url)
        let rate = file.processingFormat.sampleRate
        guard rate.isFinite, rate > 0 else { throw StoreError.invalidRecording }
        let duration = Double(file.length) / rate
        let segments = try transcript.segments(duration: duration)
        _ = try location.open().save(title: title, startedAt: Date(), durationSeconds: duration,
                                    transcript: segments, recording: url)
    }
    func remove(_ id: UUID, location: LibraryLocationSnapshot) throws {
        stop(revision: location.revision); try location.open().remove(id)
    }
    func export(_ id: UUID, to url: URL, location: LibraryLocationSnapshot) throws { try location.open().exportTranscript(id, to: url) }
    func play(_ id: UUID, location: LibraryLocationSnapshot) throws {
        try play(id, location: location, powerRevision: PowerAdmission.shared.revision)
    }
    func play(_ id: UUID, location: LibraryLocationSnapshot, powerRevision: UUID) throws {
        guard PowerAdmission.shared.allowed, PowerAdmission.shared.revision == powerRevision else { throw StoreError.invalidRecording }
        player?.stop(); player = nil
        guard let url = try location.open().recordingURL(for: id) else { throw StoreError.invalidRecording }
        let value = try AVAudioPlayer(contentsOf: url)
        value.prepareToPlay()
        guard PowerAdmission.shared.allowed, PowerAdmission.shared.revision == powerRevision, value.play() else { throw StoreError.invalidRecording }
        player = value; playerRevision = location.revision
    }
    func stop(revision: UUID?) {
        guard revision == nil || playerRevision == revision else { return }
        player?.stop(); player = nil; playerRevision = nil
    }
    func isPlaying(revision: UUID) -> Bool { playerRevision == revision && (player?.isPlaying ?? false) }
}

@MainActor final class LibraryModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published private var selectedID: UUID?
    var selection: UUID? {
        get { selectedID }
        set {
            guard transcriptSaveSelection == nil || newValue == selectedID else { return }
            if newValue != selectedID { selectionRevision = UUID(); selectedID = newValue }
        }
    }
    @Published private(set) var selectionRevision = UUID()
    private var transcriptSaveSelection: UUID?
    func beginTranscriptSave(session: Session, revision: UUID, selectionRevision: UUID) -> Bool {
        guard !busy, location.snapshot.revision == revision, self.selectionRevision == selectionRevision,
              selected == session else { return false }
        transcriptSaveSelection = session.id; busy = true
        return true
    }
    func finishTranscriptSave(_ session: Session?) {
        if let session, let index = sessions.firstIndex(where: { $0.id == session.id }) { sessions[index] = session }
        transcriptSaveSelection = nil; finishWork()
    }
    @Published var query = ""
    @Published var busy = false { didSet { if busy != oldValue { DiagnosticEventLog.shared.append(component: .library, code: busy ? .started : .stopped, severity: .info) } } }
    @Published var error: String? { didSet { if error != nil && error != oldValue { DiagnosticEventLog.shared.append(component: .library, code: .operationFailed, severity: .error) } } }
    @Published var warning = ""
    @Published var playing = false
    private let worker: any LibraryWorking
    let location: LibraryLocation
    private var locationObservation: AnyCancellable?
    private var displayedRevision: UUID
    init(location: LibraryLocation? = nil, worker: any LibraryWorking = LibraryWorker()) {
        self.location = location ?? .shared; self.worker = worker
        displayedRevision = self.location.snapshot.revision
        AppPowerLifecycle.shared.register(self)
        locationObservation = self.location.$snapshot.dropFirst().sink { [weak self] next in
            guard let self else { return }
            let old = self.displayedRevision
            self.displayedRevision = next.revision
            self.sessions = []; self.selection = nil; self.error = nil; self.warning = ""
            self.playbackTask?.cancel(); self.playing = false
            Task { await self.worker.stop(revision: old) }
            self.recordingDidSave()
        }
    }
    private var pendingRecordingRefresh = false
    private var playbackTask: Task<Void, Never>?
    var selected: Session? { sessions.first { $0.id == selection } }
    var filtered: [Session] {
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(query) ||
            $0.transcript.map(\.text).joined(separator: " ").localizedCaseInsensitiveContains(query) ||
            $0.transcript.contains { $0.speaker?.localizedCaseInsensitiveContains(query) ?? false } }
    }
    private func accepts(_ revision: UUID?) -> Bool {
        guard revision == nil || revision == location.snapshot.revision else {
            error = "The library folder changed. Select the session or reopen Import before continuing."; return false
        }
        return true
    }
    func recordingDidSave() {
        if busy { pendingRecordingRefresh = true }
        else { Task { await load() } }
    }
    private func finishWork() {
        busy = false
        if pendingRecordingRefresh { pendingRecordingRefresh = false; Task { await load() } }
    }
    func load() async {
        guard !busy else { return }
        busy = true; defer { finishWork() }
        let snapshot = location.snapshot
        do { try await reload(snapshot) }
        catch {
            guard location.snapshot.revision == snapshot.revision else { return }
            sessions = []; selection = nil; self.error = "Cannot load history: \(error)"
            location.report(error, location: snapshot)
        }
    }
    private func reload(_ snapshot: LibraryLocationSnapshot) async throws {
        let inventory = try await worker.inventory(snapshot)
        guard location.snapshot.revision == snapshot.revision else { return }
        sessions = inventory.sessions
        error = nil; location.confirmed(snapshot)
        warning = ""
        if !inventory.unreadableEntries.isEmpty || !inventory.pendingEntries.isEmpty {
            warning = "\(inventory.unreadableEntries.count) unreadable entries and \(inventory.pendingEntries.count) incomplete imports remain in the local store."
        }
        if let selection, !sessions.contains(where: { $0.id == selection }) { self.selection = nil }
    }
    func importWAV(_ url: URL, title: String, transcript: String, expectedRevision: UUID? = nil) async -> Bool {
        await importWAV(url, title: title, transcript: .plainText(transcript), expectedRevision: expectedRevision)
    }
    func importWAV(_ url: URL, title: String, transcript: ImportTranscriptDraft, expectedRevision: UUID? = nil) async -> Bool {
        guard accepts(expectedRevision) else { return false }
        guard !busy else { return false }
        guard let activity = try? location.begin("Import") else { return false }
        busy = true; defer { location.end(activity); finishWork() }
        do {
            try await worker.importWAV(url, title: title, transcript: transcript, location: activity.location)
            try await reload(activity.location)
            return true
        } catch { self.error = "Cannot import WAV: \(error)"; return false }
    }
    func delete(_ id: UUID, expectedRevision: UUID? = nil) async {
        guard accepts(expectedRevision) else { return }
        guard !busy else { return }
        guard let activity = try? location.begin("Delete") else { return }
        busy = true; defer { location.end(activity); finishWork() }
        playbackTask?.cancel(); playing = false
        do { try await worker.remove(id, location: activity.location); try await reload(activity.location) }
        catch { self.error = "Cannot delete session: \(error)" }
    }
    func export(_ id: UUID, to url: URL, expectedRevision: UUID? = nil) async {
        guard accepts(expectedRevision) else { return }
        guard !busy else { return }
        guard let activity = try? location.begin("Export") else { return }
        busy = true; defer { location.end(activity); finishWork() }
        do { try await worker.export(id, to: url, location: activity.location) }
        catch { self.error = "Cannot export transcript. Choose a new filename. \(error)" }
    }
    func play(_ id: UUID, expectedRevision: UUID? = nil) async {
        guard PowerAdmission.shared.allowed else { return }
        let powerRevision = PowerAdmission.shared.revision
        guard accepts(expectedRevision) else { return }
        guard !busy else { return }
        guard let activity = try? location.begin("Playback setup") else { return }
        busy = true; defer { location.end(activity); finishWork() }
        playbackTask?.cancel()
        do {
            try await worker.play(id, location: activity.location, powerRevision: powerRevision)
            guard PowerAdmission.shared.allowed, PowerAdmission.shared.revision == powerRevision else {
                await worker.stop(revision: activity.location.revision); return
            }
            playing = true
            playbackTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
                    guard let self else { return }
                    let active = await self.worker.isPlaying(revision: activity.location.revision)
                    guard !Task.isCancelled, self.location.snapshot.revision == activity.location.revision else { return }
                    self.playing = active
                    if !active { return }
                }
            }
        } catch { playing = false; self.error = "Cannot play recording: \(error)" }
    }
    func stop() async {
        playbackTask?.cancel(); playing = false
        await worker.stop(revision: location.snapshot.revision)
    }
}

struct ImportView: View {
    @ObservedObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var transcription = ImportTranscription()
    @State private var file: URL?
    @State private var title = ""
    @State private var transcript = ""
    @State private var locale = ""
    @State private var languages: [TranscriptionLanguage] = []
    @State private var replacingTranscript = false
    @State private var libraryRevision: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import finalized WAV").font(.title2)
            if libraryRevision != model.location.snapshot.revision {
                Text("The library folder changed. Close and reopen Import before saving.").font(.caption).foregroundColor(.red)
            }
            Button("Choose WAV…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.wav]
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    transcription.fileDidChange()
                    replacingTranscript = false
                    file = url; title = url.deletingPathExtension().lastPathComponent
                }
            }.disabled(model.busy)
            Text(file?.lastPathComponent ?? "No file selected").foregroundColor(.secondary)
            TextField("Session title", text: $title)
            Picker("Transcription language", selection: $locale) {
                Text("Choose a language").tag("")
                ForEach(languages) { language in Text(language.name).tag(language.id) }
            }.disabled(model.busy || transcription.busy)
            HStack {
                Button("Transcribe on this Mac") {
                    guard file != nil else { return }
                    if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        startTranscription()
                    } else { replacingTranscript = true }
                }.disabled(file == nil || locale.isEmpty || model.busy || transcription.busy)
                if transcription.busy {
                    ProgressView().controlSize(.small)
                    Button("Cancel transcription") { transcription.cancel() }
                }
            }
            Text("Transcribe only the WAV you selected, using the chosen language on this Mac. Speech permission is requested when you start. You can also enter text below.")
                .font(.caption).foregroundColor(.secondary)
            if !transcription.status.isEmpty {
                Text(transcription.status).font(.caption).foregroundColor(.secondary)
            }
            TextEditor(text: $transcript).frame(height: 150).border(Color.secondary.opacity(0.3))
                .disabled(transcription.busy || model.busy)
            Text(transcription.hasTimings(file: file, text: transcript)
                 ? "Word timestamps will be saved. Export lists each word on its own line."
                 : "Edited or manually entered text will be saved without word timestamps.")
                .font(.caption).foregroundColor(.secondary)
            if let error = transcription.error { Text(error).foregroundColor(.red).font(.caption) }
            if let error = model.error { Text(error).foregroundColor(.red).font(.caption) }
            HStack {
                Button("Cancel") { transcription.cancel(); dismiss() }.disabled(model.busy)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button("Import") {
                    guard let file, !transcription.busy else { return }
                    let revision = libraryRevision
                    let draft = transcription.draft(file: file, text: transcript)
                    Task { if await model.importWAV(file, title: title.trimmingCharacters(in: .whitespacesAndNewlines), transcript: draft, expectedRevision: revision) { dismiss() } }
                }.disabled(file == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.busy || transcription.busy || libraryRevision != model.location.snapshot.revision)
            }
        }.padding(24).frame(width: 560)
        .interactiveDismissDisabled(model.busy)
        .onAppear { languages = TranscriptionLanguage.supported(); libraryRevision = model.location.snapshot.revision }
        .onDisappear { transcription.cancel() }
        .onChange(of: transcript) { transcription.reviewTextChanged($0) }
        .onChange(of: transcription.completedText) { text in
            if let text { transcript = text }
        }
        .alert("Replace transcript text?", isPresented: $replacingTranscript) {
            Button("Cancel", role: .cancel) { }
            Button("Transcribe and replace") { startTranscription() }
        } message: {
            Text("Your current text stays until transcription succeeds. A successful result replaces it so you can review and edit it before importing.")
        }
    }
    private func startTranscription() {
        guard let file else { return }
        transcription.start(file: file, locale: locale)
    }
}

struct LibraryView: View {
    @ObservedObject var model: LibraryModel
    @ObservedObject var audio: AudioRouteController
    @ObservedObject var catalog: CatalogModel
    @ObservedObject private var microphoneTest = MicrophoneTestController.shared
    @ObservedObject private var libraryLocation = LibraryLocation.shared
    @State private var showingSettings = false
    @State private var showingAudio = false
    @State private var importing = false
    @State private var transcribing: Session?
    @State private var showingTranscription = false
    @State private var deleting: Session?
    @State private var deletingRevision: UUID?
    private func duration(_ seconds: Double) -> String {
        guard seconds < Double(Int.max) else { return "Long recording" }
        let whole = Int(seconds)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Lab Voice").font(.title2)
                    Text(audio.statusTitle).font(.caption).foregroundColor(.secondary)
                    if audio.recording.busy { Text(audio.recording.message).font(.caption).foregroundColor(audio.recording.phase == .paused ? .orange : .red) }
                }
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button("Import WAV…") { model.error = nil; importing = true }.disabled(model.busy)
                Button("Audio…") { showingAudio = true }
                Button("Settings…") { showingSettings = true }
                Button("Refresh") { Task { await model.load() } }.disabled(model.busy)
            }.padding()
            PowerStatusView()
            Text(libraryLocation.displayPath).font(.caption).foregroundColor(.secondary).textSelection(.enabled)
            if let error = libraryLocation.error { Text(error).font(.caption).foregroundColor(.red).textSelection(.enabled) }
            Divider()
            HSplitView {
                VStack {
                    TextField("Search history and transcripts", text: $model.query).padding(10)
                    List(selection: $model.selection) {
                        ForEach(model.filtered, id: \.id) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(duration(session.durationSeconds))")
                                    .font(.caption).foregroundColor(.secondary)
                            }.tag(session.id)
                        }
                    }
                    if !model.busy && model.filtered.isEmpty {
                        Text(model.query.isEmpty ? "No local sessions. Import a WAV to begin." : "No matching sessions.")
                            .foregroundColor(.secondary).padding()
                    }
                }.frame(minWidth: 260, idealWidth: 310)
                VStack(alignment: .leading, spacing: 16) {
                    if let session = model.selected {
                        Text(session.title).font(.title)
                        Text("\(duration(session.durationSeconds)) · Saved \(session.startedAt.formatted())")
                            .foregroundColor(.secondary)
                        HStack {
                            Button(model.playing ? "Stop playback" : "Play recording") {
                                let revision = model.location.snapshot.revision
                                Task { if model.playing { await model.stop() } else { await model.play(session.id, expectedRevision: revision) } }
                            }.disabled(session.recordingFilename == nil || model.busy)
                            Button("Export transcript…") {
                                let revision = model.location.snapshot.revision
                                let panel = NSSavePanel()
                                panel.allowedContentTypes = [.plainText]
                                panel.nameFieldStringValue = "transcript.txt"
                                if panel.runModal() == .OK, let url = panel.url {
                                    Task { await model.export(session.id, to: url, expectedRevision: revision) }
                                }
                            }.disabled(session.transcript.isEmpty || model.busy)
                            Button("Delete…") { deletingRevision = model.location.snapshot.revision; deleting = session }.disabled(model.busy)
                        }
                        Button("Transcribe on this Mac…") { transcribing = session; showingTranscription = true }
                            .disabled(session.recordingFilename == nil || model.busy)
                        Divider()
                        Text("Transcript").font(.headline)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                if session.transcript.isEmpty {
                                    Text("No transcript supplied for this recording.").foregroundColor(.secondary)
                                }
                                ForEach(Array(session.transcript.enumerated()), id: \.offset) { _, segment in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(duration(segment.startSeconds))" + (segment.speaker.map { " · " + $0 } ?? ""))
                                            .font(.caption).foregroundColor(.secondary)
                                        Text(segment.text).textSelection(.enabled)
                                    }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Text("Select a session").font(.title2)
                        Text("Recordings and supplied transcript text stay in your local library.").foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                }.padding(24).frame(minWidth: 450, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            if !model.warning.isEmpty { Divider(); Text(model.warning).font(.caption).padding(10) }
            if !audio.recording.retainedPaths.isEmpty { Divider(); ScrollView { RetainedRecordingNotice(recording: audio.recording) }.frame(maxHeight: 100).padding(10) }
            if !microphoneTest.retainedPaths.isEmpty {
                Divider()
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("Private microphone test folders remain after interrupted cleanup. No history session was saved.")
                        ForEach(microphoneTest.retainedPaths, id: \.self) { Text($0).textSelection(.enabled) }
                    }.font(.caption).foregroundColor(.orange)
                }.frame(maxHeight: 100).padding(10)
            }
        }.frame(minWidth: 820, minHeight: 520)
        .task { await model.load(); await audio.recording.refreshRetained(); await microphoneTest.refreshRetained() }
        .onReceive(NotificationCenter.default.publisher(for: .localRecordingSaved)) { _ in model.recordingDidSave() }
        .onChange(of: model.selection) { _ in Task { await model.stop() } }
        .sheet(isPresented: $showingAudio) { AudioView(audio: audio) }
        .sheet(isPresented: $showingSettings) { AppSettingsView(catalog: catalog, library: model, audio: audio, showDone: true) }
        .sheet(isPresented: $importing) { ImportView(model: model) }
        .sheet(isPresented: $showingTranscription) {
            if let session = transcribing { SavedSessionTranscriptionView(model: model, session: session) }
        }
        .alert(deleting == nil ? "Operation failed" : "Delete local session?",
               isPresented: Binding(get: { deleting != nil || (model.error != nil && !importing && !showingTranscription) },
                                    set: { if !$0 { deleting = nil; model.error = nil } })) {
            if let session = deleting {
                Button("Cancel", role: .cancel) { deleting = nil }
                Button("Delete", role: .destructive) {
                    let revision = deletingRevision
                    Task { await model.delete(session.id, expectedRevision: revision) }
                    deleting = nil
                }
            } else {
                Button("OK") { model.error = nil }
            }
        } message: {
            if deleting != nil {
                Text("This permanently removes the selected recording and transcript from Lab Voice. The source WAV remains in its original location.")
            } else { Text(model.error ?? "") }
        }
    }
}

@main struct LabVoiceApp: App {
    @NSApplicationDelegateAdaptor(LabVoiceApplicationDelegate.self) private var delegate
    @StateObject private var audio = AudioRouteController.shared
    @StateObject private var widget = FloatingWidgetController.shared
    @StateObject private var model = LibraryModel()
    @StateObject private var catalog = CatalogModel()
    @AppStorage("powerSimulationCommands") private var powerSimulationCommands = false
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    init() {
        // Headless bundle check exits before scenes or the session store open.
        if CommandLine.arguments.contains("--verify-model-catalog") {
            do {
                let models = try ModelCatalog.installedExpectations()
                guard models.count == 11, models.filter({ $0.sha256 != nil }).count == 8 else {
                    throw CatalogError.invalidManifest
                }
                print("Packaged model catalog resolved: 11 entries, 8 reference digests, no weights.")
                exit(0)
            } catch {
                fputs("Packaged model catalog failed: \(error)\n", stderr)
                exit(1)
            }
        }
    }
    var body: some Scene {
        WindowGroup {
            LibraryView(model: model, audio: audio, catalog: catalog).preferredColorScheme(appearance.colorScheme)
                .onAppear { widget.restoreVisibility() }
        }
        .commands {
            CommandGroup(before: .appTermination) {
                Button("Relaunch Lab Voice…") { delegate.requestRelaunch() }
                    .disabled(delegate.actionPending || delegate.relaunchBlocked)
            }
            CommandMenu("Widget") {
                Button("Show widget") { widget.show() }
                Button("Hide widget") { widget.hide() }.disabled(!widget.isVisible)
            }
        }
        Settings { AppSettingsView(catalog: catalog, library: model, audio: audio).preferredColorScheme(appearance.colorScheme) }
    }
}
