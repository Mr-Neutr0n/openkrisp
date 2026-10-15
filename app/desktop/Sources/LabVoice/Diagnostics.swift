import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

actor DiagnosticsWriter {
    func save(_ report: DiagnosticReport, to url: URL, sample: URL?) throws { try DiagnosticReportExporter.write(report, to: url, sample: sample) }
}

@MainActor final class DiagnosticsController: ObservableObject {
    @Published var category: DiagnosticCategory = .other
    @Published var description = "" {
        didSet {
            if description.utf8.count > DiagnosticReport.maximumIssueBytes {
                var bytes = Array(description.utf8.prefix(DiagnosticReport.maximumIssueBytes))
                while String(bytes: bytes, encoding: .utf8) == nil { bytes.removeLast() }
                description = String(bytes: bytes, encoding: .utf8) ?? ""
            }
        }
    }
    @Published var includeOccurrenceDate = false
    @Published var occurrenceDate = Date()
    @Published var includeSystemInformation = false
    @Published var selectedSample: URL?
    @Published private(set) var saving = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false
    private let snapshot: () -> DiagnosticStatusSnapshot
    private let log: DiagnosticEventLog
    private let export: (DiagnosticReport, URL, URL?) async throws -> Void
    init(snapshot: @escaping () -> DiagnosticStatusSnapshot, log: DiagnosticEventLog? = nil,
         export: ((DiagnosticReport, URL, URL?) async throws -> Void)? = nil) {
        self.snapshot = snapshot; self.log = log ?? .shared
        let writer = DiagnosticsWriter()
        self.export = export ?? { try await writer.save($0, to: $1, sample: $2) }
    }
    func save(to url: URL) async {
        guard !saving else { return }
        saving = true; message = "Saving diagnostics locally…"; failed = false
        defer { saving = false }
        log.append(component: .app, code: .exportStarted, severity: .info)
        do {
            let system: DiagnosticSystemMetadata? = includeSystemInformation ? .init(osVersion: ProcessInfo.processInfo.operatingSystemVersionString, architecture: .arm64) : nil
            let report = try DiagnosticReport.make(appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development", build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "development", issue: .init(category: category, text: description, occurredAt: includeOccurrenceDate ? occurrenceDate : nil), status: snapshot(), events: log.snapshot(), system: system)
            try await export(report, url, selectedSample)
            log.append(component: .app, code: .exportCompleted, severity: .info)
            message = "Diagnostics saved to the selected folder."
        } catch {
            log.append(component: .app, code: .exportFailed, severity: .error)
            failed = true
            if let failure = error as? DiagnosticExportError {
                switch failure {
                case .invalidSample: message = "The selected sample must be a readable, finalized mono or stereo PCM16 WAV. Choose another sample or clear it."
                case .invalidReport: message = "The current diagnostic report is invalid. Review the description and try again."
                case .invalidDestination: message = "Choose a new diagnostic folder in a writable location. Existing folders are never replaced."
                case .cancelled: failed = false; message = "Diagnostic export cancelled."
                case .cleanupIncomplete: message = "Export failed and incomplete files may remain in the selected folder. Review it before retrying."
                case .io: message = "Cannot save diagnostics. Check the destination and selected sample, then try a new folder name."
                }
            } else { message = "Cannot save diagnostics. Choose a new folder name in a writable location. Existing folders are never replaced." }
        }
    }
}

@MainActor enum DiagnosticsStatus {
    static func current(audio: AudioRouteController, library: LibraryModel, test: MicrophoneTestController) -> DiagnosticStatusSnapshot {
        let audioState: DiagnosticState
        switch audio.phase { case .idle: audioState = audio.error == nil ? .idle : .failed
        case .authorizing, .starting: audioState = .starting
        case .running: audioState = .running
        case .stopping: audioState = .stopping }
        let recording: DiagnosticState
        switch audio.recording.phase { case .idle: recording = audio.recording.error == nil ? .idle : .failed
        case .recording: recording = .running
        case .paused: recording = .paused
        case .uncertain: recording = .unknown
        case .stopping: recording = .stopping
        default: recording = .busy }
        let microphone: DiagnosticState
        switch test.phase { case .idle: microphone = .idle
        case .failed: microphone = .failed
        case .comparison: microphone = .ready
        case .capturing: microphone = .running
        default: microphone = .busy }
        return .init(audio: audioState, recording: recording,
                     library: library.location.error != nil || library.error != nil ? .unavailable : (library.busy || library.location.switching ? .busy : .ready),
                     microphoneTest: microphone, controls: audio.controlPending ? .pending : (audio.controlError != nil ? .unknown : (audio.confirmedControls != nil ? .ready : .idle)), sessionCount: library.sessions.count)
    }
    static func guidance(audio: AudioRouteController, library: LibraryModel, test: MicrophoneTestController) -> [String] {
        var result: [String] = []
        if let inventory = audio.inventory, !inventory.driverPresent { result.append("The virtual audio driver is unavailable. Review the driver setup before starting a route.") }
        if audio.error != nil { result.append("Audio reported an error. Open Audio to review its current message and selected devices.") }
        if audio.controlError != nil { result.append("Route controls are not confirmed. Review Audio before relying on the requested mute or volume.") }
        if library.location.error != nil || library.error != nil { result.append("The library needs attention. Check the selected folder or choose an accessible folder in App settings.") }
        if !audio.recording.retainedPaths.isEmpty || !test.retainedPaths.isEmpty { result.append("Temporary files need attention. Review the recording or microphone-test recovery message before deleting anything.") }
        if result.isEmpty { result.append("No specific recovery action follows from the current status. Describe the issue and save a local report.") }
        return result
    }
}

struct DiagnosticsView: View {
    @StateObject private var controller: DiagnosticsController
    @ObservedObject var audio: AudioRouteController
    @ObservedObject var library: LibraryModel
    @ObservedObject private var test = MicrophoneTestController.shared
    init(audio: AudioRouteController, library: LibraryModel) {
        self.audio = audio; self.library = library
        _controller = StateObject(wrappedValue: DiagnosticsController(snapshot: { DiagnosticsStatus.current(audio: audio, library: library, test: .shared) }))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Local diagnostics").font(.headline)
                Text("Save current app status and recent event codes from this run. This is not a historical crash log. Nothing is uploaded.")
                Picker("Issue", selection: $controller.category) {
                    Text("Audio").tag(DiagnosticCategory.audio)
                    Text("Recording").tag(DiagnosticCategory.recording)
                    Text("Library").tag(DiagnosticCategory.library)
                    Text("Transcription").tag(DiagnosticCategory.transcription)
                    Text("Other").tag(DiagnosticCategory.other)
                }
                Text("Description, optional.").font(.caption)
                TextEditor(text: $controller.description).frame(height: 90).border(Color.secondary.opacity(0.3))
                Toggle("Include when the issue occurred", isOn: $controller.includeOccurrenceDate)
                if controller.includeOccurrenceDate { DatePicker("Issue date", selection: $controller.occurrenceDate) }
                Toggle("Include macOS version and processor architecture", isOn: $controller.includeSystemInformation)
                HStack {
                    Button("Choose PCM16 WAV sample…") {
                        let panel = NSOpenPanel(); panel.allowedContentTypes = [.wav]; panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK { controller.selectedSample = panel.url }
                    }
                    Button("Clear sample") { controller.selectedSample = nil }.disabled(controller.selectedSample == nil)
                }
                Text(controller.selectedSample == nil ? "No sample attached." : "The selected finalized mono or stereo PCM16 WAV will be copied as sample.wav, including its existing metadata.").font(.caption)
                Text("Status and event codes exclude transcripts, device identifiers, paths and raw system logs. Your description is included as entered. Audio is included only when you explicitly choose a finalized mono or stereo PCM16 RIFF/WAVE sample.").font(.caption).foregroundColor(.secondary)
                Divider()
                Text("Current status").font(.headline)
                Text(audio.statusTitle + " · " + audio.recording.message).font(.caption)
                Text("Microphone test: \(String(describing: test.phase)). Library: \(library.busy ? "busy" : (library.location.error == nil && library.error == nil ? "ready" : "needs attention")).").font(.caption)
                Text(audio.controlStatus).font(.caption)
                Text("Troubleshooting").font(.headline)
                ForEach(DiagnosticsStatus.guidance(audio: audio, library: library, test: test), id: \.self) { Text($0).font(.caption) }
                Button("Save diagnostic folder…") {
                    let panel = NSSavePanel(); panel.nameFieldStringValue = "Lab-Voice-diagnostics"; panel.canCreateDirectories = true
                    if panel.runModal() == .OK, let url = panel.url { Task { await controller.save(to: url) } }
                }.disabled(controller.saving)
                if controller.saving { ProgressView().controlSize(.small) }
                if let message = controller.message { Text(message).foregroundColor(controller.failed ? .red : .secondary) }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }.disabled(controller.saving)
    }
}
