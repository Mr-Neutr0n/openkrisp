import Foundation
@preconcurrency import Speech
import AVFoundation
import Darwin

func mapAuthorization(_ status: SFSpeechRecognizerAuthorizationStatus) -> SpeechAuthorization {
    switch status {
    case .notDetermined: return .notDetermined
    case .denied: return .denied
    case .restricted: return .restricted
    case .authorized: return .authorized
    @unknown default: return .unknown
    }
}
// Kept internal so tests can inspect request policy without starting Speech.
func offlineRequest(_ url: URL) -> SFSpeechURLRecognitionRequest {
    let request = SFSpeechURLRecognitionRequest(url: url)
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = false
    return request
}
@MainActor private final class AppleTask: RecognitionCancellation {
    private let task: SFSpeechRecognitionTask
    init(_ task: SFSpeechRecognitionTask) { self.task = task }
    func cancel() { task.cancel() }
}
@MainActor final class AppleBackend: OfflineRecognitionBackend {
    private let recognizer: SFSpeechRecognizer
    var localeIdentifier: String { recognizer.locale.identifier }
    var supportsOnDeviceRecognition: Bool { recognizer.supportsOnDeviceRecognition }
    var isAvailable: Bool { recognizer.isAvailable }
    init?(locale: String) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else { return nil }
        self.recognizer = recognizer
        recognizer.queue = .main
    }
    func start(file: URL, completion: @escaping @MainActor @Sendable (Result<OfflineTranscript, TranscriptionFailure>) -> Void) -> any RecognitionCancellation {
        // Recheck capability immediately before task creation. Never fall back.
        guard recognizer.supportsOnDeviceRecognition else {
            completion(.failure(.onDeviceRecognitionUnsupported))
            return NoopCancellation()
        }
        guard recognizer.isAvailable else {
            completion(.failure(.recognizerUnavailable))
            return NoopCancellation()
        }
        let locale = localeIdentifier
        let request = offlineRequest(file)
        let task = recognizer.recognitionTask(with: request) { result, error in
            let event: Result<OfflineTranscript, TranscriptionFailure>
            if let error {
                let detail = error as NSError
                event = .failure(.recognitionFailed(domain: detail.domain, code: detail.code, description: detail.localizedDescription))
            } else if let result, result.isFinal {
                let segments = result.bestTranscription.segments.map {
                    RecognizedSegment(text: $0.substring, startSeconds: $0.timestamp,
                                      durationSeconds: $0.duration, confidence: $0.confidence)
                }
                guard segments.allSatisfy({ $0.startSeconds.isFinite && $0.startSeconds >= 0 &&
                    $0.durationSeconds.isFinite && $0.durationSeconds >= 0 &&
                    ($0.startSeconds + $0.durationSeconds).isFinite &&
                    $0.confidence.isFinite && $0.confidence >= 0 && $0.confidence <= 1 }) else {
                    Task { @MainActor in completion(.failure(.invalidResult)) }
                    return
                }
                event = .success(OfflineTranscript(text: result.bestTranscription.formattedString,
                                                   localeIdentifier: locale, segments: segments))
            } else {
                return // Partial results are never published as completed text.
            }
            Task { @MainActor in completion(event) }
        }
        return AppleTask(task)
    }
}
@MainActor private final class NoopCancellation: RecognitionCancellation { func cancel() {} }

func validateSelectedWAV(_ selected: UserSelectedWAV) async throws {
    try await Task.detached(priority: .userInitiated) {
        let path = selected.url.path
        let fd = path.withCString { Darwin.open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK) }
        guard fd >= 0 else { throw TranscriptionFailure.invalidWAV }
        defer { Darwin.close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { throw TranscriptionFailure.invalidWAV }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        let prefix = try handle.read(upToCount: 12) ?? Data()
        guard prefix.count == 12, prefix.prefix(4) == Data("RIFF".utf8),
              prefix.suffix(4) == Data("WAVE".utf8) else { throw TranscriptionFailure.invalidWAV }
        let file = try AVAudioFile(forReading: selected.url)
        guard file.length > 0, file.processingFormat.sampleRate.isFinite,
              file.processingFormat.sampleRate > 0 else { throw TranscriptionFailure.invalidWAV }
    }.value
}
