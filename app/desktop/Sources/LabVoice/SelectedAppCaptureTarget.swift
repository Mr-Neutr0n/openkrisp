import Foundation

struct SelectedAppCaptureTarget: Codable, Equatable, Sendable {
    struct Process: Codable, Equatable, Sendable {
        let objectID: UInt32
        let actualPID: Int
        enum CodingKeys: String, CodingKey { case objectID = "object_id", actualPID = "actual_pid" }
    }
    let responsiblePID: Int
    let appID: String
    let processes: [Process]
    enum CodingKeys: String, CodingKey { case responsiblePID = "responsible_pid", appID = "app_id", processes }
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.responsiblePID == rhs.responsiblePID && Data(lhs.appID.utf8) == Data(rhs.appID.utf8) && lhs.processes == rhs.processes
    }
}
struct SelectedAppCaptureSelection: Equatable, Sendable {
    let epoch: String
    let activationID: UUID
    let name: String
    let target: SelectedAppCaptureTarget
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.epoch == rhs.epoch && lhs.activationID == rhs.activationID && Data(lhs.name.utf8) == Data(rhs.name.utf8) && lhs.target == rhs.target
    }
    static func make(policy: LocalCallPolicy, snapshot: AudioProcessSnapshot?, epoch: String?, stale: Bool) -> Self? {
        guard !stale, policy.fresh, let current = policy.current, let epoch, let snapshot,
              snapshot.status == "available", snapshot.errors.isEmpty,
              snapshot.processes.allSatisfy({ $0.usageStale == false && $0.errors.isEmpty }),
              let call = policy.calls.first(where: { Data($0.name.utf8) == Data(current.utf8) }), policy.qualified(call),
              let appID = call.appID, !appID.isEmpty, let active = call.output.first,
              call.output.allSatisfy({ $0.pid == active.pid }), active.pid > 0 else { return nil }
        let rows = snapshot.processes.filter { $0.responsiblePID == active.pid }
        guard !rows.isEmpty, rows.allSatisfy({ row in
            guard let id = row.appID, let actual = row.actualPID else { return false }
            return Data(id.utf8) == Data(appID.utf8) && actual > 0 && row.objectID > 0
        }), call.output.allSatisfy({ usage in
            rows.contains { row in row.output.running == true && row.output.devices?.contains { String($0.objectID) == usage.deviceID } == true }
        }) else { return nil }
        let activeRows = rows.filter { $0.output.running == true && $0.output.devices?.isEmpty == false }
        guard !activeRows.isEmpty, activeRows.count <= 32, activeRows.allSatisfy({ !$0.responsiblePIDFallback && $0.stabilizationPending == false }) else { return nil }
        let tuples = activeRows.map { SelectedAppCaptureTarget.Process(objectID: $0.objectID, actualPID: $0.actualPID!) }.sorted { $0.objectID < $1.objectID }
        guard Set(tuples.map(\.objectID)).count == tuples.count, Set(tuples.map(\.actualPID)).count == tuples.count else { return nil }
        return .init(epoch: epoch, activationID: call.activationID, name: call.name,
                     target: .init(responsiblePID: active.pid, appID: appID, processes: tuples))
    }
}
