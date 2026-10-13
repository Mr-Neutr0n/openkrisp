import Foundation

struct AudioChannelControl: Codable, Equatable, Sendable {
    var muted = false
    var gain = 1.0
    var valid: Bool { gain.isFinite && (0...1).contains(gain) }
}
struct AudioControlSnapshot: Equatable, Sendable {
    var microphone = AudioChannelControl()
    var speaker = AudioChannelControl()
    var valid: Bool { microphone.valid && speaker.valid }
    var startupArguments: [String] {
        var arguments = ["--microphone-gain", String(microphone.gain), "--speaker-gain", String(speaker.gain)]
        if microphone.muted { arguments.append("--microphone-muted") }
        if speaker.muted { arguments.append("--speaker-muted") }
        return arguments
    }
}
struct AudioControlCommand: Encodable, Sendable {
    let type = "controls"
    let operationID: String
    let sequence: UInt64
    let microphone: AudioChannelControl
    let speaker: AudioChannelControl
    init(id: UUID, sequence: UInt64, snapshot: AudioControlSnapshot) {
        operationID = id.uuidString; self.sequence = sequence
        microphone = snapshot.microphone; speaker = snapshot.speaker
    }
    func line() throws -> Data {
        var bytes = try JSONEncoder().encode(self)
        bytes.append(10)
        return bytes
    }
}
struct AudioControlAcknowledgment: Decodable {
    let type: String
    let operationID: String
    let sequence: UInt64
    let accepted: Bool
    let error: String?
    let microphone: AudioChannelControl?
    let speaker: AudioChannelControl?
    var snapshot: AudioControlSnapshot? {
        guard let microphone, let speaker else { return nil }
        return AudioControlSnapshot(microphone: microphone, speaker: speaker)
    }
}
