import Foundation

/// What was captured, not an assertion about call identity or microphone audio.
public struct RecordingSource: Codable, Equatable, Sendable {
    public struct Process: Codable, Equatable, Sendable {
        public let objectID: UInt32
        public let actualPID: Int
        public init(objectID: UInt32, actualPID: Int) {
            self.objectID = objectID; self.actualPID = actualPID
        }
    }
    public let kind: String
    public let appName: String
    public let appID: String
    public let responsiblePID: Int
    public let processes: [Process]
    public init(appName: String, appID: String, responsiblePID: Int, processes: [Process]) {
        kind = "selected_app_output"
        self.appName = appName; self.appID = appID
        self.responsiblePID = responsiblePID; self.processes = processes
    }
    public var isValid: Bool {
        kind == "selected_app_output" && !appName.isEmpty && !appID.isEmpty &&
        appName.utf8.count <= 4096 && appID.utf8.count <= 4096 &&
        !appName.utf8.contains(0) && !appID.utf8.contains(0) &&
        responsiblePID > 0 && responsiblePID <= Int(Int32.max) &&
        !processes.isEmpty && processes.count <= 32 &&
        Set(processes.map(\.objectID)).count == processes.count &&
        Set(processes.map(\.actualPID)).count == processes.count &&
        processes.allSatisfy { $0.objectID > 0 && $0.actualPID > 0 && $0.actualPID <= Int(Int32.max) }
    }
}
