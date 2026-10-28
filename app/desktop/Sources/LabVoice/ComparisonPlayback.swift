import Foundation
import AVFoundation

enum ComparisonVariant: String, CaseIterable { case original, processed
    var title: String { self == .original ? "Original" : "RNNoise processed" }
}
struct ComparisonPlaybackState: Sendable { let playing: Bool; let position: Double }
protocol ComparisonPlaying: Sendable {
    func configure(id: UUID, original: URL, processed: URL) async
    func select(id: UUID, variant: ComparisonVariant) async throws -> ComparisonPlaybackState
    func play(id: UUID, replay: Bool) async throws -> ComparisonPlaybackState
    func pause(id: UUID) async -> ComparisonPlaybackState
    func snapshot(id: UUID) async -> ComparisonPlaybackState?
    func stop(id: UUID) async
}
protocol ComparisonAudioPlayer: AnyObject {
    var currentTime: TimeInterval { get set }
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }
    func prepareToPlay() -> Bool
    func play() -> Bool
    func pause()
    func stop()
}
extension AVAudioPlayer: ComparisonAudioPlayer {}

/// File reads and player setup stay off the main thread. Only explicit Play produces output.
actor ComparisonPlayback: ComparisonPlaying {
    private var id: UUID?
    private var paths: [ComparisonVariant: URL] = [:]
    private var selected: ComparisonVariant = .original
    private var player: (any ComparisonAudioPlayer)?
    private let makePlayer: @Sendable (URL) throws -> any ComparisonAudioPlayer
    init(makePlayer: @escaping @Sendable (URL) throws -> any ComparisonAudioPlayer = { try AVAudioPlayer(contentsOf: $0) }) { self.makePlayer = makePlayer }
    private var position = 0.0
    private var powerRevision = PowerAdmission.shared.revision
    func configure(id: UUID, original: URL, processed: URL) {
        player?.stop(); player = nil; self.id = id
        powerRevision = PowerAdmission.shared.revision
        paths = [.original: original, .processed: processed]; selected = .original; position = 0
    }
    func select(id: UUID, variant: ComparisonVariant) throws -> ComparisonPlaybackState {
        guard self.id == id else { throw MicrophoneTestError.unavailable }
        let playing = player?.isPlaying ?? false
        position = player?.currentTime ?? position
        player?.stop(); player = nil; selected = variant
        if playing { return try play(id: id, replay: false) }
        return ComparisonPlaybackState(playing: false, position: position)
    }
    func play(id: UUID, replay: Bool) throws -> ComparisonPlaybackState {
        guard PowerAdmission.shared.allowed, PowerAdmission.shared.revision == powerRevision, self.id == id, let url = paths[selected] else { throw MicrophoneTestError.unavailable }
        if replay { position = 0; player?.stop(); player = nil }
        if player == nil {
            let value = try makePlayer(url)
            value.currentTime = min(position, value.duration)
            player = value
        }
        guard let player else { throw MicrophoneTestError.unavailable }
        if player.currentTime >= player.duration { player.currentTime = 0 }
        guard player.prepareToPlay() else { throw MicrophoneTestError.unavailable }
        guard PowerAdmission.shared.allowed, PowerAdmission.shared.revision == powerRevision, player.play() else { throw MicrophoneTestError.unavailable }
        return ComparisonPlaybackState(playing: true, position: player.currentTime)
    }
    func pause(id: UUID) -> ComparisonPlaybackState {
        guard self.id == id else { return ComparisonPlaybackState(playing: false, position: 0) }
        player?.pause(); position = player?.currentTime ?? position
        return ComparisonPlaybackState(playing: false, position: position)
    }
    func snapshot(id: UUID) -> ComparisonPlaybackState? {
        guard self.id == id else { return nil }
        return ComparisonPlaybackState(playing: player?.isPlaying ?? false, position: player?.currentTime ?? position)
    }
    func stop(id: UUID) {
        guard self.id == id else { return }
        player?.stop(); player = nil; self.id = nil; paths = [:]; position = 0
    }
}
