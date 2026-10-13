import AVFoundation

@MainActor enum MicrophonePermission {
    static func status() -> AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .audio) }
    static func request() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
    }
}
