import Foundation
import Combine
import SwiftUI

// Synchronous admission is also checked inside playback actors immediately before
// producing output. Epoch changes invalidate queued work across suspend/resume.
final class PowerAdmission: @unchecked Sendable {
    static let shared = PowerAdmission()
    private let lock = NSLock()
    private var open = true
    private var epoch = UUID()
    var allowed: Bool { lock.lock(); defer { lock.unlock() }; return open }
    var revision: UUID { lock.lock(); defer { lock.unlock() }; return epoch }
    func setAllowed(_ value: Bool) { lock.lock(); open = value; epoch = UUID(); lock.unlock() }
}
enum AppPowerEvent { case suspend, resume }
struct PowerSuspendResult { let failure: String?; let blocking: Bool
    static let stopped = PowerSuspendResult(failure: nil, blocking: false)
}
enum AppPowerState: Equatable { case active, suspending, suspended, resuming, failed }

@MainActor final class AppPowerLifecycle: ObservableObject {
    static let shared = AppPowerLifecycle()
    @Published private(set) var state: AppPowerState = .active
    @Published private(set) var error: String?
    private var desired: AppPowerEvent?
    private var task: Task<Void, Never>?
    private var cleanupFailed = false
    private var retainedWarning: String?
    private let revoke: () -> Void
    private let suspendResources: () async -> PowerSuspendResult
    private let resumeResources: () async -> String?
    private struct LibraryReference { weak var model: LibraryModel? }
    private var libraries: [LibraryReference] = []
    private struct TranscriptionReference { weak var model: ImportTranscription? }
    private var transcriptions: [TranscriptionReference] = []
    func register(_ transcription: ImportTranscription) {
        transcriptions.removeAll { $0.model == nil }
        transcriptions.append(.init(model: transcription))
    }
    var admissionOpen: Bool { PowerAdmission.shared.allowed }
    var transitioning: Bool { state == .suspending || state == .resuming }
    init(revoke: (() -> Void)? = nil, suspend: (() async -> PowerSuspendResult)? = nil,
         resume: (() async -> String?)? = nil) {
        self.revoke = revoke ?? {
            AudioRouteController.shared.revokeForPowerEvent()
            MicrophoneTestController.shared.revokeForPowerEvent()
            AudioCaptureAdmission.shared.objectWillChange.send()
        }
        suspendResources = suspend ?? {
            let test = MicrophoneTestController.shared
            let testStopped = await test.cancelAndCleanup()
            let routeFailure = await AudioRouteController.shared.suspendForPowerEvent()
            if !testStopped { return .init(failure: test.error ?? "Temporary microphone-test cleanup is not confirmed.", blocking: true) }
            return routeFailure
        }
        resumeResources = resume ?? { await AudioRouteController.shared.refreshForPowerResume() }
    }
    func register(_ library: LibraryModel) {
        libraries.removeAll { $0.model == nil }
        libraries.append(.init(model: library))
    }
    func request(_ event: AppPowerEvent) {
        if event == .suspend {
            PowerAdmission.shared.setAllowed(false)
            transcriptions.removeAll { $0.model == nil }
            for transcription in transcriptions { transcription.model?.cancel() }
            revoke()
        }
        desired = event
        guard task == nil else { return }
        task = Task { [weak self] in await self?.drain() }
    }
    private func drain() async {
        defer { task = nil }
        while let event = desired {
            desired = nil
            switch event {
            case .suspend:
                if state == .suspended && !cleanupFailed { continue }
                state = .suspending; error = nil
                libraries.removeAll { $0.model == nil }
                for library in libraries { await library.model?.stop() }
                let result = await suspendResources()
                cleanupFailed = result.blocking
                retainedWarning = result.blocking ? nil : result.failure
                error = result.failure
                state = result.failure == nil ? .suspended : .failed
            case .resume:
                if state == .active && PowerAdmission.shared.allowed { continue }
                // Suspend may have been superseded before its task began. Its
                // synchronous revocation still requires resource cleanup.
                if state == .active {
                    state = .suspending
                    for library in libraries { await library.model?.stop() }
                    let result = await suspendResources()
                    cleanupFailed = result.blocking; retainedWarning = result.blocking ? nil : result.failure
                    error = result.failure
                    state = result.failure == nil ? .suspended : .failed
                }
                guard !cleanupFailed else {
                    state = .failed
                    error = error ?? "Cleanup is not confirmed. Retry Suspend before resuming."
                    continue
                }
                state = .resuming; error = retainedWarning
                if let failure = await resumeResources() {
                    state = .failed; error = failure
                } else if desired != .suspend {
                    state = .active; PowerAdmission.shared.setAllowed(true)
                    AudioCaptureAdmission.shared.objectWillChange.send()
                } // A queued Suspend runs cleanup after this resume work, with admission still closed.
            }
        }
    }
    func retryCleanup() { request(.suspend) }
    func waitUntilSettled() async { await task?.value }
}

struct PowerStatusView: View {
    @ObservedObject private var power = AppPowerLifecycle.shared
    @ObservedObject private var monitoring = NativePowerNotifications.shared
    var body: some View {
        if power.state != .active || power.error != nil || monitoring.error != nil {
            VStack(alignment: .leading, spacing: 6) {
                Text(power.state == .active ? "Audio may be started explicitly." : "Power transition: audio admission is closed.")
                if let error = power.error ?? monitoring.error { Text(error).foregroundColor(.orange) }
                HStack {
                    Button("Retry cleanup") { power.retryCleanup() }.disabled(power.transitioning)
                    Button("Resume local audio services") { power.request(.resume) }.disabled(power.transitioning)
                }
                Text("Resume refreshes devices. It does not restart capture. Retained recording files and open text drafts are preserved.")
            }.font(.caption).padding(10)
        }
    }
}
