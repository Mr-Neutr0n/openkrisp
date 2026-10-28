import AppKit
import Combine
import IOKit
import IOKit.pwr_mgt

enum NativePowerEvent: Equatable { case suspend, resume, powerOff }

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
    private let emit: (NativePowerEvent) -> Void
    private var port: IONotificationPortRef?
    private var rootConnection: io_connect_t = 0
    private var notifier: io_object_t = 0
    private var source: CFRunLoopSource?
    private var powerOffObserver: NSObjectProtocol?

    init(emit: @escaping (NativePowerEvent) -> Void) { self.emit = emit }

    func start() {
        guard !monitoring else { return }
        error = nil
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
            stop(); error = "System sleep/wake notifications are unavailable. Simulated power controls remain available."
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

    func stop() {
        if let observer = powerOffObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        powerOffObserver = nil
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        if notifier != 0 { _ = IODeregisterForSystemPower(&notifier); notifier = 0 }
        if rootConnection != 0 { IOServiceClose(rootConnection); rootConnection = 0 }
        if let port { IONotificationPortDestroy(port) }
        port = nil; monitoring = false
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
