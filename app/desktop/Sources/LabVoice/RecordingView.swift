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
    var body: some View {
        if !recording.retainedPaths.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(recording.retainedPaths.count) recording staging folder(s) remain. They are not saved sessions. No files were deleted automatically.")
                Text("Inspect these folders before manually importing a finalized WAV. Partial files may be invalid.")
                ForEach(recording.retainedPaths, id: \.self) { path in Text(path).textSelection(.enabled) }
            }.font(.caption).foregroundColor(.orange)
        }
    }
}
