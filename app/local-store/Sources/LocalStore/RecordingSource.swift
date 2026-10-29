import Foundation

/// Captured source identity and independent mixing policy, not proof of call identity.
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
    public let microphoneUID: String?
    public let microphoneObjectID: UInt32?
    public let microphoneChannel: UInt32?
    public let mixPolicy: String?
    public let timelinePolicy: String?
    public init(appName: String, appID: String, responsiblePID: Int, processes: [Process],
                microphoneUID: String? = nil, microphoneObjectID: UInt32? = nil) {
        kind = microphoneUID == nil ? "selected_app_output" : "selected_app_output_and_microphone"
        self.appName = appName; self.appID = appID
        self.responsiblePID = responsiblePID; self.processes = processes
        self.microphoneUID = microphoneUID; self.microphoneObjectID = microphoneObjectID
        microphoneChannel = microphoneUID == nil ? nil : 0
        mixPolicy = microphoneUID == nil ? nil : "app_half_mic_half"
        timelinePolicy = microphoneUID == nil ? nil : "adjacent_host_anchors_common_overlap"
    }
    public var isValid: Bool {
        let modeValid: Bool
        if let microphoneUID {
            modeValid = kind == "selected_app_output_and_microphone" && !microphoneUID.isEmpty &&
                microphoneUID.utf8.count <= 4096 && !microphoneUID.utf8.contains(0) &&
                microphoneChannel == 0 && mixPolicy == "app_half_mic_half" &&
                timelinePolicy == "adjacent_host_anchors_common_overlap" &&
                (microphoneObjectID == nil || microphoneObjectID! > 0)
        } else {
            modeValid = kind == "selected_app_output" && microphoneObjectID == nil &&
                microphoneChannel == nil && mixPolicy == nil && timelinePolicy == nil
        }
        return modeValid && !appName.isEmpty && !appID.isEmpty &&
        appName.utf8.count <= 4096 && appID.utf8.count <= 4096 &&
        !appName.utf8.contains(0) && !appID.utf8.contains(0) &&
        responsiblePID > 0 && responsiblePID <= Int(Int32.max) &&
        !processes.isEmpty && processes.count <= 32 &&
        Set(processes.map(\.objectID)).count == processes.count &&
        Set(processes.map(\.actualPID)).count == processes.count &&
        processes.allSatisfy { $0.objectID > 0 && $0.actualPID > 0 && $0.actualPID <= Int(Int32.max) }
    }
}
