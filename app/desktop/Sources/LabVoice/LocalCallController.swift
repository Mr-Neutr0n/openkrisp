import Foundation
import Combine

private let callNameWhitespace: CharacterSet = {
    // ECMAScript whitespace differs from Foundation at U+0085 and U+FEFF.
    var characters = CharacterSet(charactersIn: "\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{0020}\u{00A0}\u{1680}\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}")
    characters.insert(charactersIn: UnicodeScalar(0x2000)!...UnicodeScalar(0x200A)!)
    return characters
}()
private func exactCallName(_ lhs: String, _ rhs: String) -> Bool { Data(lhs.utf8) == Data(rhs.utf8) }

// Observation policy only. A tracked call never admits physical capture or ASR.
struct LocalCallUsage: Equatable {
    let pid: Int
    let actualPids: String?
    let deviceID: String
    let isVirtual: Bool
    func matches(_ other: Self) -> Bool { pid == other.pid && deviceID == other.deviceID }
}
struct LocalTrackedCall: Identifiable {
    let name: String
    var appID: String? = nil
    var appVersion: String? = nil
    var input: [LocalCallUsage] = []
    var output: [LocalCallUsage] = []
    var lastInput: LocalCallUsage?
    var lastOutput: LocalCallUsage?
    var confirmed = false
    var started = false
    var starts = 0
    var id: Data { Data(name.utf8) }
    var bothLegs: Bool { !input.isEmpty && !output.isEmpty }
    var noLegs: Bool { input.isEmpty && output.isEmpty }
    var virtualMicrophone: Bool { input.contains { $0.isVirtual } }
    func usages(_ direction: AudioUsageDirection) -> [LocalCallUsage] { direction == .input ? input : output }
    mutating func add(_ usage: LocalCallUsage, direction: AudioUsageDirection, allApps: Bool) {
        var list = usages(direction)
        guard !list.contains(where: { $0.matches(usage) }) else { return }
        if direction == .input && allApps || usage.isVirtual {
            if let previous = list.first {
                if direction == .input { lastInput = previous } else { lastOutput = previous }
            }
            list.insert(usage, at: 0)
        } else { list.append(usage) }
        if direction == .input { input = list } else { output = list }
    }
    mutating func remove(_ usage: LocalCallUsage, direction: AudioUsageDirection) {
        var list = usages(direction)
        guard let index = list.firstIndex(where: { $0.matches(usage) }) else { return }
        if index == 0 {
            if direction == .input { lastInput = list[index] } else { lastOutput = list[index] }
        }
        list.remove(at: index)
        if direction == .input { input = list } else { output = list }
    }
}
struct LocalCallStopDeadline: Equatable {
    let name: String
    let began: TimeInterval
    let due: TimeInterval
}
struct LocalCallPolicy {
    var calls: [LocalTrackedCall] = []
    var current: String?
    var blocked: [String] = []
    var allApps = true
    var startDelay: TimeInterval = 0.5
    var stopDelay: TimeInterval = 1
    var stopDeadline: LocalCallStopDeadline?
    var fresh = false
    static func extra(_ name: String) -> TimeInterval { name.lowercased() == "safari" ? 0.3 : 0 }
    func qualified(_ call: LocalTrackedCall) -> Bool {
        call.bothLegs && (allApps || call.virtualMicrophone) && !isBlocked(call.name)
    }
    func isCurrent(_ name: String) -> Bool { current.map { exactCallName($0, name) } == true }
    func isBlocked(_ name: String) -> Bool { blocked.contains { exactCallName($0, name.lowercased()) } }
    mutating func invalidate() { fresh = false; current = nil; stopDeadline = nil }
    mutating func reset() { calls = []; current = nil; stopDeadline = nil; fresh = true }
    mutating func startNext() {
        guard fresh, current == nil else { return }
        stopDeadline = nil
        guard let index = calls.firstIndex(where: { !$0.started && qualified($0) }) else { return }
        current = calls[index].name; calls[index].started = true; calls[index].starts += 1
    }
    mutating func stop(startNext: Bool) {
        if let index = calls.firstIndex(where: { call in current.map { name in exactCallName(call.name, name) } == true }) {
            calls[index].started = false; calls[index].confirmed = false
            if calls[index].noLegs { calls.remove(at: index) }
        }
        current = nil; stopDeadline = nil
        if startNext { self.startNext() }
    }
    mutating func add(name rawName: String, usage: LocalCallUsage, direction: AudioUsageDirection, now: TimeInterval, appID: String? = nil, appVersion: String? = nil) {
        let name = rawName.trimmingCharacters(in: callNameWhitespace)
        guard fresh, !name.isEmpty else { return }
        if !calls.contains(where: { exactCallName($0.name, name) }) { calls.append(.init(name: name, appID: appID, appVersion: appVersion)) }
        let index = calls.firstIndex { exactCallName($0.name, name) }!
        calls[index].add(usage, direction: direction, allApps: allApps)
        if calls[index].bothLegs && (allApps || calls[index].virtualMicrophone) { calls[index].confirmed = true }
        if let deadline = stopDeadline, current.map { exactCallName($0, name) } == true, calls[index].bothLegs {
            stopDeadline = nil
            let previous = direction == .input ? calls[index].lastInput : calls[index].lastOutput
            if allApps && (previous?.deviceID != usage.deviceID || now - deadline.began < startDelay + Self.extra(name)) { return }
            stop(startNext: false)
        }
        startNext()
    }
    mutating func remove(name rawName: String, usage: LocalCallUsage, direction: AudioUsageDirection, now: TimeInterval) {
        let name = rawName.trimmingCharacters(in: callNameWhitespace)
        guard fresh, let index = calls.firstIndex(where: { exactCallName($0.name, name) }) else { return }
        calls[index].remove(usage, direction: direction)
        if current.map { exactCallName($0, name) } == true {
            if calls[index].bothLegs {
                if !allApps && calls[index].input.first?.isVirtual != true { stop(startNext: true) }
            } else if stopDeadline == nil {
                stopDeadline = .init(name: name, began: now, due: now + stopDelay + Self.extra(name))
            }
        } else if calls[index].noLegs { calls.remove(at: index) }
    }
    mutating func expire(_ deadline: LocalCallStopDeadline, now: TimeInterval) {
        guard fresh, stopDeadline == deadline, current.map { exactCallName($0, deadline.name) } == true, now >= deadline.due else { return }
        stop(startNext: true)
    }
    mutating func setBlocked(_ name: String, blocked value: Bool) {
        if value { if !isBlocked(name) { blocked.append(name.lowercased()) } }
        else { blocked.removeAll { exactCallName($0, name.lowercased()) } }
        guard fresh else { return }
        if value && current.map { exactCallName($0.lowercased(), name.lowercased()) } == true { stop(startNext: true) }
        else if !value { startNext() }
    }
    mutating func switchTo(_ name: String) {
        guard fresh, let previous = current, !exactCallName(previous, name),
              calls.contains(where: { exactCallName($0.name, name) }) else { return }
        stop(startNext: false)
        let requested = calls.remove(at: calls.firstIndex { exactCallName($0.name, name) }!)
        calls.insert(requested, at: 0)
        if let index = calls.firstIndex(where: { exactCallName($0.name, previous) }) { calls.append(calls.remove(at: index)) }
        startNext()
    }
}

enum LocalCallStreamDiff {
    struct Result {
        let retained: [GroupedAudioClient]
        let created: [GroupedAudioClient]
        let removed: [GroupedAudioClient]
    }
    static func same(_ lhs: GroupedAudioClient, _ rhs: GroupedAudioClient) -> Bool {
        lhs.direction == rhs.direction && lhs.clientPID == rhs.clientPID &&
            lhs.deviceID == rhs.deviceID && Data(lhs.appID.utf8) == Data(rhs.appID.utf8)
    }
    static func reconcile(_ incoming: [GroupedAudioClient], previous: [GroupedAudioClient],
                          compare: (String, String) -> ComparisonResult) -> Result {
        // JS sorts appId with no localeCompare options. Stable equal-ID order
        // preserves the native byte-key order supplied before this stage.
        let ordered = incoming.enumerated().sorted { lhs, rhs in
            let result = compare(lhs.element.appID, rhs.element.appID)
            return result == .orderedSame ? lhs.offset < rhs.offset : result == .orderedAscending
        }.map(\.element)
        var retained = previous, created: [GroupedAudioClient] = [], removed: [GroupedAudioClient] = []
        for client in ordered where !retained.contains(where: { same($0, client) }) {
            retained.append(client); created.append(client)
        }
        // Retain the original metadata for matching identities. Removal visits
        // the retained array backwards, after every addition has been emitted.
        for index in retained.indices.reversed() where !ordered.contains(where: { same($0, retained[index]) }) {
            removed.append(retained.remove(at: index))
        }
        return .init(retained: retained, created: created, removed: removed)
    }
}

@MainActor final class LocalCallController: ObservableObject {
    static let shared = LocalCallController()
    @Published private(set) var policy = LocalCallPolicy()
    @Published private(set) var note = "Start watching to track calls."
    private var clients: [AudioUsageDirection: [GroupedAudioClient]] = [:]
    private var generation: UInt64?
    private var timer: Task<Void, Never>?
    private var epoch = UUID()
    private let defaults: UserDefaults
    private let now: () -> TimeInterval
    private let automaticTimers: Bool
    private let compareApplicationIDs: (String, String) -> ComparisonResult
    init(defaults: UserDefaults = .standard, automaticTimers: Bool = true,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         compareApplicationIDs: @escaping (String, String) -> ComparisonResult = {
             $0.compare($1, options: [], locale: Locale.current)
         }) {
        self.defaults = defaults; self.automaticTimers = automaticTimers; self.now = now
        self.compareApplicationIDs = compareApplicationIDs
        policy.blocked = (defaults.stringArray(forKey: "localCallBlockedNames") ?? []).map { $0.lowercased() }
        policy.allApps = defaults.object(forKey: "localCallTrackAllApps") as? Bool ?? true
    }
    func invalidate(_ reason: String) {
        timer?.cancel(); timer = nil; epoch = UUID(); generation = nil
        clients = [:]; policy.invalidate(); note = reason
    }
    func receive(snapshot: AudioProcessSnapshot, generation incoming: UInt64, reason: String,
                 directions: [AudioUsageDirection], coalesced: UInt64) {
        guard snapshot.status == "available", snapshot.errors.isEmpty,
              snapshot.processes.allSatisfy({ $0.usageStale == false && $0.errors.isEmpty }) else {
            invalidate("Tracking paused. Audio use is incomplete."); return
        }
        if coalesced > 0 { invalidate("Tracking paused. Some audio-use updates were missed."); return }
        guard reason != "read_error" else { invalidate("Tracking paused. Audio-use read failed."); return }
        let grouped = AudioUsageGrouping.group(snapshot)
        guard grouped.complete else { invalidate("Tracking paused. Application or device identity is incomplete."); return }
        // Native clients use appID+deviceID byte order. PID presentation groups
        // and source object traversal do not define callback delivery order.
        let ordered = grouped.clients.sorted { $0.dedupKey.lexicographicallyPrecedes($1.dedupKey) }
        let timestamp = now()
        func replacement(_ direction: AudioUsageDirection) -> [GroupedAudioClient] {
            ordered.filter { $0.direction == direction && $0.clientPID != Int(ProcessInfo.processInfo.processIdentifier) &&
                Data($0.appID.utf8) != Data("dev.labvoice.desktop".utf8) && $0.deviceRole != .privateFeed && $0.deviceRole != .privateMonitor &&
                (policy.allApps || (direction == .input ? $0.deviceRole == .publicMicrophone : $0.deviceRole == .publicSpeaker)) }
        }
        // A complete baseline describes current use only. It does not replay
        // missing native callbacks or reconstruct call history before this frame.
        if generation != incoming || !policy.fresh {
            timer?.cancel(); timer = nil; epoch = UUID()
            generation = incoming
            clients = [:]; policy.reset()
            for direction in [AudioUsageDirection.input, .output] {
                let diff = LocalCallStreamDiff.reconcile(replacement(direction), previous: [], compare: compareApplicationIDs)
                clients[direction] = diff.retained
                for client in diff.created { add(client, now: timestamp) }
            }
            note = "Tracking refreshed. Earlier call changes are unknown. Tracking does not start recording."
        } else if reason == "changed" {
            for direction in directions {
                let diff = LocalCallStreamDiff.reconcile(replacement(direction), previous: clients[direction] ?? [], compare: compareApplicationIDs)
                clients[direction] = diff.retained
                for client in diff.created { add(client, now: timestamp) }
                for client in diff.removed { remove(client, now: timestamp) }
            }
            note = "Tracking does not start recording or request microphone access."
        }
        schedule()
    }
    private func usage(_ client: GroupedAudioClient) -> LocalCallUsage {
        .init(pid: client.clientPID, actualPids: client.actualPids, deviceID: client.deviceID,
              isVirtual: client.direction == .input ? client.deviceRole == .publicMicrophone : client.deviceRole == .publicSpeaker)
    }
    private func add(_ client: GroupedAudioClient, now: TimeInterval) {
        policy.add(name: client.appName ?? "", usage: usage(client), direction: client.direction, now: now, appID: client.appID, appVersion: client.appVersion)
    }
    private func remove(_ client: GroupedAudioClient, now: TimeInterval) {
        policy.remove(name: client.appName ?? "", usage: usage(client), direction: client.direction, now: now)
    }
    func setBlocked(_ name: String, blocked: Bool) {
        policy.setBlocked(name, blocked: blocked)
        defaults.set(policy.blocked.sorted(), forKey: "localCallBlockedNames"); schedule()
    }
    func setAllApps(_ enabled: Bool) {
        guard policy.allApps != enabled else { return }
        policy.allApps = enabled; defaults.set(enabled, forKey: "localCallTrackAllApps")
        invalidate("Tracking mode changed. Waiting for an audio-use update.")
    }
    func switchTo(_ name: String) { policy.switchTo(name); schedule() }
    private func schedule() {
        timer?.cancel(); timer = nil; epoch = UUID()
        guard automaticTimers, policy.fresh, let deadline = policy.stopDeadline else { return }
        let token = epoch
        let delay = max(0, deadline.due - now())
        timer = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) } catch { return }
            guard let self, self.epoch == token, PowerAdmission.shared.allowed else { return }
            self.policy.expire(deadline, now: self.now()); self.schedule()
        }
    }
}
