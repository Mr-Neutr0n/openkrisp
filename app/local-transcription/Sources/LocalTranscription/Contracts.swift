import Foundation

public enum SpeechAuthorization: String, Sendable, Equatable {
    case notDetermined, denied, restricted, authorized, unknown
}
public enum TranscriptionPhase: String, Sendable { case idle, validatingFile, recognizing, completed, failed, cancelled }
public enum TranscriptionFailure: Error, Sendable, Equatable {
    case authorizationRequired(SpeechAuthorization)
    case missingUsageDescription
    case unsupportedLocale
    case onDeviceRecognitionUnsupported
    case recognizerUnavailable
    case invalidWAV
    case busy
    case cancelled
    case timedOut
    case invalidTimeout
    case invalidResult
    case recognitionFailed(domain: String, code: Int, description: String)
}
public struct UserSelectedWAV: Sendable {
    public let url: URL
    /// The caller must obtain this URL from an explicit user file selection.
    /// Construction never reads the file or requests authorization.
    public init(userSelectedURL: URL) throws {
        guard userSelectedURL.isFileURL, userSelectedURL.pathExtension.lowercased() == "wav",
              !userSelectedURL.path.utf8.contains(0) else { throw TranscriptionFailure.invalidWAV }
        url = userSelectedURL.standardizedFileURL
    }
}
public struct RecognizedSegment: Sendable, Equatable {
    public let text: String
    public let startSeconds: Double
    public let durationSeconds: Double
    public let confidence: Float
    public init(text: String, startSeconds: Double, durationSeconds: Double, confidence: Float) {
        self.text = text; self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds; self.confidence = confidence
    }
}
public struct OfflineTranscript: Sendable, Equatable {
    public let text: String
    public let localeIdentifier: String
    public let segments: [RecognizedSegment]
    public init(text: String, localeIdentifier: String, segments: [RecognizedSegment]) {
        self.text = text; self.localeIdentifier = localeIdentifier; self.segments = segments
    }
}

// These protocols permit contract tests without instantiating an OS recognizer,
// requesting consent, opening user files, or performing recognition.
@MainActor protocol RecognitionCancellation: AnyObject { func cancel() }
@MainActor protocol OfflineRecognitionBackend: AnyObject {
    var localeIdentifier: String { get }
    var supportsOnDeviceRecognition: Bool { get }
    var isAvailable: Bool { get }
    func start(file: URL, completion: @escaping @MainActor @Sendable (Result<OfflineTranscript, TranscriptionFailure>) -> Void) -> any RecognitionCancellation
}
func sameLocale(_ first: String, _ second: String) -> Bool {
    first.replacingOccurrences(of: "-", with: "_").lowercased() == second.replacingOccurrences(of: "-", with: "_").lowercased()
}
