import XCTest
@testable import LabVoice

private actor DiagnosticCapture {
    var reports: [DiagnosticReport] = []
    var samples: [URL?] = []
    var fail = false
    func setFailure(_ value: Bool = true) { fail = value }
    func write(_ report: DiagnosticReport, _ url: URL, _ sample: URL?) throws {
        if fail { throw CocoaError(.fileWriteNoPermission) }
        reports.append(report); samples.append(sample)
    }
    func selectedSamples() -> [URL?] { samples }
    func data() throws -> [Data] { try reports.map { try JSONEncoder().encode($0) } }
}

@MainActor final class DiagnosticsControllerTests: XCTestCase {
    private func snapshot() -> DiagnosticStatusSnapshot {
        .init(audio: .running, recording: .paused, library: .ready, microphoneTest: .idle, controls: .pending, sessionCount: 3)
    }
    func testExplicitExportCapturesSnapshotAndOptionalSystemMetadata() async throws {
        let capture = DiagnosticCapture()
        let log = DiagnosticEventLog(maximumEvents: 8)
        log.append(component: .audio, code: .started, severity: .info)
        let model = DiagnosticsController(snapshot: snapshot, log: log, export: { report, url, sample in try await capture.write(report, url, sample) })
        model.category = .audio; model.description = "Mute update delayed"
        let captured = try await capture.data()
        XCTAssertTrue(captured.isEmpty)
        await model.save(to: URL(fileURLWithPath: "/unused-selected-report.json"))
        XCTAssertFalse(model.saving); XCTAssertFalse(model.failed)
        let first = String(decoding: try await capture.data()[0], as: UTF8.self)
        XCTAssertTrue(first.contains("Mute update delayed")); XCTAssertTrue(first.contains("running")); XCTAssertTrue(first.contains("pending"))
        XCTAssertFalse(first.contains("osVersion")); XCTAssertFalse(first.contains("/unused"))
        let firstSamples = await capture.selectedSamples()
        XCTAssertNil(firstSamples[0])
        model.selectedSample = URL(fileURLWithPath: "/explicit-selected-sample.wav")
        model.includeOccurrenceDate = true
        model.occurrenceDate = Date(timeIntervalSince1970: 1234567890)
        model.includeSystemInformation = true
        await model.save(to: URL(fileURLWithPath: "/unused-selected-report-2.json"))
        let second = String(decoding: try await capture.data()[1], as: UTF8.self)
        XCTAssertTrue(second.contains("occurredAt"))
        XCTAssertTrue(second.contains("osVersion")); XCTAssertTrue(second.contains("arm64"))
        let samples = await capture.selectedSamples()
        XCTAssertEqual(samples[1], model.selectedSample)
        XCTAssertFalse(second.contains("explicit-selected-sample"))
    }
    func testExportFailureIsVisibleAndRetryDoesNotClaimEarlierSuccess() async throws {
        let capture = DiagnosticCapture(); await capture.setFailure()
        let model = DiagnosticsController(snapshot: snapshot, log: DiagnosticEventLog(), export: { report, url, sample in try await capture.write(report, url, sample) })
        await model.save(to: URL(fileURLWithPath: "/unused.json"))
        XCTAssertTrue(model.failed); XCTAssertFalse(model.saving)
        XCTAssertTrue(model.message?.contains("Cannot save") == true)
        let captured = try await capture.data()
        XCTAssertTrue(captured.isEmpty)
        await capture.setFailure(false)
        await model.save(to: URL(fileURLWithPath: "/unused-retry"))
        XCTAssertFalse(model.failed)
        XCTAssertTrue(model.message?.contains("saved") == true)
        let retried = try await capture.data()
        XCTAssertEqual(retried.count, 1)
    }
    func testDescriptionUsesTheCoreUTF8Bound() {
        let model = DiagnosticsController(snapshot: snapshot, log: DiagnosticEventLog(), export: { _, _, _ in })
        model.description = String(repeating: "👩🏽‍💻", count: 2000)
        XCTAssertLessThanOrEqual(model.description.utf8.count, 8192)
        XCTAssertFalse(model.description.contains("�"))
    }
    func testControllerLifecycleProducesFixedEventsWithoutPrivateMessages() async throws {
        let log = DiagnosticEventLog.shared
        let model = ImportTranscription(authorization: { .denied }, requestAuthorization: { .denied }, recognize: { _, _ in throw CocoaError(.userCancelled) }, cancelRecognition: {})
        model.start(file: URL(fileURLWithPath: "/private/not-a-readable-recording.wav"), locale: "en_US")
        for _ in 0..<1000 { if !model.busy { break }; await Task.yield() }
        XCTAssertFalse(model.busy)
        let data = try JSONEncoder().encode(log.snapshot())
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("transcription")); XCTAssertTrue(text.contains("operationFailed"))
        XCTAssertFalse(text.contains("not-a-readable-recording")); XCTAssertFalse(text.contains("readable, finalized"))
    }
}
