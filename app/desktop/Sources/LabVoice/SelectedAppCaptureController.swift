import Foundation
import Combine
import LocalStore
import AVFoundation

enum SelectedAppCapturePhase { case idle, authorizing, preparing, starting, recording, stopping, saving, failed }
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
    let microphoneUID: String?
    let microphoneObjectID: UInt32?
    let mixPolicy: String?
    let timelinePolicy: String?
    enum CodingKeys: String, CodingKey {
        case version, event, target, source, channels, status, path, frames, error
        case microphoneUID = "microphone_uid", microphoneObjectID = "microphone_object_id", mixPolicy = "mix_policy", timelinePolicy = "timeline_policy"
        case operationID = "operation_id", sampleRate = "sample_rate", pcmFormat = "pcm_format", cleanupVerified = "cleanup_verified"
    }
}

private struct CaptureMicrophoneSelection: Equatable {
    let uid: String
    let sampleRate: Double
    let channels: UInt32
    init?(_ device: AudioHardwareDevice?) {
        guard let device, !device.uid.isEmpty, !device.uid.hasPrefix("dev.hari.labvoice."), device.uid.utf8.count <= 4096, !device.uid.utf8.contains(0), device.alive == 1,
              device.nominalRate == 48000, device.input.channels > 0 else { return nil }
        uid = device.uid; sampleRate = device.nominalRate; channels = device.input.channels
    }
    static func == (lhs: Self, rhs: Self) -> Bool {
        Data(lhs.uid.utf8) == Data(rhs.uid.utf8) && lhs.sampleRate == rhs.sampleRate && lhs.channels == rhs.channels
    }
}

@MainActor final class SelectedAppCaptureController: ObservableObject {
    static let shared = SelectedAppCaptureController()
    @Published private(set) var includesMicrophone = false
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
    private let currentMicrophone: () -> AudioHardwareDevice?
    private let inspectMicrophone: (String) async throws -> AudioHardwareDevice?
    private let stopMicrophoneInspection: () async -> Bool
    private let authorization: () -> AVAuthorizationStatus
    private let requestAuthorization: () async -> Bool
    private var microphoneSelection: CaptureMicrophoneSelection?
    private var microphoneObjectID: UInt32?
    private var configurationRevision = UUID()
    private var operationConfigurationRevision: UUID?
    private var inspectionPending = false
    private var observations: [AnyCancellable] = []
    private var selection: SelectedAppCaptureSelection?
    private var operation: UUID?
    private var powerRevision: UUID?
    private var child: (any AudioHelperChild)?
    private var job: RecordingJob?
    private var activity: LibraryActivity?
    private var preparation: Task<Void, Never>?
    private var metadataTask: Task<Void, Never>?
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
    var canStart: Bool { !engaged && admission.available && selected() != nil && (!includesMicrophone || CaptureMicrophoneSelection(currentMicrophone()) != nil) }
    var selectedName: String? { selected()?.name }
    init(storage: any RecordingStoring = RecordingStorage(), location: LibraryLocation? = nil,
         admission: AudioCaptureAdmission? = nil, factory: (() throws -> any AudioHelperChild)? = nil,
         selection: (() -> SelectedAppCaptureSelection?)? = nil, timeout: UInt64 = 10_000_000_000,
         currentMicrophone: (() -> AudioHardwareDevice?)? = nil,
         inspectMicrophone: ((String) async throws -> AudioHardwareDevice?)? = nil,
         stopMicrophoneInspection: (() async -> Bool)? = nil,
         authorization: (() -> AVAuthorizationStatus)? = nil, requestAuthorization: (() async -> Bool)? = nil) {
        self.storage = storage; self.location = location ?? .shared; self.admission = admission ?? .shared
        self.factory = factory ?? { SystemAudioHelperChild(url: try AudioHelperServices.packagedURL(), outputMode: .streaming(maxLineBytes: 98304)) }
        self.selected = selection ?? {
            let watch = AudioUseWatchController.shared
            return SelectedAppCaptureSelection.make(policy: LocalCallController.shared.policy, snapshot: watch.snapshot,
                                                     epoch: watch.observationEpoch, stale: watch.stale || watch.phase != .watching)
        }
        self.timeout = timeout
        self.currentMicrophone = currentMicrophone ?? { AudioRouteController.shared.selectedMicrophone }
        let inspection = AudioHelperServices()
        self.inspectMicrophone = inspectMicrophone ?? { uid in
            let inventory = try await inspection.inventory()
            guard inventory.errors.isEmpty else { throw AudioHelperError.invalidInventory }
            return inventory.devices.first { Data($0.uid.utf8) == Data(uid.utf8) }
        }
        self.stopMicrophoneInspection = stopMicrophoneInspection ?? { await inspection.stopInventory() }
        self.authorization = authorization ?? { MicrophonePermission.status() }
        self.requestAuthorization = requestAuthorization ?? { await MicrophonePermission.request() }
        if currentMicrophone == nil {
            let audio = AudioRouteController.shared
            observations.append(audio.$inputUID.sink { [weak self] uid in
                guard let self, let pinned = self.microphoneSelection else { return }
                if Data(uid.utf8) != Data(pinned.uid.utf8) { self.revoke("The microphone selection changed. Stopping recording.") }
            })
            observations.append(audio.$inventory.sink { [weak self] inventory in
                guard let self, let pinned = self.microphoneSelection else { return }
                let current = inventory?.devices.first { Data($0.uid.utf8) == Data(pinned.uid.utf8) }
                if CaptureMicrophoneSelection(current) != pinned { self.revoke("The microphone configuration changed. Stopping recording.") }
            })
        }
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
    func setIncludesMicrophone(_ enabled: Bool) {
        guard includesMicrophone != enabled else { return }
        includesMicrophone = enabled; configurationRevision = UUID()
        revoke("The recording mode changed. Stopping the current recording.")
    }
    func start() {
        guard canStart, let selected = selected() else { return }
        let microphone = includesMicrophone ? CaptureMicrophoneSelection(currentMicrophone()) : nil
        guard !includesMicrophone || microphone != nil else { return }
        let id = UUID()
        guard admission.acquire(id, owner: .selectedAppRecording) else { return }
        guard let activity = try? location.begin("Selected app audio recording") else {
            admission.release(id); error = "Finish changing the library folder before recording."; return
        }
        self.activity = activity; operation = id; selection = selected; powerRevision = PowerAdmission.shared.revision
        microphoneSelection = microphone; microphoneObjectID = nil; operationConfigurationRevision = configurationRevision
        lifetime = self; cancelled = false; admittedStart = false; result = nil; exitEvent = nil; savedSessionID = nil
        phase = .preparing; error = nil; message = "Preparing selected app audio recording…"
        let source = RecordingSource(appName: selected.name, appID: selected.target.appID, responsiblePID: selected.target.responsiblePID,
                                     processes: selected.target.processes.map { .init(objectID: $0.objectID, actualPID: $0.actualPID) }, microphoneUID: microphone?.uid)
        preparation = Task { [weak self] in
            guard let self else { return }
            do {
                if let microphone {
                    self.phase = .authorizing; self.message = "Checking microphone permission…"
                    let status = self.authorization()
                    var granted = status == .authorized
                    if status == .notDetermined { granted = await self.requestAuthorization() }
                    guard self.operation == id, self.admitted(selected) else {
                        await self.failBeforeLaunch("Recording was cancelled before microphone capture started.", id: id); return
                    }
                    guard granted else {
                        await self.failBeforeLaunch("Microphone permission is required to include the selected microphone.", id: id); return
                    }
                    self.inspectionPending = true
                    let fresh: AudioHardwareDevice?
                    do { fresh = try await self.inspectMicrophone(microphone.uid) }
                    catch { self.inspectionPending = false; throw error }
                    self.inspectionPending = false
                    guard self.operation == id, self.admitted(selected), CaptureMicrophoneSelection(fresh) == microphone else {
                        await self.failBeforeLaunch("The selected microphone changed before recording started. Refresh audio devices and try again.", id: id); return
                    }
                }
                self.phase = .preparing
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
                var arguments = ["--capture-selected-app", "--operation-id", id.uuidString, "--target-json", target, "--output", job.wav.path]
                if let microphone { arguments += ["--microphone-uid", microphone.uid] }
                try process.launch(arguments: arguments,
                                   line: { [weak self] line in self?.receive(line, id: id) }, exit: { [weak self] event in self?.exited(event, id: id) })
                self.armDeadline(id: id)
            } catch { await self.failBeforeLaunch("Cannot start selected app audio: \(error.localizedDescription)", id: id) }
        }
    }
    private func admitted(_ selection: SelectedAppCaptureSelection) -> Bool {
        !cancelled && self.selected() == selection && PowerAdmission.shared.allowed && powerRevision == PowerAdmission.shared.revision &&
            !QuitGate.shared.quitting && admission.operationID == operation && operationConfigurationRevision == configurationRevision &&
            includesMicrophone == (microphoneSelection != nil) &&
            (microphoneSelection == nil || CaptureMicrophoneSelection(currentMicrophone()) == microphoneSelection)
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
        guard operation == id, exitEvent == nil, let selection else { return }
        guard let data = line.data(using: .utf8), data.count <= 98304,
              let event = try? JSONDecoder().decode(SelectedAppCaptureEvent.self, from: data), event.version == 1,
              event.operationID == id.uuidString, event.target == selection.target, event.source == (microphoneSelection == nil ? "selected_app_output" : "selected_app_output_and_microphone"),
              event.sampleRate == 48000, event.channels == 2, event.pcmFormat == "pcm16",
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["source_format"] is [String: Any] else {
            invalidateCaptureEvidence(); error = "The selected app helper returned an invalid capture event."; revoke("Stopping invalid selected app capture."); return
        }
        if let microphone = microphoneSelection {
            let failedResult = event.event == "app_capture_result" && event.status == "failed"
            guard event.microphoneUID.map({ Data($0.utf8) }) == Data(microphone.uid.utf8),
                  failedResult || (event.microphoneObjectID ?? 0) > 0,
                  failedResult || microphoneObjectID == nil || microphoneObjectID == event.microphoneObjectID,
                  event.mixPolicy == "app_half_mic_half", event.timelinePolicy == "adjacent_host_anchors_common_overlap",
                  failedResult || object["microphone_source_format"] is [String: Any] else {
                invalidateCaptureEvidence(); error = "The helper returned a different microphone or mix configuration."; revoke("Stopping invalid microphone capture."); return
            }
            if let objectID = event.microphoneObjectID, objectID > 0 && !failedResult {
                microphoneObjectID = objectID
                updateJobSource(microphoneObjectID: objectID)
            }
        } else if event.microphoneUID != nil || event.microphoneObjectID != nil || event.mixPolicy != nil || event.timelinePolicy != nil {
            invalidateCaptureEvidence(); error = "The app-only helper unexpectedly included microphone capture."; revoke("Stopping invalid microphone capture."); return
        }
        switch event.event {
        case "app_capture_started":
            guard phase == .starting, admitted(selection) else { revoke("The selected call changed before capture started."); return }
            admittedStart = true; job?.captureAdmissionVerified = true; persistJobMetadata(); deadline?.cancel(); deadline = nil
            phase = .recording; message = microphoneSelection == nil ? "Recording selected app audio. Microphone audio is not included." : "Recording selected app audio and the selected microphone. Both sources use half gain."
        case "app_capture_result":
            guard result == nil, event.status == "completed" || event.status == "failed", event.cleanupVerified != nil,
                  event.path == job?.wav.path, event.frames != nil else {
                invalidateCaptureEvidence(); error = "The selected app helper returned an invalid result."; revoke("Stopping invalid selected app capture."); return
            }
            result = event; deadline?.cancel(); deadline = nil; phase = .stopping
            if event.status != "completed" { error = event.error?.isEmpty == false ? event.error : "Selected app capture failed." }
        default: invalidateCaptureEvidence(); error = "The selected app helper returned an unknown capture event."; revoke("Stopping selected app capture.")
        }
    }
    private func invalidateCaptureEvidence() {
        job?.captureAdmissionVerified = false; persistJobMetadata()
    }
    private func persistJobMetadata() {
        guard let job, let id = operation else { return }
        let previous = metadataTask
        metadataTask = Task { [weak self] in
            await previous?.value
            guard let self, self.operation == id else { return }
            do { try await self.storage.persistMetadata(job) }
            catch {
                guard self.operation == id else { return }
                self.job?.captureAdmissionVerified = false
                if self.error == nil { self.error = "Recording source metadata could not be saved. The capture will stop." }
                self.revoke("Stopping because recording metadata could not be saved.")
            }
        }
    }
    private func updateJobSource(microphoneObjectID: UInt32) {
        guard var job, let source = job.recordingSource, let uid = microphoneSelection?.uid else { return }
        job.recordingSource = RecordingSource(appName: source.appName, appID: source.appID, responsiblePID: source.responsiblePID,
                                             processes: source.processes, microphoneUID: uid, microphoneObjectID: microphoneObjectID)
        self.job = job
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
            await self.metadataTask?.value
            guard self.operation == id else { return false }
            var saved = false
            if let job = self.job, let result = self.result, self.admittedStart, result.status == "completed", result.cleanupVerified == true,
               self.exitEvent?.status == 0, self.exitEvent?.diagnostic.isEmpty == true,
               let frames = result.frames, frames > 0, self.error == nil {
                self.phase = .saving; self.message = "Saving selected app audio…"
                do {
                    let save = try await self.storage.saveCompleted(job, path: job.wav.path, frames: frames, sampleRate: 48000, channels: 2)
                    guard self.operation == id else { return false }
                    self.savedSessionID = save.session.id; self.error = save.cleanupWarning
                    self.job = nil; saved = true; self.message = job.recordingSource?.microphoneUID == nil ? "Selected app audio saved. Microphone audio was not included." : "Selected app and microphone audio saved."
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
        error = message
        await metadataTask?.value
        guard operation == id else { return }
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
        microphoneSelection = nil; microphoneObjectID = nil; operationConfigurationRevision = nil
        preparation = nil; metadataTask = nil; lifetime = nil
    }
    func stop() async -> Bool {
        if let stopTask { return await stopTask.value }
        guard let id = operation else { return true }
        cancelled = true; deadline?.cancel(); deadline = nil
        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            defer { self.stopTask = nil }
            if self.inspectionPending, !(await self.stopMicrophoneInspection()) {
                self.error = "The microphone inspection helper has not confirmed exit. Retry Stop before quitting."
                self.phase = .failed; return false
            }
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
                    await self.metadataTask?.value
                    guard self.operation == id else { return true }
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
