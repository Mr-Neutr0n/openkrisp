import Foundation
@preconcurrency import Speech

@MainActor public final class OfflineTranscriber {
    public private(set) var phase: TranscriptionPhase = .idle
    public var isBusy: Bool { operationID != nil }
    private let authorization: @MainActor () -> SpeechAuthorization
    private let factory: @MainActor (String) -> (any OfflineRecognitionBackend)?
    private let validateFile: @Sendable (UserSelectedWAV) async throws -> Void
    private var operationID: UUID?
    private var continuation: CheckedContinuation<OfflineTranscript, any Error>?
    private var cancellation: (any RecognitionCancellation)?
    private var backend: (any OfflineRecognitionBackend)?
    private var deadline: Task<Void, Never>?

    public init() {
        authorization = { mapAuthorization(SFSpeechRecognizer.authorizationStatus()) }
        factory = { AppleBackend(locale: $0) }
        validateFile = validateSelectedWAV
    }
    init(authorization: @escaping @MainActor () -> SpeechAuthorization,
         factory: @escaping @MainActor (String) -> (any OfflineRecognitionBackend)?,
         validateFile: @escaping @Sendable (UserSelectedWAV) async throws -> Void) {
        self.authorization = authorization; self.factory = factory; self.validateFile = validateFile
    }
    public static var authorizationStatus: SpeechAuthorization {
        mapAuthorization(SFSpeechRecognizer.authorizationStatus())
    }
    /// Only call after an explicit user action consenting to the OS prompt.
    /// The app must contain NSSpeechRecognitionUsageDescription.
    public static func requestAuthorization() async throws -> SpeechAuthorization {
        guard let description = Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") as? String,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptionFailure.missingUsageDescription
        }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: mapAuthorization(status))
            }
        }
    }
    public func transcribe(_ selected: UserSelectedWAV, localeIdentifier: String,
                           timeoutSeconds: Double = 120) async throws -> OfflineTranscript {
        if Task.isCancelled { throw TranscriptionFailure.cancelled }
        guard !isBusy else { throw TranscriptionFailure.busy }
        guard timeoutSeconds.isFinite, timeoutSeconds > 0, timeoutSeconds <= 3600 else {
            throw TranscriptionFailure.invalidTimeout
        }
        let status = authorization()
        guard status == .authorized else { throw TranscriptionFailure.authorizationRequired(status) }
        guard let candidate = factory(localeIdentifier), sameLocale(candidate.localeIdentifier, localeIdentifier) else {
            throw TranscriptionFailure.unsupportedLocale
        }
        guard candidate.supportsOnDeviceRecognition else { throw TranscriptionFailure.onDeviceRecognitionUnsupported }
        guard candidate.isAvailable else { throw TranscriptionFailure.recognizerUnavailable }
        let id = UUID()
        operationID = id; backend = candidate; phase = .validatingFile
        var validationCompleted = false
        return try await withTaskCancellationHandler {
            do {
                try await validateFile(selected)
                guard !Task.isCancelled, operationID == id else { throw TranscriptionFailure.cancelled }
                // Permission can change while the file is being validated.
                let currentAuthorization = authorization()
                guard currentAuthorization == .authorized else {
                    throw TranscriptionFailure.authorizationRequired(currentAuthorization)
                }
                guard candidate.supportsOnDeviceRecognition else { throw TranscriptionFailure.onDeviceRecognitionUnsupported }
                guard candidate.isAvailable else { throw TranscriptionFailure.recognizerUnavailable }
                validationCompleted = true
                return try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation
                    phase = .recognizing
                    let handle = candidate.start(file: selected.url) { [weak self] result in
                        self?.finish(id, result)
                    }
                    // A backend may synchronously fail or complete during start.
                    guard operationID == id else { handle.cancel(); return }
                    cancellation = handle
                    deadline = Task { [weak self] in
                        do { try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000)) }
                        catch { return }
                        self?.finish(id, .failure(.timedOut))
                    }
                }
            } catch {
                let failure: any Error = (error is CancellationError ||
                    (!validationCompleted && operationID != id)) ? TranscriptionFailure.cancelled : error
                if operationID == id { finish(id, .failure(failure as? TranscriptionFailure ?? .invalidWAV)) }
                throw failure
            }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.finish(id, .failure(.cancelled)) }
        }
    }
    public func cancel() {
        if let id = operationID { finish(id, .failure(.cancelled)) }
    }
    private func finish(_ id: UUID, _ result: Result<OfflineTranscript, TranscriptionFailure>) {
        guard operationID == id else { return }
        operationID = nil
        let pending = continuation; continuation = nil
        let handle = cancellation; cancellation = nil
        deadline?.cancel(); deadline = nil
        backend = nil
        switch result {
        case .success: phase = .completed
        case .failure(.cancelled): phase = .cancelled
        case .failure: phase = .failed
        }
        handle?.cancel()
        pending?.resume(with: result.mapError { $0 as any Error })
    }
}
