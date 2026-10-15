import Foundation
import Combine

/// Main-actor ownership covers permission waits and uncertain cleanup, across every window.
@MainActor final class AudioCaptureAdmission: ObservableObject {
    static let shared = AudioCaptureAdmission()
    enum Owner: Equatable { case route, microphoneTest, recordingRecovery }
    @Published private(set) var operationID: UUID?
    private(set) var owner: Owner?
    var available: Bool { operationID == nil && !QuitGate.shared.quitting }
    func acquire(_ id: UUID, owner: Owner) -> Bool {
        guard available else { return false }
        self.owner = owner; operationID = id; return true
    }
    func release(_ id: UUID) {
        guard operationID == id else { return }
        owner = nil; operationID = nil
    }
}
