import Foundation

enum AudioUsageDirection: String, Sendable { case input, output }
enum AudioUsageDeviceRole: Sendable, Equatable {
    case publicMicrophone, publicSpeaker, privateFeed, privateMonitor, other, unknown
    init(uid: String?) {
        switch uid {
        case "dev.hari.labvoice.microphone": self = .publicMicrophone
        case "dev.hari.labvoice.speaker": self = .publicSpeaker
        case "dev.hari.labvoice.feed": self = .privateFeed
        case "dev.hari.labvoice.monitor": self = .privateMonitor
        case .none: self = .unknown
        default: self = .other
        }
    }
    var label: String? {
        switch self {
        case .publicMicrophone: return "Lab Voice microphone"
        case .publicSpeaker: return "Lab Voice speaker"
        case .privateFeed: return "Internal app feed"
        case .privateMonitor: return "Internal app monitor"
        case .other, .unknown: return nil
        }
    }
}
struct GroupedAudioClient: Identifiable, Sendable {
    let direction: AudioUsageDirection
    let clientPID: Int
    let actualPids: String?
    let appName: String?
    let appID: String
    var appVersion: String? = nil
    let deviceID: String
    let deviceUID: String?
    let sourceObjectID: UInt32
    let incomplete: Bool
    var stale = false
    var stabilizationPending = false
    var deviceRole: AudioUsageDeviceRole { .init(uid: deviceUID) }
    // Native dedup concatenates strings without a separator. Data preserves exact
    // UTF-8 identity rather than Swift String's canonical-equivalence comparison.
    var dedupKey: Data { Data((appID + deviceID).utf8) }
    var id: String { direction.rawValue + ":" + dedupKey.base64EncodedString() }
    var deviceDescription: String { deviceRole.label ?? deviceUID ?? "Unknown device \(deviceID)" }
}
struct GroupedAudioApplication: Identifiable, Sendable {
    let id: Int
    let clients: [GroupedAudioClient]
    var name: String { clients.compactMap(\.appName).first ?? "Unknown application" }
    var actualPids: String? { clients.first?.actualPids }
}
struct GroupedAudioUsage: Sendable {
    let applications: [GroupedAudioApplication]
    let issues: [String]
    let sourceAvailable: Bool
    var clients: [GroupedAudioClient] { applications.flatMap(\.clients) }
    var complete: Bool { sourceAvailable && issues.isEmpty && clients.allSatisfy { !$0.incomplete } }
}
struct NormalizedAudioInput {
    let devices: [AudioUsedDevice]?
    let issue: String?
}
enum AudioUsageGrouping {
    private static func uniqueDevices(_ direction: AudioProcessDirection) -> [AudioUsedDevice]? {
        guard let running = direction.running, let devices = direction.devices,
              !devices.contains(where: { $0.objectID == 0 }), running || devices.isEmpty else { return nil }
        var unique: [UInt32: AudioUsedDevice] = [:]
        for device in devices {
            if let prior = unique[device.objectID] {
                let uid = prior.uid.map { Data($0.utf8) } == device.uid.map { Data($0.utf8) } ? prior.uid : nil
                unique[device.objectID] = .init(objectID: device.objectID, uid: uid,
                    hasInputStreams: prior.hasInputStreams == device.hasInputStreams ? prior.hasInputStreams : nil)
            } else { unique[device.objectID] = device }
        }
        return unique.values.sorted { $0.objectID < $1.objectID }
    }
    static func normalizeInput(_ input: AudioProcessDirection, output: AudioProcessDirection) -> NormalizedAudioInput {
        guard var devices = uniqueDevices(input) else { return .init(devices: nil, issue: "Input usage is unknown.") }
        // The native sorted-set algorithm has two separate passes. Both stop as
        // soon as only one input device remains, even if that last device lacks
        // streams or also appears in output. Unvisited unknowns do not matter.
        for device in devices {
            if devices.count < 2 { break }
            guard let hasStreams = device.hasInputStreams else {
                return .init(devices: nil, issue: "Input device normalization needs unavailable stream metadata.")
            }
            if !hasStreams { devices.removeAll { $0.objectID == device.objectID } }
        }
        if devices.count > 1 {
            guard let outputDevices = uniqueDevices(output) else {
                return .init(devices: nil, issue: "Input device normalization needs the unknown output-device set.")
            }
            let outputIDs = Set(outputDevices.map(\.objectID))
            for device in devices {
                if devices.count < 2 { break }
                if outputIDs.contains(device.objectID) { devices.removeAll { $0.objectID == device.objectID } }
            }
        }
        return .init(devices: devices, issue: nil)
    }
    static func group(_ snapshot: AudioProcessSnapshot) -> GroupedAudioUsage {
        guard snapshot.status == "available" else { return .init(applications: [], issues: snapshot.errors, sourceAvailable: false) }
        var issues = snapshot.errors
        let records = snapshot.processes.sorted { $0.objectID < $1.objectID }
        let unknownOwner = records.contains { ($0.responsiblePID ?? 0) <= 0 }
        var siblingPIDs: [Int: Set<Int>] = [:], incompleteSiblingOwners = Set<Int>()
        for record in records {
            guard let owner = record.responsiblePID, owner > 0 else { continue }
            if let actual = record.actualPID, actual > 0 { siblingPIDs[owner, default: []].insert(actual) }
            else { incompleteSiblingOwners.insert(owner) }
            // Conservative provenance: a held stale sibling may retain identity
            // from before a failed read. Do not claim its helper list is current.
            if record.usageStale == true { incompleteSiblingOwners.insert(owner) }
        }
        var inputKeys: [Data: GroupedAudioClient] = [:], outputKeys: [Data: GroupedAudioClient] = [:]
        var clients: [GroupedAudioClient] = []
        for record in records {
            if record.usageStale == true { issues.append("Process object \(record.objectID) retains last observed usage.") }
            if !record.errors.isEmpty { issues.append("Process object \(record.objectID) has incomplete properties.") }
            let normalized = normalizeInput(record.input, output: record.output)
            let directions: [(AudioUsageDirection, [AudioUsedDevice]?, String?)] = [
                (.input, normalized.devices, normalized.issue),
                (.output, uniqueDevices(record.output), "Output usage is unknown.")]
            for (direction, devices, issue) in directions {
                guard let devices else {
                    issues.append("Process object \(record.objectID): " + (issue ?? "Usage is unknown.")); continue
                }
                guard !devices.isEmpty else { continue }
                guard let owner = record.responsiblePID, owner > 0,
                      let actual = record.actualPID, actual > 0, let appID = record.appID else {
                    issues.append("Process object \(record.objectID) has audio use with unknown application identity."); continue
                }
                let siblingsComplete = !unknownOwner && !incompleteSiblingOwners.contains(owner)
                let actualPids = siblingsComplete ? siblingPIDs[owner, default: []].sorted().map(String.init).joined(separator: ",") : nil
                for device in devices {
                    let client = GroupedAudioClient(direction: direction, clientPID: owner, actualPids: actualPids,
                        appName: record.appName, appID: appID, appVersion: record.appVersion, deviceID: String(device.objectID), deviceUID: device.uid,
                        sourceObjectID: record.objectID, incomplete: !record.errors.isEmpty || !siblingsComplete || device.uid == nil || record.appName == nil || record.usageStale == true,
                        stale: record.usageStale == true, stabilizationPending: record.stabilizationPending == true)
                    let previous = direction == .input ? inputKeys[client.dedupKey] : outputKeys[client.dedupKey]
                    if let previous {
                        if previous.clientPID != client.clientPID || Data(previous.appID.utf8) != Data(client.appID.utf8) || previous.deviceID != client.deviceID {
                            issues.append("Conflicting application/device keys were deduplicated in \(direction.rawValue).")
                        }
                        continue
                    }
                    if direction == .input { inputKeys[client.dedupKey] = client } else { outputKeys[client.dedupKey] = client }
                    clients.append(client)
                }
            }
        }
        if unknownOwner || !incompleteSiblingOwners.isEmpty { issues.append("Some helper-process identities are unknown; complete helper PID groups are unavailable.") }
        let owners = Set(clients.map(\.clientPID)).sorted()
        let applications = owners.map { owner in GroupedAudioApplication(id: owner, clients: clients.filter { $0.clientPID == owner }) }
        return .init(applications: applications, issues: Array(Set(issues)).sorted(), sourceAvailable: true)
    }
}
