import XCTest
@testable import SquarePoC

/// Phase 1 automated tests. They run on the macOS CI runner in an
/// iOS simulator through `xcodebuild test`, so every claim in the
/// Phase 1 report about these behaviours is backed by a test result,
/// not by reading the code.
final class SquarePoCTests: XCTestCase {

    // MARK: - Rust interoperability (Phase 3 link test)
    //
    // These two tests only pass if SquareCorePOC.xcframework is
    // genuinely linked into the test host app and its C ABI can be
    // called from Swift. A cargo check alone would not prove that.

    func testRustVersionStringIsCallable() {
        XCTAssertEqual(RustBridge.version(), "square-core-poc 0.1.0")
    }

    func testRustLoudnessOfKnownSineBuffer() {
        // One second of a 440 Hz sine wave at half amplitude, mono.
        let sampleRate = 44100
        var samples: [Int16] = []
        samples.reserveCapacity(sampleRate)
        for frame in 0..<sampleRate {
            let phase = 2.0 * Double.pi * 440.0 * Double(frame) / Double(sampleRate)
            samples.append(Int16(0.5 * sin(phase) * Double(Int16.max)))
        }
        let loudness = RustBridge.loudness(samples: samples, channels: 1, sampleRate: sampleRate)
        guard let value = loudness else {
            XCTFail("Rust loudness returned nil for a valid sine buffer")
            return
        }
        // A half amplitude sine measures roughly -9 LUFS with
        // BS.1770 gating; accept a wide, honest range.
        XCTAssertTrue(value.isFinite)
        XCTAssertGreaterThan(value, -20.0)
        XCTAssertLessThan(value, -3.0)
    }

    func testRustLoudnessRejectsEmptyInput() {
        XCTAssertNil(RustBridge.loudness(samples: [], channels: 1, sampleRate: 44100))
    }

    // MARK: - Local audio playback (Phase 2)

    @MainActor
    func testGeneratedToneLoadsWithRealDuration() throws {
        let url = try AudioPlayer.makeTestToneURL()
        let player = AudioPlayer()
        player.addFiles([url])
        XCTAssertNil(player.lastError)
        XCTAssertTrue(player.hasLoadedTrack)
        XCTAssertEqual(player.duration, 3.0, accuracy: 0.25)
        XCTAssertEqual(player.currentTitle, "Generated Test Tone")
    }

    @MainActor
    func testPlayPauseAndSeekStateChanges() throws {
        let url = try AudioPlayer.makeTestToneURL()
        let player = AudioPlayer()
        player.addFiles([url], autoplay: false)
        XCTAssertFalse(player.isPlaying)

        player.play()
        XCTAssertTrue(player.isPlaying)

        player.pause()
        XCTAssertFalse(player.isPlaying)

        player.seek(to: 1.5)
        XCTAssertEqual(player.currentTime, 1.5, accuracy: 0.3)

        player.seek(to: 999)
        XCTAssertLessThanOrEqual(player.currentTime, player.duration + 0.001)
    }

    @MainActor
    func testTrackSwitchingAcrossQueue() throws {
        let toneA = try AudioPlayer.makeTestToneURL()
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let toneB = documents.appendingPathComponent("Second Test Tone.wav")
        try AudioPlayer.writeToneWAV(to: toneB, seconds: 2.0, frequency: 660.0)

        let player = AudioPlayer()
        player.addFiles([toneA, toneB], autoplay: false)
        XCTAssertEqual(player.queue.count, 2)
        XCTAssertEqual(player.currentIndex, 0)

        player.playNext()
        XCTAssertEqual(player.currentIndex, 1)
        XCTAssertEqual(player.duration, 2.0, accuracy: 0.25)

        player.playPrevious()
        XCTAssertEqual(player.currentIndex, 0)
    }

    @MainActor
    func testUnsupportedFileReportsErrorInsteadOfCrashing() throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bogus = documents.appendingPathComponent("not-audio.mp3")
        try Data("this is not audio".utf8).write(to: bogus)

        let player = AudioPlayer()
        player.addFiles([bogus])
        XCTAssertNotNil(player.lastError)
        XCTAssertFalse(player.hasLoadedTrack)
    }

    @MainActor
    func testLoudnessMeasurementOfToneFile() async throws {
        let url = try AudioPlayer.makeTestToneURL()
        let player = AudioPlayer()
        player.addFiles([url], autoplay: false)
        await player.measureLoudness()
        XCTAssertNil(player.lastError)
        let loudness = try XCTUnwrap(player.loudnessLUFS)
        XCTAssertTrue(loudness.isFinite)
        XCTAssertGreaterThan(loudness, -20.0)
        XCTAssertLessThan(loudness, -3.0)
    }
}
