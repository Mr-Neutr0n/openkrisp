import Foundation
import Combine
import LocalStore

enum RecordingPhase { case idle, preparing, starting, recording, pausing, paused, resuming, stopping, importing, uncertain }

private struct RecordingCommand: Encodable {
    let type: String
    let operationID: String
    let sequence: UInt64
    let recordingID: String
    let path: String?
    func line() throws -> Data { var data = try JSONEncoder().encode(self); data.append(10); return data }
}
private struct RecordingAck: Decodable {
    let type: String, operationID: String, recordingID: String, action: String
    let sequence: UInt64
    let accepted: Bool
    let error: String?
}
private struct RecordingResult: Decodable {
    let type: String, operationID: String, recordingID: String, status: String, path: String
    let frames: UInt64
    let sampleRate: Double
    let channels: UInt32
    let error: String?
}

@MainActor final class RecordingController: ObservableObject {
    @Published private(set) var phase: RecordingPhase = .idle { didSet { if phase != oldValue { DiagnosticEventLog.shared.append(component: .recording, code: phase == .idle ? .stopped : (phase == .recording ? .started : .stateChanged), severity: .info) } } }
    @Published private(set) var message = "Recording is off."
    @Published private(set) var error: String? { didSet { if error != nil && error != oldValue { DiagnosticEventLog.shared.append(component: .recording, code: .operationFailed, severity: .error) } } }
    @Published private(set) var retainedPaths: [String] = []
    @Published private(set) var savedSessionID: UUID?
    @Published private(set) var settling = false
    private let location: LibraryLocation
    private var libraryActivity: LibraryActivity?
    private let storage: any RecordingStoring
    private let timeout: UInt64
    private var operation: UUID?
    private var send: ((Data) throws -> Void)?
    private var job: RecordingJob?
    private var sequence: UInt64 = 0
    private var flight: (sequence: UInt64, action: String)?
    private var deadline: Task<Void, Never>?
    private var work: Task<Void, Never>?
    private var stoppingRoute = false
    private var failureToken: UUID?
    var busy: Bool { phase != .idle || settling }
    var libraryActivityID: UUID? { libraryActivity?.id }
    var canStart: Bool { operation != nil && !busy && !stoppingRoute && !QuitGate.shared.quitting }
    init(storage: any RecordingStoring = RecordingStorage(), timeout: UInt64 = 10_000_000_000, location: LibraryLocation? = nil) {
        self.location = location ?? .shared
        self.storage = storage; self.timeout = timeout
    }
    func attach(operationID: UUID, send: @escaping (Data) throws -> Void) {
        guard !busy else { return }
        operation = operationID; self.send = send; sequence = 0; stoppingRoute = false
    }
    func refreshRetained() async {
        do {
            let paths = try await storage.retainedDirectories()
            retainedPaths = paths.filter { phase == .uncertain || $0 != job?.directory.path }
        }
        catch { self.error = "Cannot inspect retained recordings: \(error)" }
    }
    func start() {
        guard canStart, let id = operation else { return }
        guard let activity = try? location.begin("Recording") else { error = "Finish changing the library folder before recording."; return }
        libraryActivity = activity
        failureToken = nil
        phase = .preparing; error = nil; savedSessionID = nil; message = "Preparing private recording file…"
        work = Task { [weak self] in
            guard let self else { return }
            do {
                let prepared = try await self.storage.prepare(operationID: id, location: activity.location)
                self.job = prepared
                self.retainedPaths.removeAll { $0 == prepared.directory.path }
                guard self.operation == id, !self.stoppingRoute, !Task.isCancelled else {
                    await self.fail("Recording cancelled before capture started.", terminal: true); return
                }
                self.phase = .starting; self.message = "Waiting for recording start confirmation…"
                try self.command(action: "start", job: prepared)
            } catch { await self.fail("Cannot start recording: \(error)", terminal: true) }
        }
    }
    func pauseOrResume() {
        guard let job, phase == .recording || phase == .paused else { return }
        let action = phase == .recording ? "pause" : "resume"
        phase = action == "pause" ? .pausing : .resuming
        message = "Waiting for recording \(action) confirmation…"
        do { try command(action: action, job: job) }
        catch { work = Task { [weak self] in await self?.fail("Cannot \(action) recording: \(error)", terminal: false) } }
    }
    func stop() {
        guard let job, [.recording, .starting, .uncertain, .pausing, .paused, .resuming].contains(phase) else { return }
        deadline?.cancel(); deadline = nil
        phase = .stopping; message = "Finalizing recording…"
        do { try command(action: "stop", job: job) }
        catch {
            work = Task { [weak self] in await self?.fail("Cannot request recording finalization: \(error)", terminal: false) }
        }
    }
    private func command(action: String, job: RecordingJob) throws {
        guard let send, operation == job.operationID, sequence < 9_007_199_254_740_991 else { throw AudioHelperError.controlChannelClosed }
        sequence += 1
        let token = sequence
        flight = (token, action)
        try send(RecordingCommand(type: "recording-" + action, operationID: job.operationID.uuidString,
            sequence: token, recordingID: job.id.uuidString, path: action == "start" ? job.wav.path : nil).line())
        guard flight?.sequence == token else { return }
        armDeadline(job: job, message: "Recording \(action) was not confirmed. Current recording state is unknown; stop audio to end capture.")
    }
    private func armDeadline(job: RecordingJob, message: String) {
        deadline?.cancel()
        deadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: self?.timeout ?? 0) } catch { return }
            guard let self, self.job?.id == job.id, self.phase != .importing else { return }
            await self.fail(message, terminal: false)
        }
    }
    @discardableResult func receive(_ line: String, operationID: UUID) -> Bool {
        guard let data = line.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String, type == "recording-ack" || type == "recording-result" else { return false }
        guard operation == operationID, let job, job.operationID == operationID else { return true }
        if type == "recording-ack" {
            guard let ack = try? JSONDecoder().decode(RecordingAck.self, from: data),
                  ack.operationID == operationID.uuidString, ack.recordingID == job.id.uuidString,
                  ack.sequence == flight?.sequence, ack.action == flight?.action else { return true }
            flight = nil; deadline?.cancel(); deadline = nil
            if !ack.accepted {
                work = Task { [weak self] in await self?.fail("Recording command rejected: " + (ack.error ?? "No reason supplied."), terminal: ack.action == "start") }
            } else if ack.action == "start" {
                // A stop may already be waiting; its newer flight prevents this stale ACK from matching.
                phase = .recording; message = "Recording processed microphone + speaker mix locally."
            } else if ack.action == "pause" {
                phase = .paused; message = "Recording paused. Paused audio is excluded from the saved duration."
            } else if ack.action == "resume" {
                phase = .recording; message = "Recording processed microphone + speaker mix locally."
            } else {
                phase = .stopping; message = "Draining and finalizing recording…"
                armDeadline(job: job, message: "Recording finalization was not confirmed. Staging files are retained; stop audio.")
            }
        } else {
            guard let result = try? JSONDecoder().decode(RecordingResult.self, from: data),
                  result.operationID == operationID.uuidString, result.recordingID == job.id.uuidString,
                  phase != .importing else { return true }
            deadline?.cancel(); deadline = nil; flight = nil
            if result.status != "completed" {
                work = Task { [weak self] in await self?.fail("Recording failed: " + (result.error ?? "No finalized result."), terminal: true) }
            } else {
                failureToken = nil
                phase = .importing; message = "Validating and saving completed recording…"
                work = Task { [weak self] in
                    guard let self else { return }
                    do {
                        let saved = try await self.storage.saveCompleted(job, path: result.path, frames: result.frames,
                                                                        sampleRate: result.sampleRate, channels: result.channels)
                        self.savedSessionID = saved.session.id; self.job = nil; self.phase = .idle
                        self.releaseLibraryActivity()
                        self.message = "Recording saved to local history."; self.error = saved.cleanupWarning
                        await self.refreshRetained()
                        NotificationCenter.default.post(name: .localRecordingSaved, object: nil)
                    } catch { await self.fail("Completed recording could not be imported: \(error)", terminal: true) }
                }
            }
        }
        return true
    }
    private func fail(_ message: String, terminal: Bool) async {
        deadline?.cancel(); deadline = nil; flight = nil
        let token = UUID(); failureToken = token
        let retained = job
        self.error = message; self.message = terminal ? "Recording was not saved." : "Recording status unknown. Stop audio."
        if terminal { job = nil; phase = .idle; releaseLibraryActivity() } else { phase = .uncertain }
        if let retained {
            if !retainedPaths.contains(retained.directory.path) { retainedPaths.append(retained.directory.path) }
            do { try await storage.retainFailure(retained, message: message) }
            catch {
                if failureToken == token { self.error = message + " Failure note could not be written: \(error). Staging metadata remains at \(retained.directory.path)." }
            }
            if terminal { await storage.releaseDestination(retained) }
        }
    }
    private func releaseLibraryActivity() {
        if let libraryActivity { location.end(libraryActivity) }
        libraryActivity = nil
    }
    /// Called before helper termination. A failed/missing ACK never implies a saved recording.
    func prepareForRouteStop() async {
        stoppingRoute = true
        if phase == .preparing { work?.cancel(); await work?.value }
        stop()
        let start = DispatchTime.now().uptimeNanoseconds
        while busy && phase != .uncertain {
            if DispatchTime.now().uptimeNanoseconds - start >= timeout { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    func finishAfterExit() async {
        if let operation { await helperExited(operationID: operation) }
    }
    /// Output has drained before this call. Await imports or retain unexpected-exit evidence.
    func helperExited(operationID: UUID) async {
        guard operation == operationID else { return }
        settling = true; stoppingRoute = true; deadline?.cancel(); deadline = nil
        await work?.value
        guard operation == operationID else { settling = false; return }
        if job != nil { await fail("Audio helper exited without a validated completed recording. Files remain for inspection.", terminal: true) }
        guard operation == operationID else { settling = false; return }
        operation = nil; send = nil; stoppingRoute = false; settling = false
    }
}
