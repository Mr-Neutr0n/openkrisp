import Foundation
import Combine
import AVFoundation
import AppKit

enum AudioRoutePhase { case idle, authorizing, starting, running, stopping }

@MainActor final class AudioRouteController: ObservableObject {
    static let shared = AudioRouteController()
    let recording: RecordingController
    private let captureAdmission = AudioCaptureAdmission.shared
    private var admissionObservation: AnyCancellable?
    private var recordingObservation: AnyCancellable?
    @Published private(set) var inventory: AudioInventory? { didSet { audioUseObservedAt = nil; invalidateProvider(); invalidateAEC(); invalidateAccent() } }
    @Published private(set) var audioUseObservedAt: Date?
    @Published private(set) var loading = false
    @Published private(set) var phase: AudioRoutePhase = .idle { didSet { if phase != oldValue { DiagnosticEventLog.shared.append(component: .audio, code: phase == .idle ? .stopped : (phase == .running ? .started : .stateChanged), severity: .info) } } }
    @Published private(set) var activeOptions: AudioRouteOptions?
    @Published private(set) var error: String? { didSet { if error != nil && error != oldValue { DiagnosticEventLog.shared.append(component: .audio, code: .operationFailed, severity: .error) } } }
    @Published var inputUID = "" { didSet { if oldValue != inputUID { invalidateProvider(); invalidateAEC(); invalidateAccent() } } }
    private let headsetStore: HeadsetConfirmationStore
    @Published private(set) var headsetConfirmations: [HeadsetConfirmation]
    var selectedMicrophone: AudioHardwareDevice? { inventory?.devices.first { $0.uid == inputUID && $0.input.channels > 0 } }
    private let compatibilityStore: LocalHeadsetCompatibilityStore
    @Published private(set) var compatibilityLists = LocalHeadsetLists()
    @Published private(set) var compatibilityStatus = "No offline compatibility list loaded."
    var selectedCompatibility: LocalHeadsetCompatibility {
        guard let device = selectedMicrophone else { return .unknown("Choose a microphone.") }
        var lists = compatibilityLists
        lists.manual = headsetConfirmations.map { .init(name: .string($0.name)) }
        return LocalHeadsetPolicy.evaluate(device: device.localHeadsetPolicyDevice, lists: lists,
            mode: installedMicrophoneMode == .ordinaryNC ? .alwaysOff : .auto)
    }
    var selectedHeadsetConfirmed: Bool { selectedCompatibility.compatible }
    func importCompatibilityList(at url: URL) {
        guard canEditHeadsetConfirmations else { return }
        applyCompatibility(compatibilityStore.importFile(at: url, preserving: compatibilityLists))
    }
    func clearCompatibilityList() {
        guard canEditHeadsetConfirmations else { return }
        applyCompatibility(compatibilityStore.clear(preserving: compatibilityLists))
    }
    private func applyCompatibility(_ result: LocalHeadsetCacheLoad) {
        compatibilityStatus = result.failure ?? "Offline list loaded: \(result.lists.allowed.count) allowed, \(result.lists.blocked.count) blocked."
        if result.loaded { compatibilityLists = result.lists; invalidateProvider(); invalidateAEC(); invalidateAccent() }
    }
    var compatibilityDescription: String {
        switch selectedCompatibility {
        case .alwaysOff: return "Background voice is off. Ordinary noise cancellation selected."
        case .allowed: return "Offline allow list matched. Background voice selected."
        case .manualAllowed: return "Manual interface name matched. Background voice selected."
        case .blocked: return "Offline block list matched. Ordinary noise cancellation selected."
        case .lowRate: return "Microphone rate is below 16 kHz. Ordinary noise cancellation selected."
        case .userChoiceRequired: return "No compatibility match. Ordinary noise cancellation selected."
        case .unknown(let reason): return reason + " Ordinary noise cancellation selected."
        }
    }
    var requiresHeadsetConfirmation: Bool {
        false // Unavailable compatibility falls back to ordinary NC.
    }
    var canEditHeadsetConfirmations: Bool { !engaged && captureAdmission.available && !QuitGate.shared.quitting }
    func confirmSelectedHeadset() {
        guard canEditHeadsetConfirmations, let device = selectedMicrophone, device.alive == 1,
              let name = device.interfaceName, !name.isEmpty,
              headsetStore.confirm(name: name) else { return }
        headsetConfirmations = headsetStore.entries; invalidateProvider(); invalidateAEC(); invalidateAccent()
    }
    func removeHeadsetConfirmation(name: String) {
        guard canEditHeadsetConfirmations, headsetStore.remove(name: name) else { return }
        headsetConfirmations = headsetStore.entries; invalidateProvider(); invalidateAEC(); invalidateAccent()
    }
    func resetHeadsetConfirmations() {
        guard canEditHeadsetConfirmations, headsetStore.reset() else { return }
        headsetConfirmations = headsetStore.entries; installedMicrophoneMode = .backgroundVoice
        invalidateProvider(); invalidateAEC(); invalidateAccent()
    }
    @Published var outputUID = ""
    @Published var microphoneNoise = false { didSet { if oldValue != microphoneNoise { invalidateAEC(); if microphoneProvider == .installedKrisp { invalidateProvider() } } } }
    @Published var speakerNoise = false { didSet { if oldValue != speakerNoise, speakerProvider == .installedKrisp { invalidateProvider() } } }
    @Published var microphoneProvider: NoiseProvider = .rnnoise { didSet { if oldValue != microphoneProvider, microphoneNoise { invalidateProvider() } } }
    @Published var installedMicrophoneMode: InstalledMicrophoneMode = .ordinaryNC {
        didSet { if oldValue != installedMicrophoneMode { invalidateProvider(); invalidateAEC(); invalidateAccent() } }
    }
    var selectedMicrophoneRole: InstalledNCModelRole { selectedCompatibility.compatible ? .outboundHVC : .outbound }
    var unsupportedHVCWithAEC: Bool {
        echoCancellation && microphoneNoise && microphoneProvider == .installedKrisp && selectedMicrophoneRole == .outboundHVC
    }
    @Published var accentConversion = false { didSet { if oldValue != accentConversion { invalidateAccent() } } }
    @Published private(set) var accentModel: URL?
    @Published private(set) var installedAccentConfiguration: InstalledAccentConfiguration?
    @Published private(set) var accentValidating = false
    @Published private(set) var accentStatus = "Choose your local outbound accent model."
    private var accentValidationID = UUID()
    private let resolveAccent: (URL, URL, URL) async throws -> InstalledAccentConfiguration
    var unsupportedAccentCombination: Bool { accentConversion && (microphoneNoise || echoCancellation) }
    @Published var speakerProvider: NoiseProvider = .rnnoise { didSet { if oldValue != speakerProvider, speakerNoise { invalidateProvider() } } }
    @Published var echoCancellation = false { didSet { if oldValue != echoCancellation { invalidateAEC() } } }
    @Published private(set) var installedAECConfiguration: InstalledAECConfiguration?
    @Published private(set) var aecValidating = false
    @Published private(set) var aecStatus = "Choose the installed Krisp app to validate echo cancellation."
    private let resolveAEC: (URL) async throws -> InstalledAECConfiguration
    private var aecValidationID = UUID()
    @Published private(set) var installedApp: URL?
    @Published private(set) var installedNode: URL?
    @Published private(set) var installedConfiguration: InstalledNCConfiguration?
    @Published private(set) var installedSpeakerConfiguration: InstalledNCConfiguration?
    @Published private(set) var providerValidating = false
    @Published private(set) var providerStatus = "Choose the installed Krisp app and reviewed Node runtime."
    private let resolveProvider: (URL, URL, InstalledNCModelRole) async throws -> InstalledNCConfiguration
    private var providerValidationID = UUID()
    @Published private(set) var desiredControls = AudioControlSnapshot()
    @Published private(set) var confirmedControls: AudioControlSnapshot?
    @Published private(set) var controlPending = false
    @Published private(set) var controlError: String? { didSet { if controlError != nil && controlError != oldValue { DiagnosticEventLog.shared.append(component: .audio, code: .operationFailed, severity: .error) } } }
    private var controlSequence: UInt64 = 0
    private var controlFlight: (sequence: UInt64, snapshot: AudioControlSnapshot)?
    private var controlDeadline: Task<Void, Never>?
    private let controlTimeout: UInt64
    private let readInventory: () async throws -> AudioInventory
    private let readAudioUse: () async throws -> AudioInventory
    private let stopInventory: () async -> Bool
    private struct InventoryQuery {
        let id = UUID()
        var cancelled = false
        var finished = false
        var stopID: UUID?
        var stopTask: Task<Bool, Never>?
    }
    private var inventoryQuery: InventoryQuery?
    private func finishInventoryQueryIfDrained() {
        guard let query = inventoryQuery, query.finished, query.stopTask == nil else { return }
        inventoryQuery = nil; loading = false
    }

    private let authorization: () -> AVAuthorizationStatus
    private let requestAuthorization: () async -> Bool
    private let factory: () throws -> any AudioHelperChild
    private let startupTimeout: UInt64
    private let stopTimeout: UInt64
    private var child: (any AudioHelperChild)?
    private var operationID: UUID?
    private var startTask: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    var controlsEditable: Bool { captureAdmission.owner != .microphoneTest && !loading && (phase == .idle || phase == .running) }
    var controlStatus: String {
        if phase == .idle { return "Selected controls will apply at Start." }
        if controlPending { return "Control update pending…" }
        if controlError != nil { return "Latest controls are not confirmed." }
        if confirmedControls != nil { return "Controls accepted for upcoming callbacks." }
        return "Waiting for control confirmation…"
    }
    var engaged: Bool { phase != .idle || loading || recording.busy }
    var statusTitle: String {
        switch phase {
        case .idle: return "Audio stopped"
        case .authorizing: return "Waiting for microphone permission…"
        case .starting: return "Starting audio…"
        case .running: return "Audio running"
        case .stopping: return "Stopping audio…"
        }
    }
    var canStart: Bool {
        guard !requiresHeadsetConfirmation, !unsupportedHVCWithAEC, !unsupportedAccentCombination, !accentValidating,
              !(accentConversion && installedAccentConfiguration == nil), phase == .idle, !loading, !providerValidating, !aecValidating, !recording.busy,
              !(echoCancellation && installedAECConfiguration == nil),
              !(microphoneNoise && microphoneProvider == .installedKrisp && installedConfiguration?.modelRole != selectedMicrophoneRole),
              !(speakerNoise && speakerProvider == .installedKrisp && installedSpeakerConfiguration?.modelRole != .inbound), captureAdmission.available, !LibraryLocation.shared.switching, let inventory, inventory.driverPresent else { return false }
        return inventory.devices.contains { $0.uid == inputUID && $0.alive == 1 && $0.nominalRate == 48000 && (1...2).contains($0.input.channels) } &&
            inventory.devices.contains { $0.uid == outputUID && $0.alive == 1 && $0.nominalRate == 48000 && $0.output.channels == 2 }
    }
    init() {
        headsetStore = HeadsetConfirmationStore(); headsetConfirmations = headsetStore.entries
        compatibilityStore = LocalHeadsetCompatibilityStore()
        let loaded = compatibilityStore.load(preserving: .init()); compatibilityLists = loaded.lists; compatibilityStatus = loaded.failure ?? "Offline compatibility list loaded."
        recording = RecordingController()
        let accentResolver = InstalledAccentResolver()
        resolveAccent = { app, node, model in try await accentResolver.resolve(app: app, node: node, model: model, runtime: InstalledAccentResolver.packagedDirectory()) }
        let aecResolver = InstalledAECResolver()
        resolveAEC = { app in try await aecResolver.resolve(app: app, runtime: InstalledAECResolver.packagedDirectory()) }
        let resolver = InstalledNCResolver()
        resolveProvider = { app, node, role in try await resolver.resolve(app: app, node: node, runtime: InstalledNCResolver.packagedDirectory(), role: role) }
        let services = AudioHelperServices()
        readInventory = { try await services.inventory() }
        readAudioUse = { try await services.inventory(observeAudioUse: true) }
        stopInventory = { await services.stopInventory() }
        authorization = { MicrophonePermission.status() }
        requestAuthorization = { await MicrophonePermission.request() }
        factory = { try AudioHelperServices.makeChild() }
        startupTimeout = 10_000_000_000; stopTimeout = 10_000_000_000; controlTimeout = 2_000_000_000
        observeRecording()
    }
    init(readInventory: @escaping () async throws -> AudioInventory,
         readAudioUse: (() async throws -> AudioInventory)? = nil,
         stopInventory: @escaping () async -> Bool = { true },
         authorization: @escaping () -> AVAuthorizationStatus,
         requestAuthorization: @escaping () async -> Bool,
         factory: @escaping () throws -> any AudioHelperChild,
         startupTimeout: UInt64 = 10_000_000_000, stopTimeout: UInt64 = 10_000_000_000, controlTimeout: UInt64 = 2_000_000_000, recording: RecordingController? = nil,
         headsetStore: HeadsetConfirmationStore? = nil,
         compatibilityStore: LocalHeadsetCompatibilityStore? = nil,
         resolveInstalledProvider: @escaping (URL, URL, InstalledNCModelRole) async throws -> InstalledNCConfiguration = { app, node, role in
             try await InstalledNCResolver().resolve(app: app, node: node, runtime: InstalledNCResolver.packagedDirectory(), role: role)
         },
         resolveInstalledAccent: @escaping (URL, URL, URL) async throws -> InstalledAccentConfiguration = { app, node, model in
             try await InstalledAccentResolver().resolve(app: app, node: node, model: model, runtime: InstalledAccentResolver.packagedDirectory())
         },
         resolveInstalledAEC: @escaping (URL) async throws -> InstalledAECConfiguration = { app in
             try await InstalledAECResolver().resolve(app: app, runtime: InstalledAECResolver.packagedDirectory())
         }) {
        self.headsetStore = headsetStore ?? HeadsetConfirmationStore(); self.headsetConfirmations = self.headsetStore.entries
        self.compatibilityStore = compatibilityStore ?? LocalHeadsetCompatibilityStore()
        let loaded = self.compatibilityStore.load(preserving: .init()); compatibilityLists = loaded.lists; compatibilityStatus = loaded.failure ?? "Offline compatibility list loaded."
        self.resolveAccent = resolveInstalledAccent
        self.resolveAEC = resolveInstalledAEC
        self.recording = recording ?? RecordingController()
        self.resolveProvider = resolveInstalledProvider
        self.readInventory = readInventory; self.readAudioUse = readAudioUse ?? readInventory; self.stopInventory = stopInventory
        self.authorization = authorization; self.requestAuthorization = requestAuthorization
        self.factory = factory; self.startupTimeout = startupTimeout; self.stopTimeout = stopTimeout; self.controlTimeout = controlTimeout
        observeRecording()
    }
    private func observeRecording() {
        admissionObservation = captureAdmission.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        recordingObservation = recording.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
    func refresh() async { await refresh(allowSuspended: false) }
    func observeAudioUse() async { await refresh(allowSuspended: false, observeAudioUse: true) }
    private func refresh(allowSuspended: Bool, observeAudioUse: Bool = false) async {
        guard (allowSuspended || PowerAdmission.shared.allowed), phase == .idle, !loading, !QuitGate.shared.quitting else { return }
        let query = InventoryQuery(); inventoryQuery = query
        loading = true; error = nil
        defer {
            if inventoryQuery?.id == query.id {
                inventoryQuery?.finished = true
                finishInventoryQueryIfDrained()
            }
        }
        do {
            let result = try await (observeAudioUse ? readAudioUse() : readInventory())
            guard inventoryQuery?.id == query.id, inventoryQuery?.cancelled == false else { return }
            inventory = result
            if observeAudioUse, result.audioProcessUsage != nil { audioUseObservedAt = Date() }
            if !result.devices.contains(where: { $0.uid == inputUID && $0.input.channels > 0 }) { inputUID = "" }
            if !result.devices.contains(where: { $0.uid == outputUID && $0.output.channels > 0 }) { outputUID = "" }
        } catch {
            guard inventoryQuery?.id == query.id, inventoryQuery?.cancelled == false else { return }
            inventory = nil; self.error = error.localizedDescription
        }
    }
    func selectInstalledApp(_ url: URL) {
        guard phase == .idle else { return }
        installedApp = url; invalidateProvider(); invalidateAEC(); invalidateAccent()
    }
    func selectInstalledNode(_ url: URL) {
        guard phase == .idle else { return }
        installedNode = url; invalidateProvider(); invalidateAccent()
    }
    func selectAccentModel(_ url: URL) {
        guard phase == .idle else { return }
        accentModel = url; invalidateAccent()
    }
    private func invalidateAccent() {
        accentValidationID = UUID(); installedAccentConfiguration = nil; accentValidating = false
        accentStatus = "Validate your selected local accent files before Start."
    }
    func validateInstalledAccent() async {
        guard PowerAdmission.shared.allowed, phase == .idle, accentConversion, !accentValidating,
              let app = installedApp, let node = installedNode, let model = accentModel else { return }
        let id = UUID(); accentValidationID = id; accentValidating = true; installedAccentConfiguration = nil
        accentStatus = "Checking the local accent model and worker identities…"
        do {
            let configuration = try await resolveAccent(app,node,model)
            guard accentValidationID == id, phase == .idle, accentConversion else { return }
            installedAccentConfiguration = configuration
            accentStatus = "Outbound US accent model ready. Speech quality testing is pending."
        } catch {
            guard accentValidationID == id else { return }
            accentStatus = error.localizedDescription
        }
        if accentValidationID == id { accentValidating = false }
    }
    private func invalidateProvider() {
        providerValidationID = UUID(); installedConfiguration = nil; installedSpeakerConfiguration = nil; providerValidating = false
        providerStatus = "Validate the selected app and Node runtime before Start."
    }
    private func invalidateAEC() {
        aecValidationID = UUID(); installedAECConfiguration = nil; aecValidating = false
        aecStatus = "Validate echo cancellation for the selected app before Start."
    }
    func validateInstalledAEC() async {
        guard PowerAdmission.shared.allowed, phase == .idle, echoCancellation, !aecValidating, let app = installedApp else { return }
        let id = UUID(); aecValidationID = id; aecValidating = true; installedAECConfiguration = nil
        aecStatus = "Checking the installed echo canceller and packaged worker…"
        do {
            let configuration = try await resolveAEC(app)
            guard aecValidationID == id, phase == .idle, echoCancellation else { return }
            installedAECConfiguration = configuration
            aecStatus = "Echo cancellation is ready for Start."
        } catch {
            guard aecValidationID == id else { return }
            aecStatus = error.localizedDescription
        }
        if aecValidationID == id { aecValidating = false }
    }
    var requestedInstalledRoles: [InstalledNCModelRole] {
        (microphoneNoise && microphoneProvider == .installedKrisp ? [selectedMicrophoneRole] : []) +
        (speakerNoise && speakerProvider == .installedKrisp ? [.inbound] : [])
    }
    func validateInstalledProvider() async {
        let roles = requestedInstalledRoles
        guard PowerAdmission.shared.allowed, !requiresHeadsetConfirmation, phase == .idle, !providerValidating, !roles.isEmpty, let app = installedApp, let node = installedNode else { return }
        let id = UUID(); providerValidationID = id; providerValidating = true
        installedConfiguration = nil; installedSpeakerConfiguration = nil
        providerStatus = "Checking requested installed NC models and packaged worker identities…"
        do {
            var outbound: InstalledNCConfiguration?, inbound: InstalledNCConfiguration?
            for role in roles {
                let configuration = try await resolveProvider(app, node, role)
                guard providerValidationID == id, phase == .idle else { return }
                guard configuration.modelRole == role else { throw InstalledNCError.invalid("Validated model role does not match the requested audio direction.") }
                switch role {
                case .outbound, .outboundHVC: outbound = configuration
                case .inbound: inbound = configuration
                }
            }
            installedConfiguration = outbound; installedSpeakerConfiguration = inbound
            providerStatus = "Reviewed " + roles.map(\.rawValue).joined(separator: " and ") + " NC ready."
        } catch {
            guard providerValidationID == id else { return }
            providerStatus = error.localizedDescription
        }
        if providerValidationID == id { providerValidating = false }
    }
    func startupWait(for options: AudioRouteOptions) -> UInt64 {
        let workers = (options.installedProvider == nil ? 0 : 1) + (options.installedSpeakerProvider == nil ? 0 : 1) + (options.installedAEC == nil ? 0 : 1) + (options.installedAccent == nil ? 0 : 1)
        return workers > 0 ? UInt64(workers) * 30_000_000_000 + 10_000_000_000 : startupTimeout
    }
    // No permission request or --route launch occurs until this explicit Start action.
    private var powerRecordingPending = false
    func revokeForPowerEvent() {
        if recording.busy { powerRecordingPending = true }
        invalidateProvider(); invalidateAEC(); invalidateAccent()
        startTask?.cancel()
        inventoryQuery?.cancelled = true
        recording.objectWillChange.send()
    }
    func suspendForPowerEvent() async -> PowerSuspendResult {
        if recording.busy { powerRecordingPending = true }
        guard await stop() else { return .init(failure: error ?? "Audio cleanup is not confirmed.", blocking: true) }
        let deadline = DispatchTime.now().uptimeNanoseconds + stopTimeout
        while loading, DispatchTime.now().uptimeNanoseconds < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        guard !engaged else { return .init(failure: "Audio or recording cleanup is still pending. Retry Suspend.", blocking: true) }
        if powerRecordingPending {
            guard recording.savedSessionID != nil else {
                powerRecordingPending = false
                return .init(failure: "The interrupted recording was not saved. Any retained files remain available for recording recovery. No writer is active.", blocking: false)
            }
            powerRecordingPending = false
        }
        return .stopped
    }
    func refreshForPowerResume() async -> String? {
        invalidateProvider(); invalidateAEC(); invalidateAccent(); inventory = nil
        await refresh(allowSuspended: true)
        guard inventory != nil, !loading else { return error ?? "Device refresh did not complete. Retry Wake." }
        return nil
    }
    func start() {
        guard canStart else { return }
        let options = AudioRouteOptions(inputUID: inputUID, outputUID: outputUID,
                                        microphoneNoise: microphoneNoise, speakerNoise: speakerNoise,
                                        installedProvider: microphoneNoise && microphoneProvider == .installedKrisp ? installedConfiguration : nil,
                                        installedSpeakerProvider: speakerNoise && speakerProvider == .installedKrisp ? installedSpeakerConfiguration : nil,
                                        installedAEC: echoCancellation ? installedAECConfiguration : nil,
                                        installedAccent: accentConversion ? installedAccentConfiguration : nil)
        guard options.validProviderRoles else { return }
        let providerAdmissionID = providerValidationID, aecAdmissionID = aecValidationID, accentAdmissionID = accentValidationID
        let initialControls = desiredControls
        let id = UUID()
        guard captureAdmission.acquire(id, owner: .route) else { return }
        operationID = id; error = nil; controlError = nil
        resetControlSession(); phase = .authorizing
        startTask = Task { [weak self] in
            guard let self, self.operationID == id, !Task.isCancelled else { return }
            let status = self.authorization()
            var permitted = status == .authorized
            if status == .notDetermined { permitted = await self.requestAuthorization() }
            guard self.operationID == id, !Task.isCancelled else { return }
            guard permitted else {
                DiagnosticEventLog.shared.append(component: .audio, code: .permissionDenied, severity: .warning)
                self.error = "Microphone permission is required to start audio. Allow Lab Voice in macOS privacy settings."
                self.clear(); return
            }
            guard self.providerValidationID == providerAdmissionID, self.aecValidationID == aecAdmissionID,
                  self.accentValidationID == accentAdmissionID,
                  self.accentConversion == (options.installedAccent != nil),
                  self.microphoneNoise == options.microphoneNoise, self.echoCancellation == (options.installedAEC != nil),
                  self.inputUID == options.inputUID,
                  options.installedProvider == nil || self.selectedMicrophoneRole == options.installedProvider?.modelRole,
                  options.installedProvider?.modelRole != .outboundHVC ||
                    (self.selectedMicrophoneRole == .outboundHVC && self.selectedHeadsetConfirmed) else {
                self.error = "Microphone selection changed before startup. Start again."
                self.clear(); return
            }
            do {
                let process = try self.factory()
                self.child = process; self.phase = .starting
                try process.launch(arguments: options.arguments + ["--control-stdin", "--operation-id", id.uuidString] + initialControls.startupArguments, line: { [weak self] line in
                    self?.line(line, expected: options, initialControls: initialControls, id: id)
                }, exit: { [weak self] event in self?.exited(event, id: id) })
                if self.operationID == id, self.phase == .starting {
                    self.deadline = Task { [weak self] in
                        do { try await Task.sleep(nanoseconds: self?.startupWait(for: options) ?? 0) } catch { return }
                        guard let self, self.operationID == id, self.phase == .starting else { return }
                        self.error = "The audio helper did not confirm startup. Stopping it."
                        self.deadline = nil // Stop must not cancel its own timeout task before awaiting exit.
                        _ = await self.stop()
                    }
                }
            } catch {
                guard self.operationID == id else { return }
                self.error = "Cannot start audio helper: \(error.localizedDescription)"; self.clear()
            }
        }
    }
    private func line(_ line: String, expected: AudioRouteOptions, initialControls: AudioControlSnapshot, id: UUID) {
        guard operationID == id else { return }
        if recording.receive(line, operationID: id) { return }
        guard child?.running == true else { return }
        if phase == .running, let data = line.data(using: .utf8),
           let ack = try? JSONDecoder().decode(AudioControlAcknowledgment.self, from: data), ack.type == "controls-ack" {
            acknowledge(ack, id: id); return
        }
        guard phase == .starting,
              let data = line.data(using: .utf8), let ready = try? JSONDecoder().decode(AudioStartup.self, from: data),
              ready.event == "route_started" else { return }
        guard ready.matches(expected), ready.operationID == id.uuidString, ready.controls == initialControls, initialControls.valid else {
            error = "The audio helper confirmed a different device or processing configuration. Stopping it."
            Task { [weak self] in
                guard let self, self.operationID == id else { return }
                _ = await self.stop()
            }; return
        }
        deadline?.cancel(); deadline = nil
        activeOptions = expected; confirmedControls = ready.controls; phase = .running
        recording.attach(operationID: id) { [weak self] bytes in
            guard let self, self.operationID == id, self.phase == .running || self.phase == .stopping,
                  let process = self.child else { throw AudioHelperError.controlChannelClosed }
            try process.send(bytes)
        }
    }
    func setMicrophoneMuted(_ muted: Bool) {
        var next = desiredControls; next.microphone.muted = muted; updateControls(next)
    }
    func setSpeakerMuted(_ muted: Bool) {
        var next = desiredControls; next.speaker.muted = muted; updateControls(next)
    }
    func setMicrophonePercent(_ value: Double) {
        guard value.isFinite else { return }
        var next = desiredControls; next.microphone.gain = Double(Float(min(100, max(0, value)) / 100)); updateControls(next)
    }
    func setSpeakerPercent(_ value: Double) {
        guard value.isFinite else { return }
        var next = desiredControls; next.speaker.gain = Double(Float(min(100, max(0, value)) / 100)); updateControls(next)
    }
    private func updateControls(_ next: AudioControlSnapshot) {
        guard controlsEditable, next.valid, next != desiredControls else { return }
        desiredControls = next; controlError = nil
        publishLatestControls()
    }
    func retryControls() {
        guard phase == .running, !controlPending else { return }
        controlError = nil; publishLatestControls(force: true)
    }
    private func publishLatestControls(force: Bool = false) {
        guard phase == .running, let id = operationID, let process = child, process.running,
              controlFlight == nil, desiredControls.valid,
              force || desiredControls != confirmedControls else { return }
        guard controlSequence < 9_007_199_254_740_991 else {
            controlError = "The control sequence is exhausted. Stop and restart audio."; return
        }
        controlSequence += 1
        let sequence = controlSequence, snapshot = desiredControls
        controlFlight = (sequence, snapshot); controlPending = true
        do { try process.send(AudioControlCommand(id: id, sequence: sequence, snapshot: snapshot).line()) }
        catch {
            guard operationID == id, controlFlight?.sequence == sequence else { return }
            controlFlight = nil; controlPending = false
            controlError = "Cannot send controls. \(error.localizedDescription)"; return
        }
        guard operationID == id, controlFlight?.sequence == sequence else { return }
        controlDeadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: self?.controlTimeout ?? 0) } catch { return }
            guard let self, self.operationID == id, self.phase == .running,
                  self.controlFlight?.sequence == sequence else { return }
            self.controlFlight = nil; self.controlPending = false; self.controlDeadline = nil
            self.confirmedControls = nil
            self.controlError = "The helper did not confirm the latest controls. Current published values are unknown. Retry or stop audio."
        }
    }
    private func acknowledge(_ ack: AudioControlAcknowledgment, id: UUID) {
        guard operationID == id, phase == .running, ack.operationID == id.uuidString,
              let request = controlFlight, ack.sequence == request.sequence else { return }
        controlDeadline?.cancel(); controlDeadline = nil
        controlFlight = nil; controlPending = false
        guard ack.accepted else {
            controlError = "Control update rejected. " + (ack.error ?? "No reason supplied.")
            return
        }
        guard let snapshot = ack.snapshot, snapshot.valid, snapshot == request.snapshot else {
            controlError = "The helper confirmed different control values. Stopping audio."
            Task { [weak self] in
                guard let self, self.operationID == id else { return }
                _ = await self.stop()
            }
            return
        }
        confirmedControls = snapshot; controlError = nil
        publishLatestControls() // One queued snapshot: the newest slider positions.
    }
    private func resetControlSession() {
        controlDeadline?.cancel(); controlDeadline = nil
        controlFlight = nil; controlPending = false; confirmedControls = nil; controlSequence = 0
    }
    private func exited(_ event: HelperExit, id: UUID) {
        guard operationID == id else { return }
        let stopping = phase == .stopping
        if event.status != 0 {
            error = event.diagnostic.isEmpty ? "The audio helper exited with status \(event.status)." : event.diagnostic
        } else if !stopping {
            error = activeOptions == nil ? "The audio helper exited before confirming startup." : "The audio route ended."
        }
        Task { await recording.helperExited(operationID: id) }
        clear()
    }
    private func clear() {
        deadline?.cancel(); deadline = nil
        startTask?.cancel(); startTask = nil
        resetControlSession()
        if let operationID { captureAdmission.release(operationID) }
        operationID = nil; child = nil; activeOptions = nil; phase = .idle
    }
    func stop() async -> Bool {
        if var query = inventoryQuery {
            query.cancelled = true
            inventory = nil
            if query.stopTask == nil {
                query.stopID = UUID()
                query.stopTask = Task { await self.stopInventory() }
            }
            inventoryQuery = query
            let stopped = await query.stopTask!.value
            guard inventoryQuery?.id == query.id, inventoryQuery?.stopID == query.stopID else { return stopped }
            inventoryQuery?.stopTask = nil; inventoryQuery?.stopID = nil
            error = stopped ? nil : "The device query helper did not exit. Try Stop again before quitting."
            finishInventoryQueryIfDrained()
            // A cancelled read must unwind before another query may use its service slot.
            // This stop owns only that query, never a route started after its await.
            return stopped
        }
        deadline?.cancel(); deadline = nil
        startTask?.cancel(); startTask = nil
        guard let process = child else {
            await recording.finishAfterExit()
            clear(); return true
        }
        let id = operationID
        phase = .stopping; resetControlSession()
        await recording.prepareForRouteStop()
        process.terminate()
        let ended = await process.waitForExit(timeoutNanoseconds: stopTimeout)
        guard ended else {
            error = "The audio helper did not exit after Stop. Try Stop again before quitting."
            return false
        }
        if let id { await recording.helperExited(operationID: id) }
        if operationID == id { clear() }
        return true
    }
}

@MainActor final class LabVoiceApplicationDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var actionPending = false
    @Published private(set) var relaunchBlocked = false
    private var pendingIntent: AppExitIntent = .quit
    func applicationDidFinishLaunching(_ notification: Notification) { NativePowerNotifications.shared.start() }
    func applicationWillTerminate(_ notification: Notification) { NativePowerNotifications.shared.stop() }
    private var terminationApproved = false
    private var quitTask: Task<Void, Never>?
    private lazy var quit = QuitCoordinator(snapshot: {
        let audio = AudioRouteController.shared, test = MicrophoneTestController.shared
        let capture = SelectedAppCaptureController.shared
        let recording = audio.recording
        let saved = recording.savedSessionID != nil && !recording.busy
        let recordingActivity = recording.busy ? recording.libraryActivityID : nil
        return QuitSnapshot(recordingActive: recording.busy, audioEngaged: audio.engaged || AudioUseWatchController.shared.engaged,
                            testEngaged: test.engaged,
                            otherWork: LibraryLocation.shared.switching || LibraryLocation.shared.activities.keys.contains { $0 != recordingActivity && $0 != capture.libraryActivityID } || AudioCaptureAdmission.shared.owner == .recordingRecovery,
                            additionalRecordingActive: capture.engaged, additionalRecordingSaved: capture.savedSessionID != nil && !capture.engaged,
                            additionalRecordingFailure: capture.error, recordingSaved: saved, recordingFailure: saved ? nil : recording.error,
                            stopFailure: AudioUseWatchController.shared.engaged ? AudioUseWatchController.shared.error : audio.error, testFailure: test.error)
    }, confirmSave: { Self.confirmSave(intent: .quit) },
       stopAudio: {
           async let selectedStopped = SelectedAppCaptureController.shared.stop()
           async let watchStopped = AudioUseWatchController.shared.stop()
           let routeStopped = await AudioRouteController.shared.stop()
           let selectedDidStop = await selectedStopped, watchDidStop = await watchStopped
           return selectedDidStop && watchDidStop && routeStopped
       },
       cleanupTest: { await MicrophoneTestController.shared.cancelAndCleanup() },
       confirmRelaunchSave: { Self.confirmSave(intent: .relaunch) },
       launchForRelaunch: {
           guard let launcher = OwnAppRelauncher.current() else { return .failed("The current executable is unavailable.") }
           return await launcher.launch()
       })
    private static func confirmSave(intent: AppExitIntent) -> Bool {
        let relaunch = intent == .relaunch
        let alert = NSAlert()
        alert.messageText = relaunch ? "Save the recording and relaunch?" : "Save the recording and quit?"
        alert.informativeText = relaunch
            ? "Lab Voice will stop audio, save this recording, and open a new instance before this one exits. If saving or launch fails, this instance stays open."
            : "Lab Voice will stop audio, finalize this recording and save it to your library before quitting. If saving fails, the app will stay open."
        alert.addButton(withTitle: relaunch ? "Save and relaunch" : "Save and quit")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
    func requestRelaunch() {
        guard !actionPending, !relaunchBlocked else { return }
        pendingIntent = .relaunch
        NSApp.terminate(nil) // One termination delegate pipeline handles both intents.
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminationApproved { return .terminateNow }
        guard quitTask == nil else { return .terminateLater }
        let intent = pendingIntent; pendingIntent = .quit; actionPending = true
        quitTask = Task {
            let approved = await quit.request(intent: intent)
            if !approved, let reason = quit.reason {
                let alert = NSAlert(); alert.messageText = "Lab Voice is staying open"
                alert.informativeText = reason; alert.addButton(withTitle: "OK"); alert.runModal()
            }
            terminationApproved = approved; relaunchBlocked = quit.relaunchUncertain
            actionPending = approved; quitTask = nil
            sender.reply(toApplicationShouldTerminate: approved)
        }
        return .terminateLater
    }
}
