import AppKit
import Combine
import IOKit
import IOKit.pwr_mgt

enum NativePowerEvent: Equatable { case suspend, resume, powerOff }

struct NativePowerRegistration: Equatable {
    let connection: UInt32
    let notifier: UInt32
    let hasPort: Bool
    let hasSource: Bool
    let sourceInstalled: Bool
    let hasPowerOffObserver: Bool
}
struct NativePowerCleanupReport: Equatable {
    let sourceWasInstalled: Bool
    let sourceRemoved: Bool
    let deregisterStatus: Int64?
    let closeStatus: Int64?
    let portDestroyRequested: Bool
    let observerRemovalRequested: Bool
    let complete: Bool
}

/// Main-run-loop registration mirrors the recovered native power source. This
/// listens for notifications; it never requests sleep, wake or power off.
@MainActor final class NativePowerNotifications: ObservableObject {
    // IOKit's compound C macros are not imported by Swift. Values are bound to
    // IOMessage.h and the recovered arm64 callback in sleep-wake-findings.md.
    static let canSleepMessage: UInt32 = 0xe0000270
    static let willSleepMessage: UInt32 = 0xe0000280
    static let hasPoweredOnMessage: UInt32 = 0xe0000300
    static let shared = NativePowerNotifications { event in
        switch event {
        case .suspend: AppPowerLifecycle.shared.request(.suspend)
        case .resume: AppPowerLifecycle.shared.request(.resume)
        case .powerOff: NSApp.terminate(nil)
        }
    }
    @Published private(set) var error: String?
    @Published private(set) var monitoring = false
    @Published private(set) var cleanupReport: NativePowerCleanupReport?
    private var registrationLifetime: NativePowerNotifications?
    private let emit: (NativePowerEvent) -> Void
    private var port: IONotificationPortRef?
    private var rootConnection: io_connect_t = 0
    private var notifier: io_object_t = 0
    private var source: CFRunLoopSource?
    private var powerOffObserver: NSObjectProtocol?

    init(emit: @escaping (NativePowerEvent) -> Void) { self.emit = emit }
    var registration: NativePowerRegistration {
        .init(connection: rootConnection, notifier: notifier, hasPort: port != nil, hasSource: source != nil,
              sourceInstalled: source.map { CFRunLoopContainsSource(CFRunLoopGetMain(), $0, .commonModes) } ?? false,
              hasPowerOffObserver: powerOffObserver != nil)
    }
    private var hasResources: Bool { rootConnection != 0 || notifier != 0 || port != nil || source != nil || powerOffObserver != nil }

    func start() {
        guard !monitoring else { return }
        guard !hasResources else { error = "The previous power listener has not confirmed cleanup. Stop it before registering again."; return }
        error = nil; cleanupReport = nil
        // Native refcon is unretained. Keep this object alive through any failed
        // teardown, including an opt-in test whose local reference goes away.
        registrationLifetime = self
        rootConnection = IORegisterForSystemPower(Unmanaged.passUnretained(self).toOpaque(), &port, { refcon, _, message, argument in
            guard let refcon else { return }
            let observer = Unmanaged<NativePowerNotifications>.fromOpaque(refcon).takeUnretainedValue()
            // The sole delivery source is registered on the main run loop below.
            MainActor.assumeIsolated {
                NativePowerNotifications.dispatch(message: message, notificationID: Int(bitPattern: argument), acknowledge: { notificationID in
                    let result = IOAllowPowerChange(observer.rootConnection, notificationID)
                    if result != kIOReturnSuccess { observer.error = "Could not acknowledge the system power notification (\(result))." }
                }, emit: observer.emit)
            }
        }, &notifier)
        guard rootConnection != 0, let port,
              let value = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() else {
            let cleanup = stop()
            error = "System sleep/wake notifications are unavailable. Simulated power controls remain available." +
                (cleanup.complete ? "" : " Listener cleanup is incomplete.")
            return
        }
        source = value
        CFRunLoopAddSource(CFRunLoopGetMain(), value, .commonModes)
        powerOffObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willPowerOffNotification,
                                                                              object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.emit(.powerOff) }
        }
        monitoring = true
    }

    @discardableResult func stop() -> NativePowerCleanupReport {
        let observerRemovalRequested = powerOffObserver != nil
        if let observer = powerOffObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        powerOffObserver = nil
        let sourceWasInstalled = registration.sourceInstalled
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        let sourceRemoved = !registration.sourceInstalled
        var deregisterStatus: Int64?, closeStatus: Int64?
        if notifier != 0 {
            let previous = notifier
            let status = IODeregisterForSystemPower(&notifier)
            deregisterStatus = Int64(status)
            if status == kIOReturnSuccess { notifier = 0 }
            else if notifier == 0 { notifier = previous }
        }
        // A failed deregistration retains native resources for an explicit retry.
        // Never destroy a port while its notifier may still deliver callbacks.
        if notifier == 0, rootConnection != 0 {
            let status = IOServiceClose(rootConnection)
            closeStatus = Int64(status)
            if status == kIOReturnSuccess { rootConnection = 0 }
        }
        var portDestroyRequested = false
        if sourceRemoved, notifier == 0, rootConnection == 0 {
            if let port { IONotificationPortDestroy(port); portDestroyRequested = true }
            port = nil; source = nil
        }
        let complete = !hasResources
        monitoring = registration.sourceInstalled
        let report = NativePowerCleanupReport(sourceWasInstalled: sourceWasInstalled, sourceRemoved: sourceRemoved,
            deregisterStatus: deregisterStatus, closeStatus: closeStatus, portDestroyRequested: portDestroyRequested,
            observerRemovalRequested: observerRemovalRequested, complete: complete)
        cleanupReport = report
        if complete { registrationLifetime = nil; error = nil }
        else { error = "Power listener cleanup is incomplete. Native resources remain owned; retry Stop before registering again." }
        return report
    }

    /// Acknowledge sleep before event delivery, as the native source does. Wake
    /// completion needs no acknowledgement. Will-power-on is not Resume.
    static func dispatch(message: UInt32, notificationID: Int,
                         acknowledge: (Int) -> Void, emit: (NativePowerEvent) -> Void) {
        switch message {
        case canSleepMessage: acknowledge(notificationID)
        case willSleepMessage: acknowledge(notificationID); emit(.suspend)
        case hasPoweredOnMessage: emit(.resume)
        default: break
        }
    }
}
