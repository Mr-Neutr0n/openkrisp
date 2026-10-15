import XCTest
import AppKit
@testable import LabVoice

private actor FakeStartupService: StartupServing {
    var current: StartupStatus
    var afterEnable: StartupStatus = .enabled
    var actionError = false
    var readError = false
    var reads = 0
    var writes: [Bool] = []
    var suspendRead = false
    var suspendWrite = false
    var readWait: CheckedContinuation<StartupStatus, Never>?
    var writeWait: CheckedContinuation<Void, Never>?
    let onRead: (() -> Void)?
    init(_ current: StartupStatus, onRead: (() -> Void)? = nil) { self.current = current; self.onRead = onRead }
    func configure(current: StartupStatus? = nil, approval: Bool = false, actionError: Bool = false, readError: Bool = false) {
        if let current { self.current = current }
        afterEnable = approval ? .requiresApproval : .enabled
        self.actionError = actionError; self.readError = readError
    }
    func status() async throws -> StartupStatus {
        reads += 1; onRead?()
        if readError { throw CocoaError(.fileReadUnknown) }
        if suspendRead { suspendRead = false; return await withCheckedContinuation { readWait = $0 } }
        return current
    }
    func setEnabled(_ enabled: Bool) async throws {
        writes.append(enabled)
        if suspendWrite { await withCheckedContinuation { writeWait = $0 } }
        if actionError { throw CocoaError(.featureUnsupported) }
        current = enabled ? afterEnable : .notRegistered
    }
    func counts() -> (Int, [Bool]) { (reads, writes) }
    func holdRead() { suspendRead = true }
    func holdWrite() { suspendWrite = true }
    func reading() -> Bool { readWait != nil }
    func writing() -> Bool { writeWait != nil }
    func releaseRead(_ result: StartupStatus) { readWait?.resume(returning: result); readWait = nil }
    func releaseWrite() { suspendWrite = false; writeWait?.resume(); writeWait = nil }
}

@MainActor final class StartupTests: XCTestCase {
    func testInitializationAndRefreshNeverRegisterAndAllOSStatesRemainDistinct() async {
        let service = FakeStartupService(.notRegistered)
        let model = StartupController(service: service, notifications: NotificationCenter())
        let initial = await service.counts()
        XCTAssertEqual(initial.0, 0); XCTAssertTrue(initial.1.isEmpty)
        for state in [StartupStatus.notRegistered, .enabled, .requiresApproval, .notFound, .unavailable, .unknown] {
            await service.configure(current: state)
            await model.refresh()
            XCTAssertEqual(model.status, state)
            XCTAssertEqual(model.status.registered, state == .enabled || state == .requiresApproval)
        }
        await model.setEnabled(true) // Unknown status is not an admission to mutate OS state.
        await service.configure(current: .unavailable); await model.refresh(); await model.setEnabled(true)
        let final = await service.counts(); XCTAssertTrue(final.1.isEmpty)
        XCTAssertFalse(model.canChange)
    }
    func testExplicitActionsRereadActualStatusIncludingApprovalAndUnregister() async {
        let service = FakeStartupService(.notRegistered)
        let model = StartupController(service: service, notifications: NotificationCenter())
        await model.refresh()
        await service.configure(approval: true)
        await model.setEnabled(true)
        XCTAssertEqual(model.status, .requiresApproval); XCTAssertNil(model.error)
        await model.setEnabled(false)
        XCTAssertEqual(model.status, .notRegistered)
        let calls = await service.counts(); XCTAssertEqual(calls.1, [true, false])
    }
    func testActionAndReadFailuresDoNotInventSuccessAndRefreshRecovers() async {
        let service = FakeStartupService(.notRegistered)
        let model = StartupController(service: service, notifications: NotificationCenter())
        await model.refresh()
        await service.configure(actionError: true)
        await model.setEnabled(true)
        XCTAssertEqual(model.status, .notRegistered); XCTAssertNotNil(model.error); XCTAssertFalse(model.changing)
        await service.configure(current: .requiresApproval, actionError: true)
        await model.setEnabled(true)
        XCTAssertEqual(model.status, .requiresApproval); XCTAssertNotNil(model.error)
        await service.configure(readError: true)
        await model.refresh()
        XCTAssertEqual(model.status, .unknown); XCTAssertNotNil(model.error)
        await service.configure(current: .enabled)
        await model.refresh()
        XCTAssertEqual(model.status, .enabled); XCTAssertNil(model.error)
    }
    func testBusyActionRejectsDuplicateAndLateRefreshCannotReplaceItsStatus() async {
        let service = FakeStartupService(.notRegistered)
        let model = StartupController(service: service, notifications: NotificationCenter())
        await model.refresh(); await service.holdRead()
        let old = Task { await model.refresh() }
        for _ in 0..<1000 { if await service.reading() { break }; await Task.yield() }
        let reading = await service.reading(); XCTAssertTrue(reading)
        await service.holdWrite()
        let change = Task { await model.setEnabled(true) }
        for _ in 0..<1000 { if await service.writing() { break }; await Task.yield() }
        XCTAssertTrue(model.changing); XCTAssertFalse(model.canChange)
        await model.setEnabled(false); await model.refresh()
        await service.releaseWrite(); await change.value
        XCTAssertEqual(model.status, .enabled)
        await service.releaseRead(.notRegistered); await old.value
        XCTAssertEqual(model.status, .enabled)
        let calls = await service.counts(); XCTAssertEqual(calls.1, [true])
    }
    func testActivationNotificationRefreshesOnlyStatus() async {
        let read = expectation(description: "Activation reads OS status")
        let service = FakeStartupService(.enabled, onRead: { read.fulfill() })
        let notifications = NotificationCenter()
        let model = StartupController(service: service, notifications: notifications)
        notifications.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await fulfillment(of: [read], timeout: 2)
        for _ in 0..<1000 { if model.status == .enabled { break }; await Task.yield() }
        XCTAssertEqual(model.status, .enabled)
        let calls = await service.counts(); XCTAssertTrue(calls.1.isEmpty)
    }
}
