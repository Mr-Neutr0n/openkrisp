import Foundation
import Combine
import LocalStore

struct RecordingRecoveryRequest {
    let item: RecoverableRecording
    let libraryRevision: UUID
    let scanID: UUID
}

@MainActor final class RecordingRecoveryController: ObservableObject {
    static let shared = RecordingRecoveryController(service: RecordingRecovery(), audio: .shared)
    @Published private(set) var items: [RecoverableRecording] = []
    @Published private(set) var busy = false
    @Published private(set) var message = "Review retained recording folders to find finalized audio."
    @Published private(set) var error: String?
    private let service: any RecordingRecoveryServing
    private let audio: AudioRouteController
    private let location: LibraryLocation
    private let admission: AudioCaptureAdmission
    private let notifications: NotificationCenter
    private var scanID = UUID()
    private var scannedRevision: UUID?
    private var observations: [AnyCancellable] = []
    var canRecover: Bool {
        !busy && audio.phase == .idle && !audio.loading && !audio.recording.busy && admission.available && !location.switching
    }
    init(service: any RecordingRecoveryServing, audio: AudioRouteController, location: LibraryLocation? = nil,
         admission: AudioCaptureAdmission? = nil, notifications: NotificationCenter = .default) {
        self.service = service; self.audio = audio; self.location = location ?? .shared
        self.admission = admission ?? .shared; self.notifications = notifications
        observations.append(audio.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() })
        observations.append(self.admission.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() })
        observations.append(self.location.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() })
        observations.append(self.location.$snapshot.dropFirst().sink { [weak self] _ in
            guard let self else { return }
            self.scanID = UUID(); self.scannedRevision = nil; self.items = []
            self.message = "Library changed. Review retained recordings again before saving a copy."
        })
    }
    private func acquire() throws -> (UUID, LibraryActivity) {
        guard canRecover else { throw RecordingRecoveryControlError.busy }
        let id = UUID()
        guard admission.acquire(id, owner: .recordingRecovery) else { throw RecordingRecoveryControlError.busy }
        do { return (id, try location.begin("Recording recovery")) }
        catch { admission.release(id); throw error }
    }
    private func finish(_ lease: (UUID, LibraryActivity)) {
        location.end(lease.1); admission.release(lease.0); busy = false
    }
    func scan() async {
        guard !busy else { return }
        let lease: (UUID, LibraryActivity)
        do { lease = try acquire() } catch { self.error = "Stop audio and finish recording or microphone-test cleanup before reviewing retained recordings."; return }
        busy = true; error = nil; message = "Checking retained recording folders…"
        let token = UUID(); scanID = token
        defer { finish(lease) }
        do {
            let found = try await service.scan()
            guard token == scanID, location.snapshot.revision == lease.1.location.revision else { return }
            items = found; scannedRevision = lease.1.location.revision
            message = found.isEmpty ? "No retained recording folders were found." : "Only validated, finalized recordings can be copied. Source folders remain untouched."
        } catch {
            guard token == scanID else { return }
            items = []; scannedRevision = nil; self.error = "Cannot review retained recordings: \(error.localizedDescription)"
        }
    }
    func request(for item: RecoverableRecording) -> RecordingRecoveryRequest? {
        guard canRecover, scannedRevision == location.snapshot.revision, items.contains(item), item.eligibility == .finalized else { return nil }
        return .init(item: item, libraryRevision: location.snapshot.revision, scanID: scanID)
    }
    func saveCopy(_ request: RecordingRecoveryRequest) async {
        guard !busy else { return }
        guard request.libraryRevision == location.snapshot.revision, request.scanID == scanID, items.contains(request.item), request.item.eligibility == .finalized else {
            error = "The library or retained-recording review changed. Review again before saving a copy."; return
        }
        let lease: (UUID, LibraryActivity)
        do { lease = try acquire() } catch { self.error = "Stop audio and finish recording or microphone-test cleanup before saving a copy."; return }
        busy = true; error = nil; message = "Saving a copy to the current library…"
        defer { finish(lease) }
        do {
            let result = try await service.saveCopy(request.item, to: lease.1.location)
            message = "Copy saved to the library. The source remains. Saving it again creates another copy."
            if let warning = result.cleanupWarning { message += " " + warning }
            notifications.post(name: .localRecordingSaved, object: nil)
        } catch {
            self.error = "Cannot save this copy: \(error.localizedDescription). The retained source was not deleted."
        }
    }
}
private enum RecordingRecoveryControlError: Error { case busy }
