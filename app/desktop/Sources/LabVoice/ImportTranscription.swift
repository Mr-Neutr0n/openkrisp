import Foundation
import Combine
import LocalTranscription
@preconcurrency import Speech

struct TranscriptionLanguage: Identifiable {
    let id: String
    let name: String
    static func supported() -> [TranscriptionLanguage] {
        SFSpeechRecognizer.supportedLocales().map { locale in
            let name = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
            return TranscriptionLanguage(id: locale.identifier, name: name)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

@MainActor final class ImportTranscription: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var status = ""
    @Published private(set) var error: String?
    @Published private(set) var completedText: String?
    private let authorization: () -> SpeechAuthorization
    private let requestAuthorization: () async throws -> SpeechAuthorization
    private let recognize: (UserSelectedWAV, String) async throws -> OfflineTranscript
    private let cancelRecognition: () -> Void
    private let location: LibraryLocation
    private var libraryActivity: LibraryActivity?
    private var operationID: UUID?
    private var task: Task<Void, Never>?

    init() {
        location = .shared
        let transcriber = OfflineTranscriber()
        authorization = { OfflineTranscriber.authorizationStatus }
        requestAuthorization = { try await OfflineTranscriber.requestAuthorization() }
        recognize = { file, locale in try await transcriber.transcribe(file, localeIdentifier: locale) }
        cancelRecognition = { transcriber.cancel() }
    }
    // Tests replace permission and recognition without requesting OS consent or starting Speech.
    init(authorization: @escaping () -> SpeechAuthorization,
         requestAuthorization: @escaping () async throws -> SpeechAuthorization,
         recognize: @escaping (UserSelectedWAV, String) async throws -> OfflineTranscript,
         cancelRecognition: @escaping () -> Void, location: LibraryLocation? = nil) {
        self.location = location ?? .shared
        self.authorization = authorization
        self.requestAuthorization = requestAuthorization
        self.recognize = recognize
        self.cancelRecognition = cancelRecognition
    }

    // Only the explicit Transcribe/Replace buttons call this method.
    func start(file: URL, locale: String) {
        guard !busy else { return }
        guard !locale.isEmpty else { error = "Choose a transcription language."; return }
        let selected: UserSelectedWAV
        do { selected = try UserSelectedWAV(userSelectedURL: file) }
        catch { self.error = "Choose a readable, finalized WAV file."; return }
        guard let activity = try? location.begin("Transcription") else { error = "Finish changing the library folder before transcribing."; return }
        let id = UUID()
        libraryActivity = activity
        operationID = id
        busy = true; error = nil; completedText = nil
        status = "Preparing transcription…"
        let location = self.location
        task = Task { [weak self] in
            defer { location.end(activity) }
            guard let self, self.operationID == id, !Task.isCancelled else { return }
            defer {
                if self.operationID == id {
                    self.operationID = nil; self.task = nil; self.busy = false; self.libraryActivity = nil
                }
            }
            do {
                var permission = self.authorization()
                if permission == .notDetermined {
                    self.status = "Waiting for Speech permission…"
                    permission = try await self.requestAuthorization()
                }
                guard self.operationID == id, !Task.isCancelled else { return }
                guard permission == .authorized else {
                    throw TranscriptionFailure.authorizationRequired(permission)
                }
                self.status = "Transcribing on this Mac…"
                let result = try await self.recognize(selected, locale)
                guard self.operationID == id, !Task.isCancelled else { return }
                guard !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.error = "No speech text was returned. Your current transcript is unchanged."
                    self.status = ""; return
                }
                self.completedText = result.text
                self.status = "Transcript ready. Review and edit it before importing."
            } catch {
                guard self.operationID == id, !Task.isCancelled else { return }
                self.error = Self.message(error)
                self.status = ""
            }
        }
    }
    func cancel() {
        if let libraryActivity { location.end(libraryActivity); self.libraryActivity = nil }
        operationID = nil
        task?.cancel(); task = nil
        cancelRecognition()
        busy = false; status = ""; error = nil; completedText = nil
    }
    private static func message(_ error: Error) -> String {
        guard let failure = error as? TranscriptionFailure else {
            return "Transcription failed. Your current transcript is unchanged. \(error.localizedDescription)"
        }
        switch failure {
        case .authorizationRequired(.denied):
            return "Speech permission was denied. Allow Lab Voice in macOS privacy settings to transcribe."
        case .authorizationRequired(.restricted):
            return "Speech recognition is restricted on this Mac."
        case .authorizationRequired:
            return "Speech permission is required to transcribe this file."
        case .unsupportedLocale:
            return "The selected language is unavailable. No other language was used."
        case .onDeviceRecognitionUnsupported:
            return "On-device recognition is unavailable for this language. No server recognition was used."
        case .recognizerUnavailable:
            return "The recognizer is unavailable for this language. Try again when it is available."
        case .invalidWAV:
            return "The selected WAV cannot be transcribed. Choose a readable, finalized WAV file."
        case .timedOut:
            return "Transcription timed out. Your current transcript is unchanged."
        case .cancelled:
            return "Transcription was cancelled. Your current transcript is unchanged."
        case .missingUsageDescription:
            return "This app bundle is missing its Speech permission description."
        case .invalidResult:
            return "Recognition returned invalid text. Your current transcript is unchanged."
        case .recognitionFailed(_, _, let description):
            return "Transcription failed. Your current transcript is unchanged. \(description)"
        case .busy, .invalidTimeout:
            return "Transcription could not start. Your current transcript is unchanged."
        }
    }
}
