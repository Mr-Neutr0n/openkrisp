import SwiftUI

struct RecordingView: View {
    @ObservedObject var recording: RecordingController
    let routeRunning: Bool
    private var capturing: Bool { [.starting, .recording, .pausing, .resuming, .uncertain].contains(recording.phase) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(capturing ? Color.red : (recording.phase == .paused ? Color.orange : Color.secondary))
                    .frame(width: 9, height: 9).accessibilityHidden(true)
                Text("Local session recording").font(.headline)
            }
            Text("Records an independent stereo mix of processed microphone and speaker audio, with each source scaled to 50%. Route volume and mute affect the file. No automatic recording or transcription.")
                .font(.caption).foregroundColor(.secondary)
            Text(recording.message).font(.caption)
            HStack {
                Button("Start recording") { recording.start() }
                    .disabled(!routeRunning || !recording.canStart)
                Button(recording.phase == .paused ? "Resume recording" : "Pause recording") { recording.pauseOrResume() }
                    .disabled(!routeRunning || ![.recording, .paused].contains(recording.phase))
                Button("Stop recording") { recording.stop() }
                    .disabled(!routeRunning || ![.recording, .paused, .starting, .pausing, .resuming, .uncertain].contains(recording.phase))
            }
            Text("Stop recording finalizes and saves the written audio to local history. Pause excludes audio until Resume. Stop audio also finalizes the active recording.")
                .font(.caption).foregroundColor(.secondary)
            if let error = recording.error { Text(error).font(.caption).foregroundColor(.red).textSelection(.enabled) }
            RetainedRecordingNotice(recording: recording)
        }
    }
}

struct RetainedRecordingNotice: View {
    @ObservedObject var recording: RecordingController
    @ObservedObject private var recovery = RecordingRecoveryController.shared
    @State private var confirmation: RecordingRecoveryRequest?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
                if !recording.retainedPaths.isEmpty { Text("\(recording.retainedPaths.count) recording staging folder(s) remain. They are not saved sessions. No files were deleted automatically.") }
                Text("Partial files may be invalid. Recovery only copies validated finalized audio and never repairs or deletes these folders.")
                Button("Review retained recordings") { Task { await recovery.scan() } }.disabled(!recovery.canRecover)
                if !recovery.canRecover && !recovery.busy { Text("Stop audio and finish recording or microphone-test cleanup before recovery.") }
                if recovery.busy { ProgressView().controlSize(.small) }
                Text(recovery.message)
                if let error = recovery.error { Text(error).foregroundColor(.red).textSelection(.enabled) }
                ForEach(recovery.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                        Text(item.directory.path).textSelection(.enabled)
                        switch item.eligibility {
                        case .finalized:
                            Text(String(format: "%.2f seconds · finalized 48 kHz stereo PCM16", item.durationSeconds))
                            Button("Save copy to library…") { confirmation = recovery.request(for: item) }.disabled(!recovery.canRecover)
                        case .invalid(let reason): Text("Not eligible: " + reason)
                        }
                    }
                }
                ForEach(recording.retainedPaths, id: \.self) { path in Text(path).textSelection(.enabled) }
            }.font(.caption).foregroundColor(.orange)
                .alert("Save a copy to the current library?", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })) {
                    Button("Cancel", role: .cancel) { confirmation = nil }
                    Button("Save copy") {
                        if let request = confirmation { Task { await recovery.saveCopy(request) } }
                        confirmation = nil
                    }
                } message: {
                    Text("The retained source stays untouched. Each confirmed save creates a new session, including repeated saves of the same recording.")
                }
    }
}
