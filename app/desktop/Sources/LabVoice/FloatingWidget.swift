import AppKit
import SwiftUI

@MainActor protocol FloatingWidgetPanel: AnyObject {
    var didClose: (() -> Void)? { get set }
    func show()
    func hide()
}

/// One retained panel uses the existing route controller. Visibility has no audio side effects.
@MainActor final class FloatingWidgetController: ObservableObject {
    static let shared = FloatingWidgetController()
    static let preferenceKey = "showWidget"
    @Published private(set) var isVisible: Bool
    let audio: AudioRouteController
    private let defaults: UserDefaults
    private let factory: (AudioRouteController) -> any FloatingWidgetPanel
    private var panel: (any FloatingWidgetPanel)?
    init(audio: AudioRouteController? = nil, defaults: UserDefaults = .standard,
         factory: ((AudioRouteController) -> any FloatingWidgetPanel)? = nil) {
        self.audio = audio ?? .shared; self.defaults = defaults; self.factory = factory ?? { NativeFloatingWidgetPanel(audio: $0) }
        // False is an independent default. The original app's factory default is unknown.
        isVisible = defaults.bool(forKey: Self.preferenceKey)
    }
    /// Called once the app has entered its normal scene lifecycle, never by headless verification.
    func restoreVisibility() {
        if isVisible { show() }
    }
    func show() {
        if panel == nil {
            let created = factory(audio)
            created.didClose = { [weak self] in self?.hide() }
            panel = created
        }
        isVisible = true; defaults.set(true, forKey: Self.preferenceKey)
        panel?.show()
    }
    func hide() {
        isVisible = false; defaults.set(false, forKey: Self.preferenceKey)
        panel?.hide()
    }
    func setVisible(_ value: Bool) { if value { show() } else { hide() } }
}

@MainActor private final class NativeFloatingWidgetPanel: NSObject, FloatingWidgetPanel, NSWindowDelegate {
    var didClose: (() -> Void)?
    private let window: NSPanel
    init(audio: AudioRouteController) {
        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        window.title = "Lab Voice widget"
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: FloatingWidgetView(audio: audio, recording: audio.recording))
        window.delegate = self
        window.center()
    }
    func show() { window.orderFrontRegardless() }
    func hide() { window.orderOut(nil) }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        didClose?()
        return false // Keep the same panel for the next explicit Show action.
    }
}

private struct FloatingWidgetView: View {
    @ObservedObject var audio: AudioRouteController
    @ObservedObject var recording: RecordingController
    @ObservedObject private var selectedCapture = SelectedAppCaptureController.shared
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(audio.statusTitle).font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    Toggle("Mute microphone", isOn: Binding(
                        get: { audio.desiredControls.microphone.muted }, set: audio.setMicrophoneMuted))
                        .disabled(!audio.controlsEditable)
                    Toggle("Mute speaker", isOn: Binding(
                        get: { audio.desiredControls.speaker.muted }, set: audio.setSpeakerMuted))
                        .disabled(!audio.controlsEditable)
                    Text(audio.controlStatus).font(.caption)
                    if let accepted = audio.confirmedControls, audio.controlPending || audio.controlError != nil {
                        Text("Last accepted: mic \(accepted.microphone.muted ? "muted" : "unmuted"), speaker \(accepted.speaker.muted ? "muted" : "unmuted").").font(.caption)
                    }
                    if let error = audio.controlError { Text(error).font(.caption).foregroundColor(.red) }
                    Divider()
                    Text("Recording").font(.subheadline)
                    Text(recording.message).font(.caption)
                    if selectedCapture.engaged {
                        Text(selectedCapture.message).font(.caption).foregroundColor(.red)
                        Button("Stop selected app recording") { Task { _ = await selectedCapture.stop() } }
                    }
                    if let error = recording.error { Text(error).font(.caption).foregroundColor(.red) }
                    if let error = audio.error { Text(error).font(.caption).foregroundColor(.red) }
                    Text("Mute silences app-route output. Stop audio ends microphone capture. Closing this widget only hides it.")
                        .font(.caption).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("Stop audio") { Task { _ = await audio.stop() } }
                .disabled(!audio.engaged)
        }.padding(16).frame(width: 320, height: 320)
        .preferredColorScheme(appearance.colorScheme)
    }
}
