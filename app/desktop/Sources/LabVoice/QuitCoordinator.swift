import Foundation
import Combine

/// Main-actor admission closes the gap between the quit decision and async finalization.
@MainActor final class QuitGate {
    static let shared = QuitGate()
    private var quitToken: UUID?
    private var work: Set<UUID> = []
    var quitting: Bool { quitToken != nil }
    var hasPendingWork: Bool { !work.isEmpty }
    func beginWork() -> UUID? {
        guard !quitting else { return nil }
        let token = UUID(); work.insert(token); return token
    }
    func endWork(_ token: UUID) { work.remove(token) }
    func beginQuit() -> UUID? {
        guard !quitting, !hasPendingWork else { return nil }
        let token = UUID(); quitToken = token; return token
    }
    func cancelQuit(_ token: UUID) { if quitToken == token { quitToken = nil } }
}

struct QuitSnapshot: Sendable {
    let recordingActive: Bool
    let audioEngaged: Bool
    let testEngaged: Bool
    let otherWork: Bool
    var recordingSaved = false
    var recordingFailure: String? = nil
    var stopFailure: String? = nil
    var testFailure: String? = nil
}

@MainActor final class QuitCoordinator: ObservableObject {
    @Published private(set) var inProgress = false
    @Published private(set) var reason: String?
    private let snapshot: () -> QuitSnapshot
    private let confirmSave: () async -> Bool
    private let stopAudio: () async -> Bool
    private let cleanupTest: () async -> Bool
    private let gate: QuitGate
    init(snapshot: @escaping () -> QuitSnapshot, confirmSave: @escaping () async -> Bool,
         stopAudio: @escaping () async -> Bool, cleanupTest: @escaping () async -> Bool, gate: QuitGate? = nil) {
        self.snapshot = snapshot; self.confirmSave = confirmSave; self.stopAudio = stopAudio
        self.cleanupTest = cleanupTest; self.gate = gate ?? .shared
    }
    func request() async -> Bool {
        guard !inProgress else { return false }
        reason = nil
        let initial = snapshot()
        guard !initial.otherWork, !gate.hasPendingWork else {
            reason = "Finish the current library, recovery or diagnostic export operation before quitting. No work was interrupted."
            return false
        }
        guard let token = gate.beginQuit() else { reason = "Another quit operation is already pending."; return false }
        inProgress = true
        var approved = false
        defer { inProgress = false; if !approved { gate.cancelQuit(token) } }
        if initial.recordingActive, !(await confirmSave()) { return false }
        if initial.testEngaged, !(await cleanupTest()) {
            reason = snapshot().testFailure ?? "Microphone-test cleanup is not confirmed. Lab Voice will stay open."
            return false
        }
        if initial.audioEngaged || initial.recordingActive {
            guard await stopAudio() else {
                reason = snapshot().stopFailure ?? "The audio helper has not stopped. Lab Voice will stay open."
                return false
            }
        }
        let final = snapshot()
        guard !final.audioEngaged, !final.testEngaged, !final.recordingActive else {
            reason = final.stopFailure ?? "Audio or recording cleanup is still pending. Lab Voice will stay open."
            return false
        }
        if initial.recordingActive, !final.recordingSaved {
            reason = final.recordingFailure ?? "The recording was not saved to the library. Its retained files need attention before quitting."
            return false
        }
        approved = true // Keep admission closed until the process exits.
        return true
    }
}
