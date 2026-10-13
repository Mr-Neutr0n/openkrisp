import XCTest
import Foundation
import AVFoundation
@testable import LocalTranscription

@MainActor private final class FakeHandle: RecognitionCancellation {
    var cancellations = 0
    func cancel() { cancellations += 1 }
}
@MainActor private final class FakeBackend: OfflineRecognitionBackend {
    var localeIdentifier = "en_US"
    var supportsOnDeviceRecognition = true
    var isAvailable = true
    var starts = 0
    let handle = FakeHandle()
    var completion: (@MainActor @Sendable (Result<OfflineTranscript, TranscriptionFailure>) -> Void)?
    var immediate: Result<OfflineTranscript, TranscriptionFailure>?
    func start(file: URL, completion: @escaping @MainActor @Sendable (Result<OfflineTranscript, TranscriptionFailure>) -> Void) -> any RecognitionCancellation {
        starts += 1; self.completion = completion
        if let immediate { completion(immediate) }
        return handle
    }
}
private actor Counter {
    var value = 0
    func increment() { value += 1 }
}

private actor ValidationGate {
    var entered = false
    private var waiter: CheckedContinuation<Void, any Error>?
    func wait() async throws {
        entered = true
        try await withCheckedThrowingContinuation { waiter = $0 }
    }
    func releaseWithError() { waiter?.resume(throwing: TranscriptionFailure.invalidWAV); waiter = nil }
}
@MainActor private final class AuthorizationFixture { var status: SpeechAuthorization = .authorized }

final class LocalTranscriptionTests: XCTestCase {
    private let selected = try! UserSelectedWAV(userSelectedURL: URL(fileURLWithPath: "/not-read-by-fixture-backend.wav"))
    @MainActor private func engine(_ backend: FakeBackend, authorization: SpeechAuthorization = .authorized,
                                  reads: Counter = Counter()) -> OfflineTranscriber {
        OfflineTranscriber(authorization: { authorization }, factory: { _ in backend },
                           validateFile: { _ in await reads.increment() })
    }
    @MainActor private func waitForStart(_ backend: FakeBackend) async {
        for _ in 0..<1000 {
            if backend.starts != 0 { return }
            await Task.yield()
        }
        XCTFail("fixture recognition did not start")
    }
    @MainActor func testAuthorizationBlocksBeforeFileReadOrRecognition() async throws {
        for status in [SpeechAuthorization.notDetermined, .denied, .restricted, .unknown] {
            let reads = Counter(), backend = FakeBackend()
            let service = engine(backend, authorization: status, reads: reads)
            do { _ = try await service.transcribe(selected, localeIdentifier: "en-US"); XCTFail("authorization gate bypassed") }
            catch { XCTAssertEqual(error as? TranscriptionFailure, .authorizationRequired(status)) }
            let count = await reads.value
            XCTAssertEqual(count, 0); XCTAssertEqual(backend.starts, 0)
            XCTAssertFalse(service.isBusy)
        }
    }
    @MainActor func testUnsupportedAndUnavailableNeverStartOrRead() async throws {
        for unsupported in [true, false] {
            let backend = FakeBackend(), reads = Counter()
            backend.supportsOnDeviceRecognition = !unsupported
            backend.isAvailable = unsupported
            let service = engine(backend, reads: reads)
            do { _ = try await service.transcribe(selected, localeIdentifier: "en_US"); XCTFail("capability gate bypassed") }
            catch { XCTAssertEqual(error as? TranscriptionFailure, unsupported ? .onDeviceRecognitionUnsupported : .recognizerUnavailable) }
            let count = await reads.value
            XCTAssertEqual(count, 0); XCTAssertEqual(backend.starts, 0)
        }
    }
    @MainActor func testLocaleFallbackIsRejected() async throws {
        let backend = FakeBackend(), reads = Counter()
        let service = engine(backend, reads: reads)
        do { _ = try await service.transcribe(selected, localeIdentifier: "fr_FR"); XCTFail("fallback accepted") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .unsupportedLocale) }
        XCTAssertEqual(backend.starts, 0)
        let count = await reads.value; XCTAssertEqual(count, 0)
    }
    @MainActor func testFinalResultAndDuplicateCallback() async throws {
        let backend = FakeBackend(), service = engine(backend)
        let operation = Task { try await service.transcribe(selected, localeIdentifier: "en_US") }
        await waitForStart(backend)
        let transcript = OfflineTranscript(text: "fixture result", localeIdentifier: "en_US", segments: [
            RecognizedSegment(text: "fixture", startSeconds: 0.2, durationSeconds: 0.4, confidence: 0.9)])
        backend.completion?(.success(transcript))
        backend.completion?(.failure(.invalidResult))
        let actual = try await operation.value
        XCTAssertEqual(actual, transcript)
        XCTAssertEqual(service.phase, .completed)
        XCTAssertEqual(backend.handle.cancellations, 1)
        XCTAssertFalse(service.isBusy)
    }
    @MainActor func testCancellationBusyAndLateCallback() async throws {
        let backend = FakeBackend(), service = engine(backend)
        let operation = Task { try await service.transcribe(selected, localeIdentifier: "en_US") }
        await waitForStart(backend)
        do { _ = try await service.transcribe(selected, localeIdentifier: "en_US"); XCTFail("concurrent task admitted") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .busy) }
        operation.cancel()
        do { _ = try await operation.value; XCTFail("cancelled task succeeded") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .cancelled) }
        backend.completion?(.success(OfflineTranscript(text: "late", localeIdentifier: "en_US", segments: [])))
        XCTAssertEqual(service.phase, .cancelled)
        XCTAssertEqual(backend.handle.cancellations, 1)
        XCTAssertFalse(service.isBusy)
    }
    @MainActor func testExplicitCancelAndRestartIgnoreOldResults() async throws {
        let backend = FakeBackend(), service = engine(backend)
        let first = Task { try await service.transcribe(selected, localeIdentifier: "en_US") }
        await waitForStart(backend)
        let oldCompletion = backend.completion
        service.cancel()
        do { _ = try await first.value; XCTFail("explicit cancel failed") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .cancelled) }
        backend.starts = 0
        let second = Task { try await service.transcribe(selected, localeIdentifier: "en_US") }
        await waitForStart(backend)
        oldCompletion?(.failure(.invalidResult))
        XCTAssertEqual(service.phase, .recognizing)
        backend.completion?(.success(OfflineTranscript(text: "second", localeIdentifier: "en_US", segments: [])))
        let value = try await second.value
        XCTAssertEqual(value.text, "second")
    }
    @MainActor func testBackendErrorAndTimeoutAreReturned() async throws {
        let backend = FakeBackend(), service = engine(backend)
        let operation = Task { try await service.transcribe(selected, localeIdentifier: "en_US") }
        await waitForStart(backend)
        let failure = TranscriptionFailure.recognitionFailed(domain: "fixture", code: 102, description: "assets absent")
        backend.completion?(.failure(failure))
        do { _ = try await operation.value; XCTFail("error discarded") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, failure) }
        XCTAssertEqual(service.phase, .failed)
        do { _ = try await service.transcribe(selected, localeIdentifier: "en_US", timeoutSeconds: 0.01); XCTFail("missing final result did not time out") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .timedOut) }
        XCTAssertFalse(service.isBusy)
    }
    @MainActor func testSynchronousCompletionReleasesReturnedTask() async throws {
        let backend = FakeBackend()
        backend.immediate = .failure(.recognizerUnavailable)
        let service = engine(backend)
        do { _ = try await service.transcribe(selected, localeIdentifier: "en_US"); XCTFail("synchronous failure discarded") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .recognizerUnavailable) }
        XCTAssertEqual(backend.handle.cancellations, 1)
        XCTAssertFalse(service.isBusy)
    }
    @MainActor func testCapabilityRecheckedAfterValidation() async throws {
        let backend = FakeBackend()
        let service = OfflineTranscriber(authorization: { .authorized }, factory: { _ in backend }, validateFile: { _ in
            await MainActor.run { backend.supportsOnDeviceRecognition = false }
        })
        do { _ = try await service.transcribe(selected, localeIdentifier: "en_US"); XCTFail("changed capability ignored") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .onDeviceRecognitionUnsupported) }
        XCTAssertEqual(backend.starts, 0)
        XCTAssertEqual(service.phase, .failed)
    }
    @MainActor func testCancelDuringValidationWinsOverLaterFileError() async throws {
        let gate = ValidationGate(), backend = FakeBackend()
        let service = OfflineTranscriber(authorization: { .authorized }, factory: { _ in backend },
                                         validateFile: { _ in try await gate.wait() })
        let operation = Task { try await service.transcribe(selected, localeIdentifier: "en_US") }
        while !(await gate.entered) { await Task.yield() }
        service.cancel()
        await gate.releaseWithError()
        do { _ = try await operation.value; XCTFail("cancelled validation succeeded") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .cancelled) }
        XCTAssertEqual(backend.starts, 0)
        XCTAssertEqual(service.phase, .cancelled)
    }
    @MainActor func testAuthorizationRevokedDuringValidation() async throws {
        let permission = AuthorizationFixture(), backend = FakeBackend()
        let service = OfflineTranscriber(authorization: { permission.status }, factory: { _ in backend },
                                         validateFile: { _ in await MainActor.run { permission.status = .denied } })
        do { _ = try await service.transcribe(selected, localeIdentifier: "en_US"); XCTFail("revoked permission ignored") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .authorizationRequired(.denied)) }
        XCTAssertEqual(backend.starts, 0)
    }
    @MainActor func testInvalidTimeoutAndAlreadyCancelledTaskNeverStart() async throws {
        let backend = FakeBackend(), reads = Counter(), service = engine(backend, reads: reads)
        for timeout in [0.0, -1.0, Double.nan, Double.infinity, 3601] {
            do { _ = try await service.transcribe(selected, localeIdentifier: "en_US", timeoutSeconds: timeout); XCTFail("invalid timeout admitted") }
            catch { XCTAssertEqual(error as? TranscriptionFailure, .invalidTimeout) }
        }
        let cancelled = Task { try await service.transcribe(selected, localeIdentifier: "en_US") }
        cancelled.cancel()
        do { _ = try await cancelled.value; XCTFail("already-cancelled request admitted") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .cancelled) }
        let count = await reads.value
        XCTAssertEqual(count, 0); XCTAssertEqual(backend.starts, 0)
    }
    func testUserSelectionRejectsRemoteAndWrongExtension() throws {
        XCTAssertThrowsError(try UserSelectedWAV(userSelectedURL: URL(string: "https://example.invalid/audio.wav")!))
        XCTAssertThrowsError(try UserSelectedWAV(userSelectedURL: URL(fileURLWithPath: "/fixture.mp3")))
    }
    func testRealWAVValidationAndOfflineRequestUseTemporaryFixtureOnly() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let wav = root.appendingPathComponent("fixture.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
        do {
            let writer = try AVAudioFile(forWriting: wav, settings: format.settings)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
            buffer.frameLength = 480
            for i in 0..<480 { buffer.floatChannelData![0][i] = 0 }
            try writer.write(from: buffer)
        }
        try await validateSelectedWAV(UserSelectedWAV(userSelectedURL: wav))
        let request = offlineRequest(wav)
        XCTAssertTrue(request.requiresOnDeviceRecognition)
        XCTAssertFalse(request.shouldReportPartialResults)
        XCTAssertEqual(request.url, wav)
        let invalid = root.appendingPathComponent("invalid.wav")
        try Data("not WAV".utf8).write(to: invalid)
        do { try await validateSelectedWAV(UserSelectedWAV(userSelectedURL: invalid)); XCTFail("malformed WAV accepted") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .invalidWAV) }
        let link = root.appendingPathComponent("link.wav")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: wav)
        do { try await validateSelectedWAV(UserSelectedWAV(userSelectedURL: link)); XCTFail("symlink accepted") }
        catch { XCTAssertEqual(error as? TranscriptionFailure, .invalidWAV) }
    }
}
