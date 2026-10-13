import Foundation
import Combine
import AVFoundation

enum MicrophoneTestPhase { case idle, authorizing, preparing, starting, capturing, stopping, processing, validating, comparison, cancelling, failed }
private struct TestStarted: Decodable { let event: String, operationID: String, input_uid: String; let sampleRate: Double; let channels: UInt32; let minimumFrames, maximumFrames: UInt64 }
private struct TestProgress: Decodable { let event: String, operationID: String; let frames: UInt64 }
private struct TestAck: Decodable { let type: String, operationID: String, action: String; let sequence: UInt64; let accepted: Bool; let error: String? }
private struct TestResult: Decodable {
    let event: String, operationID: String, status: String
    let frames: UInt64; let sampleRate: Double; let channels: UInt32
    let engine: String?; let originalPath, processedPath, error: String?
    let adapterBufferingFrames: UInt64?; let adapterDelayAligned: Bool?
}

@MainActor final class MicrophoneTestController: ObservableObject {
    static let shared = MicrophoneTestController()
    @Published private(set) var phase: MicrophoneTestPhase = .idle
    @Published private(set) var inputName: String?
    @Published private(set) var frames: UInt64 = 0
    @Published private(set) var status = "Choose a microphone and start a temporary test."
    @Published private(set) var error: String?
    @Published private(set) var retainedPaths: [String] = []
    @Published private(set) var variant: ComparisonVariant = .original
    @Published private(set) var playing = false
    @Published private(set) var playbackPosition = 0.0
    private let captureAdmission = AudioCaptureAdmission.shared
    private let files: any MicrophoneTestStoring
    private let playback: any ComparisonPlaying
    private let authorization: () -> AVAuthorizationStatus
    private let requestAuthorization: () async -> Bool
    private let factory: () throws -> any AudioHelperChild
    private let startupTimeout, operationTimeout, exitTimeout: UInt64
    private var id: UUID?
    private var job: MicrophoneTestJob?
    private var child: (any AudioHelperChild)?
    private var startTask, resultTask, deadline, playbackPoll: Task<Void, Never>?
    private var sequence: UInt64 = 0
    private var flight: (sequence: UInt64, action: String)?
    private var result: TestResult?
    private var started = false, cancelIntent = false, closing = false
    var engaged: Bool { id != nil || job != nil || child != nil || closing }
    var canStop: Bool { phase == .capturing && frames >= 240000 }
    var pendingCapture: Bool { [.authorizing, .preparing, .starting, .capturing, .stopping, .processing, .validating].contains(phase) }
    var capturedSeconds: Double { Double(frames) / 48000 }
    init(files: any MicrophoneTestStoring = MicrophoneTestFiles(), playback: any ComparisonPlaying = ComparisonPlayback(),
         authorization: (() -> AVAuthorizationStatus)? = nil, requestAuthorization: (() async -> Bool)? = nil,
         factory: (() throws -> any AudioHelperChild)? = nil,
         startupTimeout: UInt64 = 10_000_000_000, operationTimeout: UInt64 = 90_000_000_000, exitTimeout: UInt64 = 10_000_000_000) {
        self.files = files; self.playback = playback
        self.authorization = authorization ?? { MicrophonePermission.status() }
        self.requestAuthorization = requestAuthorization ?? { await MicrophonePermission.request() }
        self.factory = factory ?? { try AudioHelperServices.makeChild() }
        self.startupTimeout = startupTimeout; self.operationTimeout = operationTimeout; self.exitTimeout = exitTimeout
    }
    func refreshRetained() async {
        do { retainedPaths = try await files.retained().filter { phase == .failed || $0 != job?.directory.path } }
        catch { self.error = "Cannot inspect temporary microphone tests: \(error)" }
    }
    func start(input: AudioHardwareDevice?, microphoneUnmuted: Bool, routeStopped: Bool) {
        guard !engaged else { return }
        guard routeStopped else { error = "Stop this app's audio route before starting the independent microphone test."; return }
        guard microphoneUnmuted else { error = "Unmute the app-route microphone before starting this test."; return }
        guard let input, input.alive == 1, input.nominalRate == 48000, input.input.channels > 0 else {
            error = "Choose an available physical microphone at 48 kHz. No device rate is changed."; return
        }
        let token = UUID()
        guard captureAdmission.acquire(token, owner: .microphoneTest) else { error = "Another app audio operation owns microphone capture. Stop it before testing."; return }
        inputName = input.name
        id = token; cancelIntent = false; started = false; result = nil; sequence = 0; flight = nil
        frames = 0; error = nil; phase = .authorizing; status = "Checking microphone permission…"
        startTask = Task { [weak self] in
            guard let self else { return }
            let permission = self.authorization()
            var granted = permission == .authorized
            if permission == .notDetermined { granted = await self.requestAuthorization() }
            guard self.id == token, !self.cancelIntent, !Task.isCancelled else { return }
            guard granted else {
                self.error = "Microphone permission is required for this explicit test."; self.status = "Test did not start."; self.phase = .failed; self.captureAdmission.release(token); self.id = nil; return
            }
            self.phase = .preparing; self.status = "Preparing private temporary files…"
            do {
                let created = try await self.files.prepare(id: token, inputUID: input.uid)
                guard self.id == token else { try await self.files.remove(created); return }
                self.job = created // Cancellation now owns this stage even if its removal fails.
                guard !self.cancelIntent, !Task.isCancelled else { return }
                self.retainedPaths.removeAll { $0 == created.directory.path }
                let process = try self.factory(); self.child = process
                self.phase = .starting; self.status = "Starting selected microphone capture…"
                try process.launch(arguments: ["--microphone-test", "--input", input.uid, "--directory", created.directory.path,
                    "--operation-id", token.uuidString, "--control-stdin"],
                    line: { [weak self] in self?.receive($0, token: token, inputUID: input.uid) },
                    exit: { [weak self] in self?.exited($0, token: token) })
                if self.id == token, self.phase == .starting { self.armDeadline(token: token, duration: self.startupTimeout) }
            } catch {
                if self.id == token, let failure = error as? MicrophoneTestPreparationFailure { self.job = failure.job }
                guard self.id == token, !self.cancelIntent else { return }
                let underlying = (error as? MicrophoneTestPreparationFailure)?.underlying ?? error
                self.error = "Cannot start microphone test: \(underlying.localizedDescription)"; self.phase = .failed
                self.status = "Test did not start. Done removes any temporary files."
                await self.refreshRetained()
                if self.child?.running != true { self.child = nil }
                if self.job == nil { self.captureAdmission.release(token); self.id = nil }
            }
        }
    }
    private func armDeadline(token: UUID, duration: UInt64) {
        deadline?.cancel()
        deadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: duration) } catch { return }
            guard let self, self.id == token, self.phase != .comparison else { return }
            self.error = "The microphone test timed out. Cancelling capture and retaining files if cleanup cannot be confirmed."
            self.deadline = nil
            _ = await self.cancelAndCleanup()
        }
    }
    private func receive(_ line: String, token: UUID, inputUID: String) {
        guard id == token, !cancelIntent, let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["operationID"] as? String == token.uuidString, result == nil else { return }
        if object["event"] as? String == "test_started", !started {
            guard let value = try? JSONDecoder().decode(TestStarted.self, from: data), value.operationID == token.uuidString,
                  value.input_uid == inputUID, value.sampleRate == 48000, value.channels == 1,
                  value.minimumFrames == 240000, value.maximumFrames == 2880000, child?.running == true else {
                error = "The selected microphone could not be confirmed. Cancelling the test."
                phase = .failed
                Task { [weak self] in _ = await self?.cancelAndCleanup() }
                return
            }
            started = true; phase = .capturing; status = "Capturing the first microphone channel. Record at least 5 seconds; maximum 60 seconds."
            armDeadline(token: token, duration: operationTimeout)
        } else if object["event"] as? String == "test_progress" {
            guard started, let value = try? JSONDecoder().decode(TestProgress.self, from: data), value.operationID == token.uuidString,
                  value.frames >= frames, value.frames <= 2880000 else { return }
            frames = value.frames
            if frames == 2880000 { phase = .processing; status = "Capture limit reached. Finishing capture and RNNoise processing…" }
        } else if object["type"] as? String == "test-ack" {
            guard let value = try? JSONDecoder().decode(TestAck.self, from: data), value.operationID == token.uuidString,
                  value.sequence == flight?.sequence, value.action == flight?.action else { return }
            flight = nil
            if value.accepted { phase = .processing; status = "Finishing capture and RNNoise processing…" }
            else { phase = .capturing; error = value.error == "minimum_duration" ? "Record at least 5 captured seconds before Stop." : "Stop was rejected: \(value.error ?? "unknown reason")." }
        } else if object["event"] as? String == "test_result" {
            guard let value = try? JSONDecoder().decode(TestResult.self, from: data), value.operationID == token.uuidString else { return }
            result = value; phase = .validating; status = "Finishing the test before checking the temporary files…"
        }
    }
    func stop() {
        guard canStop, let token = id, let child, child.running else { return }
        phase = .stopping; error = nil; status = "Requesting capture stop…"
        do { try command("stop", token: token, process: child) }
        catch { phase = .failed; self.error = "Cannot request Stop: \(error). Use Cancel to end capture." }
    }
    private func command(_ action: String, token: UUID, process: any AudioHelperChild) throws {
        guard sequence < 9_007_199_254_740_991 else { throw MicrophoneTestError.unavailable }
        sequence += 1; flight = (sequence, action)
        var data = try JSONSerialization.data(withJSONObject: ["type": "test-" + action, "operationID": token.uuidString, "sequence": sequence])
        data.append(10); try process.send(data)
    }
    private func exited(_ event: HelperExit, token: UUID) {
        guard id == token else { return }
        deadline?.cancel(); deadline = nil
        resultTask = Task { [weak self] in
            guard let self, self.id == token, !self.cancelIntent else { return }
            guard event.status == 0, self.started, let result = self.result, result.status == "completed",
                  result.sampleRate == 48000, result.channels == 1, result.engine == "RNNoise",
                  result.adapterBufferingFrames == 480, result.adapterDelayAligned == true,
                  let original = result.originalPath, let processed = result.processedPath, let job = self.job else {
                self.phase = .failed
                self.error = self.result?.error ?? (event.diagnostic.isEmpty ? "No completed microphone comparison was confirmed." : event.diagnostic)
                self.status = "Test did not complete. Done removes files after the test stops."
                await self.refreshRetained(); return
            }
            self.phase = .validating; self.status = "Checking the completed comparison files…"
            do {
                try await self.files.validate(job, frames: result.frames, originalPath: original, processedPath: processed)
                guard self.id == token, !self.cancelIntent, !Task.isCancelled else { return }
                await self.playback.configure(id: token, original: job.original, processed: job.processed)
                guard self.id == token, !self.cancelIntent else { return }
                self.frames = result.frames; self.variant = .original; self.playing = false; self.playbackPosition = 0
                self.phase = .comparison; self.status = "Temporary comparison ready. Playback starts only when you press Play."
            } catch {
                guard self.id == token, !self.cancelIntent else { return }
                self.phase = .failed; self.error = "Comparison file validation failed: \(error)"
                await self.refreshRetained()
            }
        }
    }
    func select(_ selected: ComparisonVariant) {
        guard phase == .comparison, let token = id else { return }
        variant = selected
        Task { [weak self] in
            guard let self else { return }
            do { let state = try await self.playback.select(id: token, variant: selected); self.applyPlayback(state, token: token) }
            catch { if self.id == token { self.error = "Cannot switch comparison playback: \(error)" } }
        }
    }
    func play(replay: Bool = false) {
        guard phase == .comparison, let token = id else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let state = try await self.playback.play(id: token, replay: replay)
                self.applyPlayback(state, token: token); self.pollPlayback(token: token)
            } catch { if self.id == token { self.error = "Cannot play temporary comparison: \(error)" } }
        }
    }
    func pausePlayback() {
        guard let token = id else { return }
        Task { [weak self] in
            guard let self else { return }
            let state = await self.playback.pause(id: token); self.applyPlayback(state, token: token)
        }
    }
    private func applyPlayback(_ state: ComparisonPlaybackState, token: UUID) {
        guard id == token, phase == .comparison, !cancelIntent else { return }
        playing = state.playing; playbackPosition = state.position
    }
    private func pollPlayback(token: UUID) {
        playbackPoll?.cancel()
        playbackPoll = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 200_000_000) } catch { return }
                guard let self, self.id == token, self.phase == .comparison,
                      let state = await self.playback.snapshot(id: token) else { return }
                self.applyPlayback(state, token: token)
                if !state.playing { return }
            }
        }
    }
    /// Done, confirmed Cancel and normal Quit share this path. Never remove a live writer's files.
    func cancelAndCleanup() async -> Bool {
        guard !closing else { return false }
        let waitingForPermission = phase == .authorizing
        closing = true; cancelIntent = true; phase = .cancelling; status = "Ending the test and removing private temporary files…"
        defer { closing = false }
        deadline?.cancel(); deadline = nil; startTask?.cancel(); playbackPoll?.cancel(); playbackPoll = nil
        let token = id
        if waitingForPermission { id = nil } else { await startTask?.value }
        if let token { await playback.stop(id: token) }
        playing = false
        if let child {
            if child.running, let token { try? command("cancel", token: token, process: child) }
            if !(await child.waitForExit(timeoutNanoseconds: exitTimeout)) {
                child.terminate()
                guard await child.waitForExit(timeoutNanoseconds: exitTimeout) else {
                    phase = .failed; error = "The microphone test has not confirmed that it stopped. Files remain; retry Done before quitting."
                    if let job, !retainedPaths.contains(job.directory.path) { retainedPaths.append(job.directory.path) }
                    return false
                }
            }
        }
        await resultTask?.value
        if let job {
            do { try await files.remove(job) }
            catch { phase = .failed; self.error = "Cannot remove this test's private files: \(error)"; await refreshRetained(); return false }
        }
        if let token { captureAdmission.release(token) }
        child = nil; job = nil; id = nil; startTask = nil; resultTask = nil; flight = nil; result = nil
        phase = .idle; frames = 0; playbackPosition = 0; status = "Temporary test files removed. No history session was saved."
        await refreshRetained()
        return true
    }
}
