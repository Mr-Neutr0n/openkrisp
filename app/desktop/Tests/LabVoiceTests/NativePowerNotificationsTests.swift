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
