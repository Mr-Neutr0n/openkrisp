import Foundation
import SwiftUI

struct AudioUsedDevice: Decodable, Sendable {
    let objectID: UInt32
    let uid: String?
    enum CodingKeys: String, CodingKey { case objectID = "object_id", uid }
}
struct AudioProcessDirection: Decodable, Sendable {
    let running: Bool?
    let devices: [AudioUsedDevice]?
    var description: String {
        guard let running else { return "unknown" }
        guard running else { return "not running" }
        guard let devices else { return "running, device usage unknown" }
        if devices.isEmpty { return "running, no device reported" }
        return "running on " + devices.map { $0.uid ?? "unknown UID for object \($0.objectID)" }.joined(separator: ", ")
    }
}
struct AudioProcessUsage: Decodable, Identifiable, Sendable {
    let objectID: UInt32
    let actualPID: Int?
    let responsiblePID: Int?
    let responsiblePIDFallback: Bool
    let responsiblePIDResolution: String
    let appName: String?
    let appID: String?
    let processBundleID: String?
    let responsibleBundleID: String?
    let input: AudioProcessDirection
    let output: AudioProcessDirection
    let errors: [String]
    var id: UInt32 { objectID }
    enum CodingKeys: String, CodingKey {
        case objectID = "object_id", actualPID = "actual_pid", responsiblePID = "responsible_pid"
        case responsiblePIDFallback = "responsible_pid_fallback", responsiblePIDResolution = "responsible_pid_resolution"
        case appName = "app_name", appID = "app_id", processBundleID = "process_bundle_id", responsibleBundleID = "responsible_bundle_id"
        case input, output, errors
    }
}
struct AudioProcessSnapshot: Decodable, Sendable {
    let status: String
    let errors: [String]
    let processes: [AudioProcessUsage]
    var summary: String {
        guard status == "available" else { return status == "unavailable" ? "Audio-use observation is unavailable." : "Audio-use observation failed. Process usage is unknown." }
        let partial = processes.filter { !$0.errors.isEmpty }.count
        return "\(processes.count) audio processes checked." + (partial == 0 ? "" : " \(partial) have incomplete properties.")
    }
}
struct AudioProcessUsageView: View {
    let snapshot: AudioProcessSnapshot?
    let observedAt: Date?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audio use").font(.headline)
            Text("Shows audio use when you checked. Check again to refresh. This does not identify calls or start recording.").font(.caption).foregroundColor(.secondary)
            if let snapshot {
                if let observedAt { Text("Checked " + observedAt.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundColor(.secondary) }
                Text(snapshot.summary).font(.caption)
                ForEach(Array(snapshot.errors.enumerated()), id: \.offset) { Text($0.element).font(.caption).foregroundColor(.orange) }
                if snapshot.status == "available" {
                    ForEach(snapshot.processes) { process in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(process.appName ?? "Unknown application").font(.caption).bold()
                            Text("Actual PID \(process.actualPID.map(String.init) ?? "unknown"), responsible PID \(process.responsiblePID.map(String.init) ?? "unknown")").font(.caption)
                            Text("Input: \(process.input.description). Output: \(process.output.description).").font(.caption).textSelection(.enabled)
                            Text("Application ID: \(process.appID ?? "unknown")").font(.caption).textSelection(.enabled)
                            if process.responsiblePIDFallback { Text("Responsibility lookup fell back to the actual PID.").font(.caption).foregroundColor(.secondary) }
                            if !process.errors.isEmpty { Text(process.errors.joined(separator: "\n")).font(.caption).foregroundColor(.orange) }
                        }
                    }
                }
            } else { Text("Choose Observe audio use to check current usage.").font(.caption).foregroundColor(.secondary) }
        }
    }
}
