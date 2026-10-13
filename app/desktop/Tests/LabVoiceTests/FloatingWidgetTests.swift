import XCTest
import Foundation
@testable import LabVoice

@MainActor private final class FixtureWidgetPanel: FloatingWidgetPanel {
    var didClose: (() -> Void)?
    var shows = 0, hides = 0
    func show() { shows += 1 }
    func hide() { hides += 1 }
    func close() { didClose?() }
}

@MainActor final class FloatingWidgetTests: XCTestCase {
    private func defaults() throws -> (UserDefaults, String) {
        let name = "LabVoice-widget-fixture-" + UUID().uuidString
        return (try XCTUnwrap(UserDefaults(suiteName: name)), name)
    }
    private func audio() -> AudioRouteController {
        AudioRouteController(readInventory: { throw AudioHelperError.invalidInventory },
            authorization: { XCTFail("Widget requested audio authorization"); return .denied },
            requestAuthorization: { XCTFail("Widget requested an OS prompt"); return false },
            factory: { XCTFail("Widget launched an audio helper"); throw AudioHelperError.missingHelper })
    }
    func testDefaultHiddenAndSinglePanelCloseShowReuseWithSharedState() throws {
        let (preferences, name) = try defaults()
        defer { preferences.removePersistentDomain(forName: name) }
        let route = audio(), panel = FixtureWidgetPanel()
        var constructions = 0
        let widget = FloatingWidgetController(audio: route, defaults: preferences) { received in
            XCTAssertTrue(received === route)
            constructions += 1; return panel
        }
        XCTAssertFalse(widget.isVisible); widget.restoreVisibility(); XCTAssertEqual(constructions, 0)
        route.setMicrophoneMuted(true)
        widget.show(); widget.show()
        XCTAssertEqual(constructions, 1); XCTAssertTrue(widget.audio === route)
        XCTAssertTrue(widget.audio.desiredControls.microphone.muted)
        XCTAssertEqual(route.phase, .idle); XCTAssertEqual(route.recording.phase, .idle)
        panel.close(); XCTAssertFalse(widget.isVisible); XCTAssertEqual(panel.hides, 1)
        XCTAssertFalse(preferences.bool(forKey: FloatingWidgetController.preferenceKey))
        widget.show(); XCTAssertEqual(constructions, 1); XCTAssertEqual(panel.shows, 3)
        XCTAssertTrue(route.desiredControls.microphone.muted)
        XCTAssertEqual(route.phase, .idle)
    }
    func testPersistedVisibilityRestoresWithoutStartingAudioOrRecording() throws {
        let (preferences, name) = try defaults()
        defer { preferences.removePersistentDomain(forName: name) }
        let route = audio(), first = FixtureWidgetPanel(), second = FixtureWidgetPanel()
        let original = FloatingWidgetController(audio: route, defaults: preferences) { _ in first }
        original.setVisible(true)
        var made = 0
        let restored = FloatingWidgetController(audio: route, defaults: preferences) { _ in made += 1; return second }
        XCTAssertTrue(restored.isVisible); XCTAssertEqual(made, 0)
        restored.restoreVisibility(); XCTAssertEqual(made, 1); XCTAssertEqual(second.shows, 1)
        restored.setVisible(false); XCTAssertEqual(second.hides, 1)
        XCTAssertEqual(route.phase, .idle); XCTAssertNil(route.confirmedControls)
        XCTAssertEqual(route.recording.phase, .idle); XCTAssertFalse(route.recording.busy)
    }
    func testCloseLeavesPendingRecordingOwnedBySharedController() async throws {
        let (preferences, name) = try defaults()
        defer { preferences.removePersistentDomain(forName: name) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = RecordingController(storage: RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: root.appendingPathComponent("sessions")))
        let route = AudioRouteController(readInventory: { throw AudioHelperError.invalidInventory },
            authorization: { XCTFail("Unexpected permission lookup"); return .denied },
            requestAuthorization: { XCTFail("Unexpected permission prompt"); return false },
            factory: { XCTFail("Unexpected helper launch"); throw AudioHelperError.missingHelper }, recording: recorder)
        let id = UUID()
        var commands = 0
        recorder.attach(operationID: id) { _ in commands += 1 }
        recorder.start()
        for _ in 0..<1000 {
            if commands == 1 { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertEqual(recorder.phase, .starting)
        let panel = FixtureWidgetPanel()
        let widget = FloatingWidgetController(audio: route, defaults: preferences) { _ in panel }
        widget.show(); panel.close()
        XCTAssertFalse(widget.isVisible)
        XCTAssertTrue(widget.audio.recording === recorder)
        XCTAssertEqual(recorder.phase, .starting); XCTAssertTrue(recorder.busy)
        XCTAssertEqual(commands, 1) // Hide did not send a stop command.
        await recorder.helperExited(operationID: id)
    }

}
