import Foundation
import Combine
import LocalStore

enum SelectedAppCapturePhase { case idle, preparing, starting, recording, stopping, saving, failed }
private struct SelectedAppCaptureEvent: Decodable {
    let version: Int
    let event: String
    let operationID: String
    let target: SelectedAppCaptureTarget
    let source: String
    let sampleRate: Double
    let channels: UInt32
    let pcmFormat: String
    let status: String?
    let path: String?
    let frames: UInt64?
    let cleanupVerified: Bool?
    let error: String?
    enum CodingKeys: String, CodingKey {
        case version, event, target, source, channels, status, path, frames, error
        case operationID = "operation_id", sampleRate = "sample_rate", pcmFormat = "pcm_format", cleanupVerified = "cleanup_verified"
    }
}

@MainActor final class SelectedAppCaptureController: ObservableObject {
    static let shared = SelectedAppCaptureController()
    @Published private(set) var phase: SelectedAppCapturePhase = .idle
    @Published private(set) var message = "Selected app audio recording is off."
    @Published private(set) var error: String?
    @Published private(set) var savedSessionID: UUID?
    @Published private(set) var retainedPaths: [String] = []
    private let storage: any RecordingStoring
    private let location: LibraryLocation
    private let admission: AudioCaptureAdmission
    private let factory: () throws -> any AudioHelperChild
    private let selected: () -> SelectedAppCaptureSelection?
    private let timeout: UInt64
    private var observations: [AnyCancellable] = []
    private var selection: SelectedAppCaptureSelection?
    private var operation: UUID?
    private var powerRevision: UUID?
    private var child: (any AudioHelperChild)?
    private var job: RecordingJob?
    private var activity: LibraryActivity?
    private var preparation: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var stopTask: Task<Bool, Never>?
    private var completion: Task<Bool, Never>?
    private var exitEvent: HelperExit?
    private var result: SelectedAppCaptureEvent?
    private var cancelled = false
    private var admittedStart = false
    private var powerCapturePending = false
    private var lifetime: SelectedAppCaptureController?
    var engaged: Bool { operation != nil || stopTask != nil || completion != nil }
    var libraryActivityID: UUID? { activity?.id }
    var canStart: Bool { !engaged && admission.available && selected() != nil }
    var selectedName: String? { selected()?.name }
    init(storage: any RecordingStoring = RecordingStorage(), location: LibraryLocation? = nil,
         admission: AudioCaptureAdmission? = nil, factory: (() throws -> any AudioHelperChild)? = nil,
         selection: (() -> SelectedAppCaptureSelection?)? = nil, timeout: UInt64 = 10_000_000_000) {
        self.storage = storage; self.location = location ?? .shared; self.admission = admission ?? .shared
        self.factory = factory ?? { SystemAudioHelperChild(url: try AudioHelperServices.packagedURL(), outputMode: .streaming(maxLineBytes: 98304)) }
        self.selected = selection ?? {
            let watch = AudioUseWatchController.shared
            return SelectedAppCaptureSelection.make(policy: LocalCallController.shared.policy, snapshot: watch.snapshot,
                                                     epoch: watch.observationEpoch, stale: watch.stale || watch.phase != .watching)
        }
        self.timeout = timeout
        if selection == nil {
            let watch = AudioUseWatchController.shared, calls = LocalCallController.shared
            observations.append(watch.$stale.sink { [weak self] stale in if stale { self?.revoke("Audio use is unknown. Stopping selected app audio.") } })
            observations.append(calls.$policy.sink { [weak self] policy in
                guard let self, let selection = self.selection else { return }
                if !policy.fresh || !policy.calls.contains(where: { $0.activationID == selection.activationID && policy.isCurrent($0.name) && policy.qualified($0) }) {
                    self.revoke("The selected call changed. Stopping selected app audio.")
                }
            })
            observations.append(watch.$snapshot.sink { [weak self] snapshot in
                guard let self, let selection = self.selection else { return }
                if SelectedAppCaptureSelection.make(policy: calls.policy, snapshot: snapshot, epoch: watch.observationEpoch, stale: watch.stale) != selection {
                    self.revoke("The selected app processes changed. Stopping selected app audio.")
                }
                self.objectWillChange.send()
            })
        }
        observations.append(self.admission.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() })
    }
    func start() {
        guard canStart, let selected = selected() else { return }
        let id = UUID()
        guard admission.acquire(id, owner: .selectedAppRecording) else { return }
        guard let activity = try? location.begin("Selected app audio recording") else {
            admission.release(id); error = "Finish changing the library folder before recording."; return
        }
        self.activity = activity; operation = id; selection = selected; powerRevision = PowerAdmission.shared.revision
        lifetime = self; cancelled = false; admittedStart = false; result = nil; exitEvent = nil; savedSessionID = nil
        phase = .preparing; error = nil; message = "Preparing selected app audio recording…"
        let source = RecordingSource(appName: selected.name, appID: selected.target.appID, responsiblePID: selected.target.responsiblePID,
                                     processes: selected.target.processes.map { .init(objectID: $0.objectID, actualPID: $0.actualPID) })
        preparation = Task { [weak self] in
            guard let self else { return }
            do {
                let job = try await self.storage.prepare(operationID: id, location: activity.location, source: source)
                guard self.operation == id else {
                    try? await self.storage.retainFailure(job, message: "Superseded selected app preparation.")
                    await self.storage.releaseDestination(job); return
                }
                self.job = job
                guard self.admitted(selected) else {
                    await self.failBeforeLaunch("Selected app recording was cancelled before capture started.", id: id); return
                }
                let process = try self.factory(); self.child = process; self.phase = .starting
                let data = try JSONEncoder().encode(selected.target)
                let target = String(decoding: data, as: UTF8.self)
                try process.launch(arguments: ["--capture-selected-app", "--operation-id", id.uuidString, "--target-json", target, "--output", job.wav.path],
                                   line: { [weak self] line in self?.receive(line, id: id) }, exit: { [weak self] event in self?.exited(event, id: id) })
                self.armDeadline(id: id)
            } catch { await self.failBeforeLaunch("Cannot start selected app audio: \(error.localizedDescription)", id: id) }
        }
    }
    private func admitted(_ selection: SelectedAppCaptureSelection) -> Bool {
        !cancelled && self.selected() == selection && PowerAdmission.shared.allowed && powerRevision == PowerAdmission.shared.revision &&
            !QuitGate.shared.quitting && admission.operationID == operation
    }
    func revalidate() {
        guard let selection, !admitted(selection) else { return }
        revoke("The selected call is no longer current. Stopping selected app audio.")
    }
    func revokeForPowerEvent() {
        if admittedStart && engaged { powerCapturePending = true }
        revoke("Stopping selected app audio for a power event.")
    }
    func suspendForPowerEvent() async -> PowerSuspendResult {
        guard await stop() else { return .init(failure: error ?? "Selected app capture cleanup is not confirmed.", blocking: true) }
        defer { powerCapturePending = false }
        if powerCapturePending && savedSessionID == nil {
            return .init(failure: error ?? "Selected app audio was not saved. Retained files remain available.", blocking: false)
        }
        return .stopped
    }
    private func revoke(_ reason: String) {
        guard engaged else { return }
        cancelled = true; message = reason; deadline?.cancel(); deadline = nil
        Task { [weak self] in _ = await self?.stop() }
    }
    private func armDeadline(id: UUID) {
        deadline?.cancel()
        deadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: self?.timeout ?? 0) } catch { return }
            guard let self, self.operation == id, self.phase == .starting else { return }
            self.error = "Selected app audio did not confirm startup."; self.deadline = nil
            _ = await self.stop()
        }
    }
    private func receive(_ line: String, id: UUID) {
        guard operation == id, let selection else { return }
        guard let data = line.data(using: .utf8), data.count <= 98304,
              let event = try? JSONDecoder().decode(SelectedAppCaptureEvent.self, from: data), event.version == 1,
              event.operationID == id.uuidString, event.target == selection.target, event.source == "selected_app_output",
              event.sampleRate == 48000, event.channels == 2, event.pcmFormat == "pcm16",
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["source_format"] is [String: Any] else {
            error = "The selected app helper returned an invalid capture event."; revoke("Stopping invalid selected app capture."); return
        }
        switch event.event {
        case "app_capture_started":
            guard phase == .starting, admitted(selection) else { revoke("The selected call changed before capture started."); return }
            admittedStart = true; deadline?.cancel(); deadline = nil
            phase = .recording; message = "Recording selected app audio. Microphone audio is not included."
        case "app_capture_result":
            guard result == nil, event.status == "completed" || event.status == "failed", event.cleanupVerified != nil,
                  event.path == job?.wav.path, event.frames != nil else {
                error = "The selected app helper returned an invalid result."; revoke("Stopping invalid selected app capture."); return
            }
            result = event; deadline?.cancel(); deadline = nil; phase = .stopping
            if event.status != "completed" { error = event.error?.isEmpty == false ? event.error : "Selected app capture failed." }
        default: error = "The selected app helper returned an unknown capture event."; revoke("Stopping selected app capture.")
        }
    }
    private func exited(_ event: HelperExit, id: UUID) {
        guard operation == id else { return }
        exitEvent = event; deadline?.cancel(); deadline = nil
        beginCompletion(id: id)
    }
    private func beginCompletion(id: UUID) {
        guard completion == nil else { return }
        completion = Task { [weak self] in
            guard let self, self.operation == id else { return false }
            var saved = false
            if let job = self.job, let result = self.result, self.admittedStart, result.status == "completed", result.cleanupVerified == true,
               self.exitEvent?.status == 0, self.exitEvent?.diagnostic.isEmpty == true,
               let frames = result.frames, frames > 0, self.error == nil {
                self.phase = .saving; self.message = "Saving selected app audio…"
                do {
                    let save = try await self.storage.saveCompleted(job, path: job.wav.path, frames: frames, sampleRate: 48000, channels: 2)
                    guard self.operation == id else { return false }
                    self.savedSessionID = save.session.id; self.error = save.cleanupWarning
                    self.job = nil; saved = true; self.message = "Selected app audio saved. Microphone audio was not included."
                    NotificationCenter.default.post(name: .localRecordingSaved, object: nil)
                } catch {
                    guard self.operation == id else { return false }
                    self.error = "Cannot save selected app audio: \(error.localizedDescription)"
                }
            }
            if !saved { await self.retain(self.error ?? "Selected app capture ended without a verified completed recording.") }
            guard self.operation == id else { return false }
            self.release(id: id); self.phase = saved ? .idle : .failed
            self.completion = nil; return saved
        }
    }
    private func retain(_ message: String) async {
        error = message; self.message = "Selected app audio was not saved."
        if let job {
            if !retainedPaths.contains(job.directory.path) { retainedPaths.append(job.directory.path) }
            try? await storage.retainFailure(job, message: message)
            await storage.releaseDestination(job)
        }
    }
    private func failBeforeLaunch(_ message: String, id: UUID) async {
        guard operation == id else { return }
        // A partially launched live helper remains owned until Stop drains it.
        if child?.running == true { error = message; revoke(message); return }
        await retain(message)
        guard operation == id else { return }
        release(id: id); phase = .failed
    }
    private func release(id: UUID) {
        guard operation == id else { return }
        deadline?.cancel(); deadline = nil
        admission.release(id)
        if let activity { location.end(activity) }
        activity = nil; job = nil; child = nil; operation = nil; selection = nil; powerRevision = nil
        preparation = nil; lifetime = nil
    }
    func stop() async -> Bool {
        if let stopTask { return await stopTask.value }
        guard let id = operation else { return true }
        cancelled = true; deadline?.cancel(); deadline = nil
        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            defer { self.stopTask = nil }
            await self.preparation?.value
            guard self.operation == id else { return true }
            if let process = self.child {
                self.phase = .stopping
                if process.running { try? process.send(Data("stop\n".utf8)) }
                var drained = await process.waitForExit(timeoutNanoseconds: self.timeout)
                if !drained { process.terminate(); drained = await process.waitForExit(timeoutNanoseconds: self.timeout) }
                guard self.operation == id else { return drained }
                guard drained, !process.running else {
                    self.phase = .failed; self.error = "Selected app capture has not confirmed exit. Retry Stop before quitting."
                    self.stopTask = nil; return false
                }
                if self.exitEvent == nil {
                    self.error = "Selected app capture drained without an exit result."
                    await self.retain(self.error!)
                    guard self.operation == id else { return true }
                    self.release(id: id); self.phase = .failed
                } else {
                    self.beginCompletion(id: id)
                    _ = await self.completion?.value
                }
            }
            self.stopTask = nil; return true
        }
        stopTask = task; return await task.value
    }
}
