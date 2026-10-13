import XCTest
import Foundation
import LocalTranscription
@testable import LabVoice

@MainActor final class ImportTranscriptionTests: XCTestCase {
    private let file = URL(fileURLWithPath: "/not-opened/user-selected.wav")
    private func ready(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Expected transcription transition did not arrive")
    }
    private func text(_ value: String) -> OfflineTranscript {
        OfflineTranscript(text: value, localeIdentifier: "en_US", segments: [])
    }
    func testPermissionStartsOnlyAfterActionAndCancelDuringPromptDoesNotRecognize() async throws {
        var requests = 0
        var recognized = 0
        var cancelled = 0
        var permission: CheckedContinuation<SpeechAuthorization, Error>?
        let flow = ImportTranscription(authorization: { .notDetermined }, requestAuthorization: {
            requests += 1
            return try await withCheckedThrowingContinuation { permission = $0 }
        }, recognize: { _, _ in recognized += 1; return self.text("unexpected") }, cancelRecognition: { cancelled += 1 })
        XCTAssertEqual(requests, 0)
        flow.start(file: file, locale: "en_US")
        try await ready { requests == 1 }
        XCTAssertTrue(flow.busy)
        flow.cancel()
        permission?.resume(returning: .authorized)
        try await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertFalse(flow.busy)
        XCTAssertEqual(recognized, 0)
        XCTAssertEqual(cancelled, 1)
        XCTAssertNil(flow.completedText)
    }
    func testSelectedFileAndExactLocaleReachRecognitionWithoutNewPrompt() async throws {
        var requests = 0
        var selectedURL: URL?
        var selectedLocale: String?
        let flow = ImportTranscription(authorization: { .authorized }, requestAuthorization: {
            requests += 1; return .authorized
        }, recognize: { selected, locale in
            selectedURL = selected.url; selectedLocale = locale
            return self.text("Review this transcript")
        }, cancelRecognition: { })
        flow.start(file: file, locale: "fr_CA")
        try await ready { !flow.busy }
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(selectedURL, file)
        XCTAssertEqual(selectedLocale, "fr_CA")
        XCTAssertEqual(flow.completedText, "Review this transcript")
    }
    func testOldFileCompletionCannotOverwriteNewOperation() async throws {
        var pending: [CheckedContinuation<OfflineTranscript, Error>] = []
        let flow = ImportTranscription(authorization: { .authorized }, requestAuthorization: { .authorized }, recognize: { _, _ in
            try await withCheckedThrowingContinuation { pending.append($0) }
        }, cancelRecognition: { })
        flow.start(file: file, locale: "en_US")
        try await ready { pending.count == 1 }
        flow.cancel()
        flow.start(file: URL(fileURLWithPath: "/not-opened/other.wav"), locale: "de_DE")
        try await ready { pending.count == 2 }
        pending[0].resume(returning: text("Wrong file"))
        try await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertTrue(flow.busy)
        XCTAssertNil(flow.completedText)
        pending[1].resume(returning: text("New file"))
        try await ready { !flow.busy }
        XCTAssertEqual(flow.completedText, "New file")
    }
    func testDeniedPermissionNeverStartsRecognition() async throws {
        var requests = 0
        var recognized = 0
        let flow = ImportTranscription(authorization: { .denied }, requestAuthorization: { requests += 1; return .denied }, recognize: { _, _ in recognized += 1; return self.text("unexpected") }, cancelRecognition: { })
        flow.start(file: file, locale: "en_US")
        try await ready { !flow.busy }
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(recognized, 0)
        XCTAssertNil(flow.completedText)
        XCTAssertNotNil(flow.error)
    }
    func testUnsupportedOfflineLanguagePublishesErrorWithoutReplacement() async throws {
        let flow = ImportTranscription(authorization: { .authorized }, requestAuthorization: { .authorized }, recognize: { _, _ in
            throw TranscriptionFailure.onDeviceRecognitionUnsupported
        }, cancelRecognition: { })
        flow.start(file: file, locale: "fr_CA")
        try await ready { !flow.busy }
        XCTAssertNil(flow.completedText)
        XCTAssertTrue(flow.error?.contains("No server recognition was used") == true)
    }
    func testEmptyResultDoesNotReplaceExistingText() async throws {
        let flow = ImportTranscription(authorization: { .authorized }, requestAuthorization: { .authorized }, recognize: { _, _ in self.text("  \n") }, cancelRecognition: { })
        flow.start(file: file, locale: "en_US")
        try await ready { !flow.busy }
        XCTAssertNil(flow.completedText)
        XCTAssertTrue(flow.error?.contains("current transcript is unchanged") == true)
    }
    func testCancelBeforeTaskStartsRequestsNoPermission() async throws {
        var requests = 0
        let flow = ImportTranscription(authorization: { .notDetermined }, requestAuthorization: { requests += 1; return .authorized }, recognize: { _, _ in self.text("unexpected") }, cancelRecognition: { })
        flow.start(file: file, locale: "en_US")
        flow.cancel()
        try await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertEqual(requests, 0)
        XCTAssertNil(flow.completedText)
        XCTAssertFalse(flow.busy)
    }
}
