import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import LocalStore
import ModelCatalog

actor LibraryWorker {
    private var storage: LocalStore?
    private var player: AVAudioPlayer?
    private func store() throws -> LocalStore {
        if let storage { return storage }
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let value = try LocalStore(root: base.appendingPathComponent("Lab Voice/sessions", isDirectory: true))
        storage = value
        return value
    }
    func inventory() throws -> StoreInventory { try store().inventory() }
    func importWAV(_ url: URL, title: String, transcript: String) throws {
        let file = try AVAudioFile(forReading: url)
        let rate = file.processingFormat.sampleRate
        guard rate.isFinite, rate > 0 else { throw StoreError.invalidRecording }
        let duration = Double(file.length) / rate
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = text.isEmpty ? [] : [TranscriptSegment(startSeconds: 0, endSeconds: duration, text: text)]
        _ = try store().save(title: title, startedAt: Date(), durationSeconds: duration,
                             transcript: segments, recording: url)
    }
    func remove(_ id: UUID) throws { player?.stop(); player = nil; try store().remove(id) }
    func export(_ id: UUID, to url: URL) throws { try store().exportTranscript(id, to: url) }
    func play(_ id: UUID) throws {
        player?.stop(); player = nil
        guard let url = try store().recordingURL(for: id) else { throw StoreError.invalidRecording }
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.prepareToPlay()
        guard newPlayer.play() else { throw StoreError.invalidRecording }
        player = newPlayer
    }
    func stop() { player?.stop(); player = nil }
    func isPlaying() -> Bool { player?.isPlaying ?? false }
}

@MainActor final class LibraryModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var selection: UUID?
    @Published var query = ""
    @Published var busy = false
    @Published var error: String?
    @Published var warning = ""
    @Published var playing = false
    private let worker = LibraryWorker()
    private var pendingRecordingRefresh = false
    private var playbackTask: Task<Void, Never>?
    var selected: Session? { sessions.first { $0.id == selection } }
    var filtered: [Session] {
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(query) ||
            $0.transcript.contains { $0.text.localizedCaseInsensitiveContains(query) ||
                ($0.speaker?.localizedCaseInsensitiveContains(query) ?? false) } }
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
        do { try await reload() } catch { self.error = "Cannot load history: \(error)" }
    }
    private func reload() async throws {
        let inventory = try await worker.inventory()
        sessions = inventory.sessions
        warning = ""
        if !inventory.unreadableEntries.isEmpty || !inventory.pendingEntries.isEmpty {
            warning = "\(inventory.unreadableEntries.count) unreadable entries and \(inventory.pendingEntries.count) incomplete imports remain in the local store."
        }
        if let selection, !sessions.contains(where: { $0.id == selection }) { self.selection = nil }
    }
    func importWAV(_ url: URL, title: String, transcript: String) async -> Bool {
        guard !busy else { return false }
        busy = true; defer { finishWork() }
        do {
            try await worker.importWAV(url, title: title, transcript: transcript)
            try await reload()
            return true
        } catch { self.error = "Cannot import WAV: \(error)"; return false }
    }
    func delete(_ id: UUID) async {
        guard !busy else { return }
        busy = true; defer { finishWork() }
        playbackTask?.cancel(); playing = false
        do { try await worker.remove(id); try await reload() }
        catch { self.error = "Cannot delete session: \(error)" }
    }
    func export(_ id: UUID, to url: URL) async {
        guard !busy else { return }
        busy = true; defer { finishWork() }
        do { try await worker.export(id, to: url) }
        catch { self.error = "Cannot export transcript. Choose a new filename. \(error)" }
    }
    func play(_ id: UUID) async {
        guard !busy else { return }
        busy = true; defer { finishWork() }
        playbackTask?.cancel()
        do {
            try await worker.play(id)
            playing = true
            playbackTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
                    guard let self else { return }
                    let active = await self.worker.isPlaying()
                    guard !Task.isCancelled else { return }
                    self.playing = active
                    if !active { return }
                }
            }
        } catch { playing = false; self.error = "Cannot play recording: \(error)" }
    }
    func stop() async {
        playbackTask?.cancel(); playing = false
        await worker.stop()
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
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import finalized WAV").font(.title2)
            Button("Choose WAV…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.wav]
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    transcription.cancel()
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
            if let error = transcription.error { Text(error).foregroundColor(.red).font(.caption) }
            if let error = model.error { Text(error).foregroundColor(.red).font(.caption) }
            HStack {
                Button("Cancel") { transcription.cancel(); dismiss() }.disabled(model.busy)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button("Import") {
                    guard let file, !transcription.busy else { return }
                    Task { if await model.importWAV(file, title: title.trimmingCharacters(in: .whitespacesAndNewlines), transcript: transcript) { dismiss() } }
                }.disabled(file == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.busy || transcription.busy)
            }
        }.padding(24).frame(width: 560)
        .interactiveDismissDisabled(model.busy)
        .onAppear { languages = TranscriptionLanguage.supported() }
        .onDisappear { transcription.cancel() }
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
    @State private var showingSettings = false
    @State private var showingAudio = false
    @State private var importing = false
    @State private var deleting: Session?
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
                                Task { if model.playing { await model.stop() } else { await model.play(session.id) } }
                            }.disabled(session.recordingFilename == nil || model.busy)
                            Button("Export transcript…") {
                                let panel = NSSavePanel()
                                panel.allowedContentTypes = [.plainText]
                                panel.nameFieldStringValue = "transcript.txt"
                                if panel.runModal() == .OK, let url = panel.url {
                                    Task { await model.export(session.id, to: url) }
                                }
                            }.disabled(session.transcript.isEmpty || model.busy)
                            Button("Delete…") { deleting = session }.disabled(model.busy)
                        }
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
        .sheet(isPresented: $showingSettings) { AppSettingsView(catalog: catalog, showDone: true) }
        .sheet(isPresented: $importing) { ImportView(model: model) }
        .alert(deleting == nil ? "Operation failed" : "Delete local session?",
               isPresented: Binding(get: { deleting != nil || (model.error != nil && !importing) },
                                    set: { if !$0 { deleting = nil; model.error = nil } })) {
            if let session = deleting {
                Button("Cancel", role: .cancel) { deleting = nil }
                Button("Delete", role: .destructive) {
                    Task { await model.delete(session.id) }
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
            CommandMenu("Widget") {
                Button("Show widget") { widget.show() }
                Button("Hide widget") { widget.hide() }.disabled(!widget.isVisible)
            }
        }
        Settings { AppSettingsView(catalog: catalog).preferredColorScheme(appearance.colorScheme) }
    }
}
