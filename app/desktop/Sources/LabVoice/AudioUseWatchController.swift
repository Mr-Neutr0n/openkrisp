import Foundation
import Combine

enum AudioUseWatchPhase { case idle, starting, watching, reconnecting, stopping, failed }
private struct AudioUseWatchEvent: Decodable {
    let version: Int
    let event: String
    let sequence: UInt64
    let generation: UInt64
    let snapshot: AudioProcessSnapshot?
    let message: String?
    let timingMode: String?
    let sourceState: String?
    let publicationReason: String?
    let changedDirections: [String]?
    let coalescedPublications: UInt64?
    let cleanupVerified: Bool?
    let allListenerRemovalsVerified: Bool?
    let listenersRemoved: UInt64?
    let listenersInvalidObjectRetired: UInt64?
    let listenersRemoveFailed: UInt64?
    enum CodingKeys: String, CodingKey {
        case version, event, sequence, generation, snapshot, message
        case timingMode = "timing_mode", sourceState = "source_state"
        case publicationReason = "publication_reason", changedDirections = "changed_directions", coalescedPublications = "coalesced_publications"
        case cleanupVerified = "cleanup_verified"
        case allListenerRemovalsVerified = "all_listener_removals_verified", listenersRemoved = "listeners_removed"
        case listenersInvalidObjectRetired = "listeners_invalid_object_retired", listenersRemoveFailed = "listeners_remove_failed"
    }
}

@MainActor final class AudioUseWatchController: ObservableObject {
    static let shared = AudioUseWatchController()
    @Published private(set) var phase: AudioUseWatchPhase = .idle
    @Published private(set) var snapshot: AudioProcessSnapshot?
    @Published private(set) var observedAt: Date?
    @Published private(set) var stale = true
    @Published private(set) var timingMode: String?
    @Published private(set) var sourceState: String?
    @Published private(set) var publicationReason: String?
    @Published private(set) var changedDirections: [AudioUsageDirection] = []
    @Published private(set) var coalescedPublications: UInt64 = 0
    @Published private(set) var coalescedPublicationTotal: UInt64 = 0
    @Published private(set) var error: String?
    @Published private(set) var cleanupVerified = false
    @Published private(set) var cleanDetachVerified = false
    @Published private(set) var allListenerRemovalsVerified: Bool?
    @Published private(set) var listenersRemoved: UInt64?
    @Published private(set) var listenersInvalidObjectRetired: UInt64?
    @Published private(set) var listenersRemoveFailed: UInt64?
    @Published private(set) var cleanupNote: String?
    private let factory: () throws -> any AudioHelperChild
    private let startupTimeout, stopTimeout: UInt64
    private var child: (any AudioHelperChild)?
    private var operationID: UUID?
    private var powerRevision: UUID?
    private var publicationAllowed = false
    private var sequence: UInt64 = 0, generation: UInt64 = 0
    private var stoppedAcknowledged = false
    private var exitEvent: HelperExit?
    private var deadline: Task<Void, Never>?
    private var stopTask: Task<Bool, Never>?
    private var processLifetime: AudioUseWatchController?
    var engaged: Bool { child != nil || stopTask != nil }
    var canStart: Bool { !engaged && PowerAdmission.shared.allowed && !QuitGate.shared.quitting }
    init(factory: (() throws -> any AudioHelperChild)? = nil,
         startupTimeout: UInt64 = 10_000_000_000, stopTimeout: UInt64 = 5_000_000_000) {
        self.factory = factory ?? { SystemAudioHelperChild(url: try AudioHelperServices.packagedURL(), outputMode: .streaming(maxLineBytes: 614400)) }
        self.startupTimeout = startupTimeout; self.stopTimeout = stopTimeout
    }
    func start() {
        guard canStart else { return }
        let id = UUID()
        do {
            let process = try factory()
            child = process; operationID = id; powerRevision = PowerAdmission.shared.revision
            processLifetime = self; publicationAllowed = true
            sequence = 0; generation = 0; stoppedAcknowledged = false; cleanupVerified = false; cleanDetachVerified = false
            allListenerRemovalsVerified = nil; listenersRemoved = nil; listenersInvalidObjectRetired = nil
            listenersRemoveFailed = nil; cleanupNote = nil
            exitEvent = nil; error = nil; stale = true; sourceState = nil; publicationReason = nil; changedDirections = []; coalescedPublications = 0; coalescedPublicationTotal = 0; phase = .starting
            try process.launch(arguments: ["--watch-audio-use-stabilized"], line: { [weak self] in self?.receive($0, id: id) }, exit: { [weak self] in self?.exited($0, id: id) })
            if operationID == id, phase == .starting {
                deadline = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: self?.startupTimeout ?? 0) } catch { return }
                    guard let self, self.operationID == id, self.phase == .starting else { return }
                    self.deadline = nil
                    self.fail("The audio-use helper did not return an initial observation.", id: id)
                }
            }
        } catch {
            child = nil; operationID = nil; processLifetime = nil; publicationAllowed = false
            stale = true; phase = .failed; self.error = "Cannot start audio-use observation: \(error.localizedDescription)"
        }
    }
    private func receive(_ line: String, id: UUID) {
        guard operationID == id else { return }
        guard let data = line.data(using: .utf8), let event = try? JSONDecoder().decode(AudioUseWatchEvent.self, from: data),
              event.version == 1, event.sequence > 0, event.generation > 0 else {
            fail("The audio-use helper returned an invalid stream event.", id: id); return
        }
        guard event.timingMode == "stabilized" else {
            fail("The audio-use helper did not return the requested stabilized timing mode.", id: id); return
        }
        guard event.sequence > sequence, event.generation >= generation else { return }
        sequence = event.sequence; generation = event.generation
        switch event.event {
        case "audio_use_snapshot":
            guard publicationAllowed, PowerAdmission.shared.allowed,
                  powerRevision == PowerAdmission.shared.revision else { return }
            guard let snapshot = event.snapshot, ["available", "failed", "unavailable"].contains(snapshot.status),
                  let source = event.sourceState, ["running", "restarting"].contains(source),
                  let reason = event.publicationReason, let directions = event.changedDirections, let coalesced = event.coalescedPublications,
                  Self.validPublication(source: source, status: snapshot.status, reason: reason, directions: directions) else {
                fail("The audio-use helper returned an invalid stabilized snapshot.", id: id); return
            }
            let total = coalescedPublicationTotal.addingReportingOverflow(coalesced)
            guard !total.overflow else { fail("The audio-use helper overflowed its publication-history counter.", id: id); return }
            coalescedPublications = coalesced; coalescedPublicationTotal = total.partialValue
            sourceState = source; publicationReason = reason
            changedDirections = directions.compactMap(AudioUsageDirection.init(rawValue:))
            deadline?.cancel(); deadline = nil
            if source == "restarting" {
                stale = true; phase = .reconnecting
                error = String((snapshot.errors.isEmpty ? "The audio-use source is reconnecting." : snapshot.errors.joined(separator: " ")).prefix(4096))
                return // Reset notifications are not an observed absence of apps.
            }
            guard snapshot.status == "available" else {
                stale = true; phase = .watching
                error = String((snapshot.errors.isEmpty ? "Audio-use observation is temporarily unavailable." : snapshot.errors.joined(separator: " ")).prefix(4096))
                return // A recoverable read failure does not terminate the source.
            }
            guard snapshot.processes.allSatisfy({ $0.usageStale != nil && $0.stabilizationPending != nil }),
                  reason != "restart_begin", reason != "restart_reset" else {
                fail("The audio-use helper omitted stabilized usage provenance.", id: id); return
            }
            self.snapshot = snapshot; observedAt = Date(); timingMode = "stabilized"
            stale = child?.running != true; error = nil; phase = .watching
        case "audio_use_error":
            preserveCleanupReport(event)
            let details = ([event.message ?? "Audio-use observation failed."] + (event.snapshot?.errors ?? [])).joined(separator: " ")
            fail(String(details.prefix(4096)), id: id)
        case "audio_use_stopped":
            guard event.cleanupVerified == true else { fail("Native audio-use listener cleanup was not verified.", id: id); return }
            let contradictory: Bool
            if event.allListenerRemovalsVerified == true {
                contradictory = (event.listenersInvalidObjectRetired ?? 0) > 0 || (event.listenersRemoveFailed ?? 0) > 0
            } else if event.allListenerRemovalsVerified == false,
                      let retired = event.listenersInvalidObjectRetired, let failed = event.listenersRemoveFailed {
                contradictory = retired == 0 && failed == 0
            } else { contradictory = false }
            guard !contradictory else { fail("The audio-use helper returned contradictory listener-cleanup results.", id: id); return }
            preserveCleanupReport(event)
            stoppedAcknowledged = true; publicationAllowed = false; stale = true
        default: fail("The audio-use helper returned an unknown stream event.", id: id)
        }
    }
    private static func validPublication(source: String, status: String, reason: String, directions: [String]) -> Bool {
        guard directions == [] || directions == ["input"] || directions == ["output"] || directions == ["input", "output"] else { return false }
        switch reason {
        case "readiness": return source == "running" && status == "available" && directions.isEmpty
        case "changed": return source == "running" && status == "available" && !directions.isEmpty
        case "restart_begin": return source == "restarting" && status == "unavailable" && directions.isEmpty
        case "restart_reset": return source == "restarting" && status == "unavailable" && directions == ["input", "output"]
        case "read_error": return directions.isEmpty // Failed, unavailable, or partial available observations.
        default: return false
        }
    }
    private func preserveCleanupReport(_ event: AudioUseWatchEvent) {
        allListenerRemovalsVerified = event.allListenerRemovalsVerified
        listenersRemoved = event.listenersRemoved
        listenersInvalidObjectRetired = event.listenersInvalidObjectRetired
        listenersRemoveFailed = event.listenersRemoveFailed
    }
    private func updateCleanupOutcome() {
        cleanupVerified = stoppedAcknowledged && exitEvent?.status == 0 && exitEvent?.diagnostic.isEmpty == true
        cleanDetachVerified = cleanupVerified && allListenerRemovalsVerified == true
        guard cleanupVerified, !cleanDetachVerified else { cleanupNote = nil; return }
        if let retired = listenersInvalidObjectRetired, retired > 0 {
            cleanupNote = "Observation stopped. \(retired) listener registrations belonged to vanished audio objects. Those objects were verified gone."
        } else if (listenersRemoveFailed ?? 0) > 0 {
            cleanupNote = "Observation stopped and listener ownership ended. Some listener-removal attempts failed."
        } else {
            cleanupNote = "Observation stopped and listener ownership ended. Individual listener-removal outcomes were not reported."
        }
    }
    private func fail(_ message: String, id: UUID) {
        guard operationID == id else { return }
        error = message; stale = true; publicationAllowed = false; phase = .failed
        deadline?.cancel(); deadline = nil
        Task { [weak self] in
            guard let self, self.operationID == id else { return }
            _ = await self.stop()
        }
    }
    private func exited(_ event: HelperExit, id: UUID) {
        guard operationID == id else { return }
        exitEvent = event; stale = true; publicationAllowed = false
        deadline?.cancel(); deadline = nil
        updateCleanupOutcome()
        if phase != .stopping {
            phase = .failed
            if !event.diagnostic.isEmpty {
                error = String(([error, event.diagnostic].compactMap { $0 }.joined(separator: " ")).prefix(4096))
            } else if error == nil {
                error = cleanupVerified ? "Audio-use observation ended." : "Audio-use helper exited without verified native listener cleanup."
            }
        }
        if stopTask == nil {
            child = nil; operationID = nil; processLifetime = nil
        }
    }
    func revokeForPowerEvent() {
        publicationAllowed = false; stale = true
        deadline?.cancel(); deadline = nil
    }
    // Process containment and clean native detach are different outcomes. A fully
    // drained exited helper can release ownership even if native teardown failed.
    // A live/undrained helper stays owned and blocks restart until Stop succeeds.
    func stop() async -> Bool {
        if let stopTask { return await stopTask.value }
        guard let process = child, let id = operationID else { stale = true; phase = .idle; return true }
        publicationAllowed = false; stale = true; phase = .stopping
        deadline?.cancel(); deadline = nil
        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            if process.running { try? process.send(Data("stop\n".utf8)) }
            var drained = await process.waitForExit(timeoutNanoseconds: self.stopTimeout)
            if !drained { process.terminate(); drained = await process.waitForExit(timeoutNanoseconds: self.stopTimeout) }
            guard self.operationID == id else { return drained }
            guard drained, !process.running else {
                self.phase = .failed; self.error = "The audio-use helper has not confirmed exit. Retry Stop before quitting."
                self.stopTask = nil; return false
            }
            self.updateCleanupOutcome()
            if !self.cleanupVerified, self.error == nil {
                self.error = "The audio-use helper has exited. Native listener cleanup was not verified."
            }
            self.child = nil; self.operationID = nil; self.stopTask = nil; self.processLifetime = nil
            self.phase = .idle
            return true
        }
        stopTask = task
        return await task.value
    }
}
