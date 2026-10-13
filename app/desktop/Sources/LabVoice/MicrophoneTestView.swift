import SwiftUI

struct MicrophoneTestView: View {
    @ObservedObject var audio: AudioRouteController
    @ObservedObject private var test = MicrophoneTestController.shared
    let input: AudioHardwareDevice?
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingCancel = false
    private var mayStart: Bool { !test.engaged && audio.phase == .idle && !audio.loading && !audio.recording.busy && !audio.desiredControls.microphone.muted && input?.alive == 1 && input?.nominalRate == 48000 }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Test microphone").font(.title2)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text((test.engaged ? test.inputName : input?.name) ?? "No physical microphone selected").font(.headline)
                    Text("Record a short sample, then compare the original with RNNoise-processed audio. Use a 48 kHz microphone. The first channel is captured for 5 to 60 seconds.")
                        .font(.caption).foregroundColor(.secondary)
                    Text("Stop audio and unmute the microphone before starting.")
                        .font(.caption).foregroundColor(.secondary)
                    Text("Files stay temporarily on this Mac and do not enter history. Done or confirmed Cancel deletes them after the test stops. Interrupted cleanup may leave a private folder for inspection.")
                        .font(.caption).foregroundColor(.secondary)
                    Text(test.status)
                    if test.engaged { Text(String(format: "Captured: %.2f seconds", test.capturedSeconds)).font(.caption.monospacedDigit()) }
                    if test.phase == .comparison {
                        Picker("Comparison", selection: Binding(get: { test.variant }, set: test.select)) {
                            ForEach(ComparisonVariant.allCases, id: \.self) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented)
                        HStack {
                            Button(test.playing ? "Pause playback" : "Play") { if test.playing { test.pausePlayback() } else { test.play() } }
                            Button("Replay") { test.play(replay: true) }
                        }
                        Text(String(format: "Playback: %.2f / %.2f seconds", test.playbackPosition, test.capturedSeconds)).font(.caption)
                        Text("Switching keeps the same playback position.").font(.caption).foregroundColor(.secondary)
                    }
                    if let error = test.error { Text(error).font(.caption).foregroundColor(.red).textSelection(.enabled) }
                    if !test.retainedPaths.isEmpty {
                        Text("Private test folders remain from earlier interrupted cleanup. They are not saved history sessions.").font(.caption).foregroundColor(.orange)
                        ForEach(test.retainedPaths, id: \.self) { Text($0).font(.caption).textSelection(.enabled) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button("Cancel") { if test.pendingCapture { confirmingCancel = true } else { finish() } }
                    .disabled(test.phase == .cancelling)
                Spacer()
                if [.authorizing, .preparing, .starting, .stopping, .processing, .validating, .cancelling].contains(test.phase) { ProgressView().controlSize(.small) }
                if test.phase == .comparison {
                    Button("Retry") { Task { if await test.cancelAndCleanup() { start() } } }
                } else if test.phase == .capturing {
                    Button("Stop capture") { test.stop() }.disabled(!test.canStop)
                } else if !test.engaged {
                    Button("Start test") { start() }.disabled(!mayStart)
                }
                Button("Done") { if test.pendingCapture { confirmingCancel = true } else { finish() } }
                    .disabled(test.phase == .cancelling)
            }
        }.padding(24).frame(width: 580, height: 500)
        .interactiveDismissDisabled(test.engaged)
        .task { await test.refreshRetained() }
        .onDisappear { if test.engaged { Task { _ = await test.cancelAndCleanup() } } }
        .alert("Cancel microphone test?", isPresented: $confirmingCancel) {
            Button("Keep test", role: .cancel) { }
            Button("Cancel and remove test", role: .destructive) { finish() }
        } message: {
            Text("This stops capture or processing and removes the temporary files. Playback never starts automatically.")
        }
    }
    private func start() { test.start(input: input, microphoneUnmuted: !audio.desiredControls.microphone.muted, routeStopped: audio.phase == .idle && !audio.recording.busy) }
    private func finish() { Task { if await test.cancelAndCleanup() { dismiss() } } }
}
