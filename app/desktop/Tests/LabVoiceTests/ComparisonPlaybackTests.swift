import XCTest
import Foundation
@testable import LabVoice

private final class FixtureComparisonAudioPlayer: ComparisonAudioPlayer, @unchecked Sendable {
    private let lock = NSLock()
    private var time = 0.0, active = false
    let duration = 5.0
    var currentTime: TimeInterval {
        get { lock.lock(); defer { lock.unlock() }; return time }
        set { lock.lock(); defer { lock.unlock() }; time = newValue }
    }
    var isPlaying: Bool { lock.lock(); defer { lock.unlock() }; return active }
    func prepareToPlay() -> Bool { true }
    func play() -> Bool { lock.lock(); defer { lock.unlock() }; active = true; return true }
    func pause() { lock.lock(); defer { lock.unlock() }; active = false }
    func stop() { pause() }
}
final class ComparisonPlaybackTests: XCTestCase {
    func testSwitchTransfersActualPlayerPositionAndReplayResetsItWithoutHardwarePlayback() async throws {
        let original = FixtureComparisonAudioPlayer(), processed = FixtureComparisonAudioPlayer()
        let playback = ComparisonPlayback { url in url.lastPathComponent == "original.wav" ? original : processed }
        let id = UUID()
        await playback.configure(id: id, original: URL(fileURLWithPath: "/fixture/original.wav"), processed: URL(fileURLWithPath: "/fixture/processed.wav"))
        _ = try await playback.play(id: id, replay: false)
        original.currentTime = 2.75
        let switched = try await playback.select(id: id, variant: .processed)
        XCTAssertEqual(switched.position, 2.75); XCTAssertTrue(switched.playing)
        XCTAssertEqual(processed.currentTime, 2.75); XCTAssertFalse(original.isPlaying)
        _ = await playback.pause(id: id)
        let pausedSwitch = try await playback.select(id: id, variant: .original)
        XCTAssertFalse(pausedSwitch.playing); XCTAssertEqual(pausedSwitch.position, 2.75)
        let replay = try await playback.play(id: id, replay: true)
        XCTAssertEqual(replay.position, 0)
        await playback.stop(id: id)
        let stale = await playback.snapshot(id: id); XCTAssertNil(stale)
    }
}
