import XCTest
import AVFoundation
import LocalStore
import LocalTranscription
@testable import LabVoice

@MainActor final class AppPowerLifecycleTests: XCTestCase {
    override func tearDown() { PowerAdmission.shared.setAllowed(true) }
    private func ready(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        XCTFail("Power fixture did not progress")
    }
    private func inventory() throws -> AudioInventory {
        try JSONDecoder().decode(AudioInventory.self, from: Data("{\"devices\":[{\"uid\":\"mic\",\"name\":\"Mic\",\"alive\":1,\"nominal_rate\":48000,\"input\":{\"channels\":1},\"output\":{\"channels\":0}},{\"uid\":\"speaker\",\"name\":\"Speaker\",\"alive\":1,\"nominal_rate\":48000,\"input\":{\"channels\":0},\"output\":{\"channels\":2}}],\"companion_devices\":[{\"uid\":\"dev.hari.labvoice.feed\",\"present\":true},{\"uid\":\"dev.hari.labvoice.monitor\",\"present\":true}],\"errors\":[]}".utf8))
    }
    func testNewestEventCoalescesAndSuspendDuringResumeNeverOpensAdmission() async throws {
        var stopGate: CheckedContinuation<PowerSuspendResult, Never>?, wakeGate: CheckedContinuation<String?, Never>?
        var stops = 0, wakes = 0, revokes = 0
        let power = AppPowerLifecycle(revoke: { revokes += 1 }, suspend: {
            stops += 1
            if stops == 1 { return await withCheckedContinuation { stopGate = $0 } }
            return .stopped
        }, resume: { wakes += 1; return await withCheckedContinuation { wakeGate = $0 } })
        power.request(.suspend); XCTAssertFalse(PowerAdmission.shared.allowed)
        try await ready { stopGate != nil }
        power.request(.resume); power.request(.suspend)
        stopGate?.resume(returning: .stopped); await power.waitUntilSettled()
        XCTAssertEqual(stops, 1); XCTAssertEqual(wakes, 0); XCTAssertEqual(power.state, .suspended)
        power.request(.resume); try await ready { wakeGate != nil }
        power.request(.suspend); XCTAssertFalse(PowerAdmission.shared.allowed)
        wakeGate?.resume(returning: nil); await power.waitUntilSettled()
        XCTAssertEqual(power.state, .suspended); XCTAssertFalse(PowerAdmission.shared.allowed)
        XCTAssertEqual(stops, 2); XCTAssertEqual(revokes, 3)
    }
    func testImmediateSuspendResumeStillCleansUpAndFailedCleanupRequiresRetry() async throws {
        var stops = 0, wakes = 0
        let power = AppPowerLifecycle(revoke: {}, suspend: { stops += 1; return .init(failure: stops == 1 ? "Helper remains live" : nil, blocking: stops == 1) }, resume: { wakes += 1; return wakes == 1 ? "Refresh failed" : nil })
        power.request(.suspend); power.request(.resume); await power.waitUntilSettled()
        XCTAssertEqual(stops, 1); XCTAssertEqual(wakes, 0); XCTAssertEqual(power.state, .failed)
        XCTAssertFalse(PowerAdmission.shared.allowed)
        power.request(.resume); await power.waitUntilSettled(); XCTAssertEqual(wakes, 0)
        power.retryCleanup(); await power.waitUntilSettled(); XCTAssertEqual(power.state, .suspended)
        power.request(.resume); await power.waitUntilSettled(); XCTAssertEqual(power.error, "Refresh failed")
        XCTAssertFalse(PowerAdmission.shared.allowed)
        power.request(.resume); await power.waitUntilSettled(); XCTAssertTrue(PowerAdmission.shared.allowed)
        XCTAssertEqual(power.state, .active); XCTAssertNil(power.error)
    }
    func testSuspendRevokesRealControllerPermissionAndWakeOnlyRefreshes() async throws {
        let snapshot = try inventory(); var permission: CheckedContinuation<Bool, Never>?, launches = 0
        let route = AudioRouteController(readInventory: { snapshot }, authorization: { .notDetermined }, requestAuthorization: { await withCheckedContinuation { permission = $0 } }, factory: { launches += 1; return PowerFixtureChild() })
        await route.refresh(); route.inputUID = "mic"; route.outputUID = "speaker"; route.start()
        try await ready { permission != nil }
        let power = AppPowerLifecycle(revoke: { route.revokeForPowerEvent() }, suspend: { await route.suspendForPowerEvent() }, resume: { await route.refreshForPowerResume() })
        power.request(.suspend)
        XCTAssertFalse(AudioCaptureAdmission.shared.available); XCTAssertFalse(route.recording.canStart)
        await power.waitUntilSettled(); permission?.resume(returning: true); await Task.yield()
        XCTAssertEqual(launches, 0); XCTAssertEqual(route.phase, .idle)
        power.request(.resume); await power.waitUntilSettled()
        XCTAssertEqual(power.state, .active); XCTAssertEqual(launches, 0); XCTAssertNotNil(route.inventory)
        _ = await route.stop()
    }
    func testSuspendRevokesPendingInventoryAndValidationPublication() async throws {
        let snapshot = try inventory(); var pending: CheckedContinuation<AudioInventory, Error>?, reads = 0
        let route = AudioRouteController(readInventory: { reads += 1; if reads == 1 { return try await withCheckedThrowingContinuation { pending = $0 } }; return snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { PowerFixtureChild() })
        let refresh = Task { await route.refresh() }; try await ready { pending != nil }
        let power = AppPowerLifecycle(revoke: { route.revokeForPowerEvent() }, suspend: { await route.suspendForPowerEvent() }, resume: { await route.refreshForPowerResume() })
        power.request(.suspend); pending?.resume(returning: snapshot); await refresh.value
        await power.waitUntilSettled(); XCTAssertNil(route.inventory); XCTAssertFalse(route.loading)
        await route.refresh(); XCTAssertEqual(reads, 1)
        await route.validateInstalledAEC(); await route.validateInstalledProvider()
        power.request(.resume); await power.waitUntilSettled(); XCTAssertEqual(reads, 2)
        XCTAssertNil(route.installedConfiguration); XCTAssertNil(route.installedAECConfiguration)
    }
    func testSuspendRevokesPendingProviderValidationAndMicrophoneTestPermission() async throws {
        let snapshot = try inventory()
        var validation: CheckedContinuation<InstalledNCConfiguration, Never>?
        let route = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { PowerFixtureChild() }, resolveInstalledProvider: { _, _, _ in await withCheckedContinuation { validation = $0 } })
        await route.refresh(); route.inputUID = "mic"; route.microphoneNoise = true; route.microphoneProvider = .installedKrisp
        route.selectInstalledApp(URL(fileURLWithPath: "/own/fixture.app")); route.selectInstalledNode(URL(fileURLWithPath: "/own/node"))
        let checking = Task { await route.validateInstalledProvider() }; try await ready { validation != nil }
        var permission: CheckedContinuation<Bool, Never>?, launches = 0
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let test = MicrophoneTestController(files: MicrophoneTestFiles(root: root), authorization: { .notDetermined }, requestAuthorization: { await withCheckedContinuation { permission = $0 } }, factory: { launches += 1; return PowerFixtureChild() })
        test.start(input: snapshot.devices[0], microphoneUnmuted: true, routeStopped: true)
        try await ready { permission != nil }
        let power = AppPowerLifecycle(revoke: { route.revokeForPowerEvent(); test.revokeForPowerEvent() }, suspend: {
            let stopped = await test.cancelAndCleanup()
            XCTAssertTrue(stopped)
            return await route.suspendForPowerEvent()
        }, resume: { await route.refreshForPowerResume() })
        power.request(.suspend); await power.waitUntilSettled()
        validation?.resume(returning: .init(nodePath: "/own/node", workerPath: "/own/worker", addonPath: "/own/addon", modelPath: "/own/model", adapterPath: "/own/adapter", libraryPath: "/own/lib", nodeSHA256: InstalledNCConfiguration.reviewedNodeSHA256, adapterSHA256: String(repeating: "a", count: 64), modelRole: .outbound))
        await checking.value; permission?.resume(returning: true); await Task.yield()
        XCTAssertNil(route.installedConfiguration); XCTAssertFalse(route.providerValidating)
        XCTAssertEqual(launches, 0); XCTAssertFalse(test.engaged)
        power.request(.resume); await power.waitUntilSettled(); XCTAssertNil(route.installedConfiguration)
    }
    func testAllRegisteredHistoryPlayersStopAndLatePlayCannotPublishAfterWake() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try LocalStore(root: root), domain = UUID().uuidString
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let session = try store.save(title: "Playback fixture", startedAt: Date(), durationSeconds: 1, transcript: [])
        let location = LibraryLocation(defaults: defaults, defaultRoot: root)
        let first = PowerLibraryWorker(store: store), second = PowerLibraryWorker(store: store)
        let one = LibraryModel(location: location, worker: first), two = LibraryModel(location: location, worker: second)
        let firstPlay = Task { await one.play(session.id) }, secondPlay = Task { await two.play(session.id) }
        try await ready { first.playGate != nil && second.playGate != nil }
        let power = AppPowerLifecycle(revoke: {}, suspend: { .stopped }, resume: { nil })
        power.register(one); power.register(two)
        power.request(.suspend); await power.waitUntilSettled()
        XCTAssertEqual(first.stops, 1); XCTAssertEqual(second.stops, 1)
        power.request(.resume); await power.waitUntilSettled()
        first.playGate?.resume(); second.playGate?.resume(); await firstPlay.value; await secondPlay.value
        XCTAssertFalse(one.playing); XCTAssertFalse(two.playing)
        XCTAssertEqual(first.stops, 2); XCTAssertEqual(second.stops, 2)
    }
    func testComparisonActorRejectsOldConfiguredPlaybackAfterPowerRoundtrip() async throws {
        let player = PowerComparisonPlayer(), playback = ComparisonPlayback(makePlayer: { _ in player }), id = UUID()
        await playback.configure(id: id, original: URL(fileURLWithPath: "/own/original.wav"), processed: URL(fileURLWithPath: "/own/processed.wav"))
        PowerAdmission.shared.setAllowed(false); PowerAdmission.shared.setAllowed(true)
        do { _ = try await playback.play(id: id, replay: false); XCTFail("Old comparison started") } catch { }
        XCTAssertEqual(player.plays, 0)
    }
    func testSuspendCancelsTranscriptionPermissionButKeepsReviewedTimingCandidate() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let domain = UUID().uuidString, defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: root) }
        let location = LibraryLocation(defaults: defaults, defaultRoot: root)
        var authorization = SpeechAuthorization.authorized, permission: CheckedContinuation<SpeechAuthorization, Error>?, recognizes = 0
        let result = OfflineTranscript(text: "Keep draft", localeIdentifier: "en_US", segments: [.init(text: "Keep", startSeconds: 0, durationSeconds: 0.2, confidence: 1)])
        let flow = ImportTranscription(authorization: { authorization }, requestAuthorization: { try await withCheckedThrowingContinuation { permission = $0 } }, recognize: { _, _ in recognizes += 1; return result }, cancelRecognition: {}, location: location)
        let file = root.appendingPathComponent("selected.wav")
        flow.start(file: file, locale: "en_US"); try await ready { !flow.busy }
        XCTAssertEqual(flow.completedText, result.text)
        authorization = .notDetermined
        flow.start(file: file, locale: "en_US"); try await ready { permission != nil }
        let power = AppPowerLifecycle(revoke: {}, suspend: { .stopped }, resume: { nil }); power.register(flow)
        power.request(.suspend); XCTAssertFalse(flow.busy)
        XCTAssertTrue(flow.hasTimings(file: file, text: result.text)); XCTAssertTrue(location.activities.isEmpty)
        flow.start(file: file, locale: "en_US"); XCTAssertFalse(flow.busy)
        await power.waitUntilSettled(); power.request(.resume); await power.waitUntilSettled()
        permission?.resume(returning: .authorized); await Task.yield()
        XCTAssertEqual(recognizes, 1); XCTAssertNil(flow.completedText)
        XCTAssertTrue(flow.hasTimings(file: file, text: result.text))
    }
    func testSuspendUsesRecordingFinalizationAndRetainsTerminalFailureWarningAcrossWake() async throws {
        for complete in [true, false] {
            let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let storage = RecordingStorage(stagingRoot: root.appendingPathComponent("staging"), storeRoot: root.appendingPathComponent("sessions"))
            let recording = RecordingController(storage: storage, timeout: 5_000_000)
            let snapshot = try inventory(), child = PowerFixtureChild(); child.completeRecording = complete
            let route = AudioRouteController(readInventory: { snapshot }, authorization: { .authorized }, requestAuthorization: { false }, factory: { child }, recording: recording)
            await route.refresh(); route.inputUID = "mic"; route.outputUID = "speaker"; route.start()
            try await ready { child.running }; child.ready(); XCTAssertEqual(route.phase, .running)
            recording.start(); try await ready { recording.phase == .recording }
            let power = AppPowerLifecycle(revoke: { route.revokeForPowerEvent() }, suspend: { await route.suspendForPowerEvent() }, resume: { await route.refreshForPowerResume() })
            power.request(.suspend); await power.waitUntilSettled()
            XCTAssertFalse(child.running); XCTAssertFalse(recording.busy); XCTAssertFalse(PowerAdmission.shared.allowed)
            if complete {
                XCTAssertNotNil(recording.savedSessionID)
                XCTAssertEqual(try LocalStore(root: root.appendingPathComponent("sessions")).inventory().sessions.count, 1)
            } else {
                XCTAssertNil(recording.savedSessionID); XCTAssertNotNil(recording.error)
                XCTAssertEqual(recording.retainedPaths.count, 1); XCTAssertNotNil(power.error)
                XCTAssertTrue(FileManager.default.fileExists(atPath: recording.retainedPaths[0]))
            }
            power.request(.resume); await power.waitUntilSettled()
            XCTAssertTrue(PowerAdmission.shared.allowed); XCTAssertEqual(route.phase, .idle)
            XCTAssertEqual(child.launches, 1)
            if !complete { XCTAssertNotNil(power.error); XCTAssertNotNil(recording.error); XCTAssertEqual(recording.retainedPaths.count, 1) }
        }
    }
}

@MainActor private final class PowerFixtureChild: AudioHelperChild {
    var running = false, completeRecording = true
    var launches = 0
    private var line: ((String) -> Void)?, exit: ((HelperExit) -> Void)?
    private var operation = "", path = ""
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        self.line = line; self.exit = exit; running = true; launches += 1
        operation = arguments[arguments.firstIndex(of: "--operation-id")! + 1]
    }
    private func emit(_ object: [String: Any]) { line?(String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)) }
    func ready() {
        emit(["event": "route_started", "operationID": operation, "input_uid": "mic", "output_uid": "speaker", "microphone_noise": false, "speaker_noise": false, "microphone_provider": "none", "speaker_provider": "none", "microphone": ["muted": false, "gain": 1], "speaker": ["muted": false, "gain": 1]])
    }
    func send(_ data: Data) throws {
        let command = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let type = command["type"] as? String, type.hasPrefix("recording-") else { return }
        let action = String(type.dropFirst(10))
        if action == "start" {
            path = command["path"] as! String
            try recordingFixtureWAV(frames: 48000).write(to: URL(fileURLWithPath: path))
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        }
        var ack = command; ack.removeValue(forKey: "path")
        ack["type"] = "recording-ack"; ack["action"] = action; ack["accepted"] = true; emit(ack)
        if action == "stop", completeRecording {
            emit(["type": "recording-result", "operationID": operation, "recordingID": command["recordingID"]!, "status": "completed", "path": path, "frames": 48000, "sampleRate": 48000, "channels": 2])
        }
    }
    func terminate() { running = false; exit?(.init(status: 0, output: Data(), diagnostic: "")) }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool { !running }
}

@MainActor private final class PowerLibraryWorker: LibraryWorking {
    let store: LocalStore
    var playGate: CheckedContinuation<Void, Never>?
    var stops = 0
    init(store: LocalStore) { self.store = store }
    func inventory(_ location: LibraryLocationSnapshot) async throws -> StoreInventory { try store.inventory() }
    func importWAV(_ url: URL, title: String, transcript: ImportTranscriptDraft, location: LibraryLocationSnapshot) async throws { XCTFail("Unexpected import") }
    func remove(_ id: UUID, location: LibraryLocationSnapshot) async throws { XCTFail("Unexpected delete") }
    func export(_ id: UUID, to url: URL, location: LibraryLocationSnapshot) async throws { XCTFail("Unexpected export") }
    func play(_ id: UUID, location: LibraryLocationSnapshot) async throws { await withCheckedContinuation { playGate = $0 } }
    func stop(revision: UUID?) async { stops += 1 }
    func isPlaying(revision: UUID) async -> Bool { false }
}
private final class PowerComparisonPlayer: ComparisonAudioPlayer, @unchecked Sendable {
    var currentTime = 0.0, duration = 1.0
    var isPlaying = false, plays = 0
    func prepareToPlay() -> Bool { true }
    func play() -> Bool { plays += 1; isPlaying = true; return true }
    func pause() { isPlaying = false }
    func stop() { isPlaying = false }
}
