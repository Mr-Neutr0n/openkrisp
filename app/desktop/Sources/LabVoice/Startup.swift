import Foundation
import Combine
import AppKit
import ServiceManagement

enum StartupStatus: Equatable, Sendable {
    case unknown, unavailable, notRegistered, enabled, requiresApproval, notFound
    var registered: Bool { self == .enabled || self == .requiresApproval }
    var message: String {
        switch self {
        case .unknown: return "Launch at login status is not available. Refresh to check."
        case .unavailable: return "Launch at login requires macOS 13 or later."
        case .notRegistered: return "Lab Voice is not registered to launch at login."
        case .enabled: return "Lab Voice is enabled to launch at login."
        case .requiresApproval: return "Registration requires approval in System Settings > General > Login Items."
        case .notFound: return "macOS could not find the login service. Launch at login is not confirmed."
        }
    }
}
protocol StartupServing: Sendable {
    func status() async throws -> StartupStatus
    func setEnabled(_ enabled: Bool) async throws
}

actor NativeStartupService: StartupServing {
    func status() -> StartupStatus {
        guard #available(macOS 13, *) else { return .unavailable }
        switch SMAppService.mainApp.status {
        case .notRegistered: return .notRegistered
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .unknown
        }
    }
    // Called only by the controller's explicit user action, never by refresh or initialization.
    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13, *) else { throw StartupError.unavailable }
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
    }
}
enum StartupError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Launch at login requires macOS 13 or later." }
}

@MainActor final class StartupController: ObservableObject {
    static let shared = StartupController(service: NativeStartupService())
    @Published private(set) var status: StartupStatus = .unknown
    @Published private(set) var changing = false
    @Published private(set) var error: String?
    private let service: any StartupServing
    private var generation = UUID()
    private var activation: AnyCancellable?
    var canChange: Bool { !changing && status != .unknown && status != .unavailable }
    init(service: any StartupServing, notifications: NotificationCenter = .default) {
        self.service = service
        activation = notifications.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in Task { await self?.refresh() } }
    }
    func refresh() async {
        guard !changing else { return }
        let token = UUID(); generation = token
        do {
            let next = try await service.status()
            guard generation == token else { return }
            status = next; error = nil
        } catch {
            guard generation == token else { return }
            status = .unknown; self.error = "Cannot read launch at login status: \(error.localizedDescription)"
        }
    }
    func setEnabled(_ enabled: Bool) async {
        guard canChange else { return }
        // The OS is the source of truth. No desired value is saved in preferences.
        let token = UUID(); generation = token; changing = true; error = nil
        defer { if generation == token { changing = false } }
        var failure: Error?
        do { try await service.setEnabled(enabled) } catch { failure = error }
        do {
            let next = try await service.status()
            guard generation == token else { return }
            status = next
            if let failure { error = "Cannot change launch at login: \(failure.localizedDescription)" }
        } catch {
            guard generation == token else { return }
            status = .unknown
            self.error = failure == nil ? "Launch at login status could not be confirmed. Refresh to check." : "Cannot change or confirm launch at login: \(failure!.localizedDescription)"
        }
    }
}
