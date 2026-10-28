import XCTest
import IOKit
@testable import LabVoice

@MainActor final class NativePowerNotificationsTests: XCTestCase {
    func testSleepAcknowledgesBeforeDispatchAndWakeOnlyAtCompletion() {
        var calls: [String] = []
        func deliver(_ message: UInt32) {
            NativePowerNotifications.dispatch(message: message, notificationID: 42,
                acknowledge: { calls.append("ack \($0)") }, emit: { calls.append(String(describing: $0)) })
        }
        deliver(0xe0000270)
        XCTAssertEqual(calls, ["ack 42"])
        calls = []; deliver(0xe0000280)
        XCTAssertEqual(calls, ["ack 42", "suspend"])
        calls = []; deliver(0xe0000320) // Will-power-on is deliberately ignored.
        XCTAssertTrue(calls.isEmpty)
        deliver(0xe0000300)
        XCTAssertEqual(calls, ["resume"])
    }
    func testUnknownNotificationDoesNotAcknowledgeOrDispatch() {
        NativePowerNotifications.dispatch(message: 0, notificationID: 123,
            acknowledge: { _ in XCTFail("Unexpected acknowledgement") }, emit: { _ in XCTFail("Unexpected event") })
    }
}

// Opt in on a real local Mac. This attaches a listener only. It requests no
// sleep, wake, power-off, permission, capture or playback, and posts no event.
@MainActor final class NativePowerRegistrationIntegrationTests: XCTestCase {
    func testRealRegistrationIsIdempotentAndNativeCleanupSucceeds() throws {
        guard ProcessInfo.processInfo.environment["LABVOICE_TEST_NATIVE_POWER_REGISTRATION"] == "1" else {
            throw XCTSkip("Set LABVOICE_TEST_NATIVE_POWER_REGISTRATION=1 to attach and detach the native listener.")
        }
        var delivered: [NativePowerEvent] = []
        let listener = NativePowerNotifications { delivered.append($0) }
        listener.start()
        let before = listener.registration
        // Always attempt teardown exactly once, even if registration assertions fail.
        defer {
            let cleanup = listener.stop()
            print("Native power registration: \(before)")
            print("Native power cleanup: \(cleanup), observed callbacks: \(delivered)")
            XCTAssertEqual(cleanup.deregisterStatus, Int64(kIOReturnSuccess))
            XCTAssertEqual(cleanup.closeStatus, Int64(kIOReturnSuccess))
            XCTAssertTrue(cleanup.sourceWasInstalled); XCTAssertTrue(cleanup.sourceRemoved)
            XCTAssertTrue(cleanup.observerRemovalRequested); XCTAssertTrue(cleanup.portDestroyRequested)
            XCTAssertTrue(cleanup.complete); XCTAssertFalse(listener.monitoring)
            let after = listener.registration
            XCTAssertEqual(after.connection, 0); XCTAssertEqual(after.notifier, 0)
            XCTAssertFalse(after.hasPort); XCTAssertFalse(after.hasSource)
            XCTAssertFalse(after.sourceInstalled); XCTAssertFalse(after.hasPowerOffObserver)
        }
        XCTAssertNil(listener.error)
        XCTAssertTrue(listener.monitoring)
        XCTAssertNotEqual(before.connection, 0); XCTAssertNotEqual(before.notifier, 0)
        XCTAssertTrue(before.hasPort); XCTAssertTrue(before.hasSource)
        XCTAssertTrue(before.sourceInstalled); XCTAssertTrue(before.hasPowerOffObserver)
        listener.start()
        XCTAssertEqual(listener.registration, before)
    }
}
