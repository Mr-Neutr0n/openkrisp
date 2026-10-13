import SwiftUI

struct AudioView: View {
    @ObservedObject var audio: AudioRouteController
    @State private var testingMicrophone = false
    @Environment(\.dismiss) private var dismiss
    private var controlsLocked: Bool { audio.phase != .idle || audio.loading || AudioCaptureAdmission.shared.owner == .microphoneTest }
    private var status: String {
        switch audio.phase {
        case .idle: return "Audio stopped"
        case .authorizing: return "Waiting for microphone permission…"
        case .starting: return "Starting audio…"
        case .running: return "Audio running"
        case .stopping: return "Stopping audio…"
        }
    }
    private func deviceName(_ device: AudioHardwareDevice) -> String {
        let rate = device.nominalRate.isFinite ? String(format: "%.0f", device.nominalRate) : "unknown"
        return "\(device.name) · \(rate) Hz"
    }
    private func channelControls(_ name: String, muted: Bool, gain: Double,
                                 mute: @escaping (Bool) -> Void, volume: @escaping (Double) -> Void) -> some View {
        HStack {
            Toggle("Mute \(name.lowercased())", isOn: Binding(get: { muted }, set: mute)).frame(width: 180, alignment: .leading)
            Slider(value: Binding(get: { gain * 100 }, set: volume), in: 0...100, step: 1)
                .accessibilityLabel("\(name) app-route volume")
            Text("\(Int((gain * 100).rounded()))%").frame(width: 42, alignment: .trailing)
        }.disabled(!audio.controlsEditable)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Audio").font(.title2)
                Spacer()
                Button("Done") { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(status).font(.headline)
                    if let inventory = audio.inventory {
                        Picker("Physical microphone", selection: $audio.inputUID) {
                            Text("Choose a microphone").tag("")
                            ForEach(inventory.devices.filter { $0.input.channels > 0 }) { device in
                                Text(deviceName(device)).tag(device.uid)
                            }
                        }.disabled(controlsLocked)
                        Picker("Physical speaker", selection: $audio.outputUID) {
                            Text("Choose a speaker").tag("")
                            ForEach(inventory.devices.filter { $0.output.channels > 0 }) { device in
                                Text(deviceName(device)).tag(device.uid)
                            }
                        }.disabled(controlsLocked)
                        if !inventory.driverPresent {
                            Text("The Lab Voice audio driver is unavailable. Install it before starting audio.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        if !inventory.errors.isEmpty {
                            Text(inventory.errors.joined(separator: "\n")).font(.caption).foregroundColor(.red)
                        }
                    } else {
                        Text(audio.loading ? "Reading audio devices…" : "Refresh to read audio devices.")
                            .foregroundColor(.secondary)
                    }
                    Button("Test microphone…") { testingMicrophone = true }
                        .disabled(audio.phase != .idle || audio.loading || audio.recording.busy || audio.inventory?.devices.contains { $0.uid == audio.inputUID && $0.input.channels > 0 } != true)
                    Text("Choose devices currently running at 48 kHz. Device sample rates are not changed.")
                        .font(.caption).foregroundColor(.secondary)
                    Divider()
                    Text("Independent RNNoise processing").font(.headline)
                    Toggle("Reduce microphone noise", isOn: $audio.microphoneNoise).disabled(controlsLocked)
                    Toggle("Reduce speaker noise", isOn: $audio.speakerNoise).disabled(controlsLocked)
                    Text("Start captures the selected microphone and routes speaker audio. These options use the independent model, not the original Krisp models.")
                        .font(.caption).foregroundColor(.secondary)
                    if let active = audio.activeOptions, audio.phase == .running {
                        Text("Microphone reduction: \(active.microphoneNoise ? "on" : "off"). Speaker reduction: \(active.speakerNoise ? "on" : "off").")
                            .font(.caption)
                    }
                    Divider()
                    Text("App-route volume and mute").font(.headline)
                    channelControls("Microphone", muted: audio.desiredControls.microphone.muted,
                                    gain: audio.desiredControls.microphone.gain,
                                    mute: audio.setMicrophoneMuted, volume: audio.setMicrophonePercent)
                    channelControls("Speaker", muted: audio.desiredControls.speaker.muted,
                                    gain: audio.desiredControls.speaker.gain,
                                    mute: audio.setSpeakerMuted, volume: audio.setSpeakerPercent)
                    Text("Linear attenuation within this app. Hardware levels are unchanged. Mute silences this app’s output. Stop audio ends microphone capture.")
                        .font(.caption).foregroundColor(.secondary)
                    Text(audio.controlStatus).font(.caption)
                    if let accepted = audio.confirmedControls, audio.controlPending || audio.controlError != nil {
                        Text("Last accepted: microphone \(Int((accepted.microphone.gain * 100).rounded()))% \(accepted.microphone.muted ? "muted" : "unmuted"), speaker \(Int((accepted.speaker.gain * 100).rounded()))% \(accepted.speaker.muted ? "muted" : "unmuted").")
                            .font(.caption)
                    }
                    if let error = audio.controlError {
                        Text(error).font(.caption).foregroundColor(.red)
                        Button("Retry controls") { audio.retryControls() }
                            .disabled(audio.phase != .running || audio.controlPending)
                    }
                    Divider()
                    RecordingView(recording: audio.recording, routeRunning: audio.phase == .running)
                    if let error = audio.error { Text(error).foregroundColor(.red).font(.caption).textSelection(.enabled) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button("Refresh devices") { Task { await audio.refresh() } }.disabled(controlsLocked)
                Spacer()
                if audio.loading || [.authorizing, .starting, .stopping].contains(audio.phase) {
                    ProgressView().controlSize(.small)
                }
                if audio.phase == .idle {
                    Button("Start audio") { audio.start() }.disabled(!audio.canStart)
                } else {
                    Button("Stop audio") { Task { _ = await audio.stop() } }
                }
            }
        }.padding(24).frame(width: 580, height: 600)
        .task { await audio.refresh(); await audio.recording.refreshRetained() }
        .sheet(isPresented: $testingMicrophone) {
            MicrophoneTestView(audio: audio, input: audio.inventory?.devices.first { $0.uid == audio.inputUID })
        }
    }
}
