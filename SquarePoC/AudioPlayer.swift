import AVFoundation
import Foundation
import MediaPlayer

/// A real local audio player built on AVAudioPlayer.
///
/// Phase 1 scope, deliberately narrow: it plays audio files the user
/// explicitly picks with the system document picker, plus one test
/// tone the app generates itself. No network access, no third party
/// catalogue, no account. Playback state, progress and errors are all
/// real and come from AVFoundation, not from a timer pretending.
///
/// Background playback is prepared the standard way: the audio
/// session uses the playback category, the generated Info.plist
/// declares the audio background mode, Now Playing info is published
/// and remote commands (lock screen, Control Centre, headphones) are
/// wired to the same transport functions the on screen buttons call.
@MainActor
final class AudioPlayer: NSObject, ObservableObject {
    @Published private(set) var queue: [URL] = []
    @Published private(set) var currentIndex: Int?
    @Published private(set) var currentTitle = "Nothing loaded"
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var loudnessLUFS: Double?
    @Published private(set) var isMeasuringLoudness = false
    @Published var lastError: String?

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var accessedURLs: Set<URL> = []
    private var remoteCommandTokens: [Any] = []
    private var didSetUpRemoteCommands = false

    var currentURL: URL? {
        guard let index = currentIndex, queue.indices.contains(index) else { return nil }
        return queue[index]
    }

    var hasLoadedTrack: Bool { player != nil }

    override init() {
        super.init()
        configureAudioSession()
        setUpRemoteCommands()
    }

    deinit {
        progressTimer?.invalidate()
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: - Queue and loading

    /// Adds files chosen in the document picker. When nothing is
    /// loaded yet, the first new file is loaded immediately.
    func addFiles(_ urls: [URL], autoplay: Bool = false) {
        var added: [URL] = []
        for url in urls where !queue.contains(url) {
            queue.append(url)
            added.append(url)
        }
        if player == nil, let first = added.first {
            load(url: first, autoplay: autoplay)
        }
    }

    func load(at index: Int, autoplay: Bool = true) {
        guard queue.indices.contains(index) else { return }
        load(url: queue[index], autoplay: autoplay)
    }

    func load(url: URL, autoplay: Bool = false) {
        lastError = nil
        loudnessLUFS = nil

        if !accessedURLs.contains(url), url.startAccessingSecurityScopedResource() {
            accessedURLs.insert(url)
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            player = newPlayer
            currentIndex = queue.firstIndex(of: url)
            currentTitle = url.deletingPathExtension().lastPathComponent
            duration = newPlayer.duration
            currentTime = 0
            isPlaying = false
            updateNowPlaying()
            if autoplay { play() }
        } catch {
            player = nil
            isPlaying = false
            duration = 0
            currentTime = 0
            currentTitle = "Could not load file"
            lastError = "This file could not be played. It may be missing, damaged, or in a format iOS does not support. (\(error.localizedDescription))"
        }
    }

    // MARK: - Transport

    func play() {
        guard let player else { return }
        configureAudioSession()
        player.play()
        isPlaying = player.isPlaying
        startProgressTimer()
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
        syncCurrentTime()
        updateNowPlaying()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let clamped = min(max(seconds, 0), player.duration)
        player.currentTime = clamped
        currentTime = clamped
        updateNowPlaying()
    }

    func playNext() {
        guard let index = currentIndex else { return }
        let next = index + 1
        if queue.indices.contains(next) {
            load(at: next, autoplay: true)
        } else {
            stopAtEnd()
        }
    }

    func playPrevious() {
        guard let index = currentIndex else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        let previous = index - 1
        if queue.indices.contains(previous) {
            load(at: previous, autoplay: true)
        } else {
            seek(to: 0)
        }
    }

    private func stopAtEnd() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopProgressTimer()
        updateNowPlaying()
    }

    // MARK: - Generated test tone

    /// Writes the generated test tone into the app's Documents folder
    /// and returns its URL. The tone is synthesized by this app (a
    /// 440 Hz sine wave), so it is legally safe test audio.
    static func makeTestToneURL() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("Generated Test Tone.wav")
        if !FileManager.default.fileExists(atPath: url.path) {
            try writeToneWAV(to: url)
        }
        return url
    }

    /// Writes a 16 bit PCM WAV file containing a sine wave.
    static func writeToneWAV(to url: URL, seconds: Double = 3.0,
                             frequency: Double = 440.0, sampleRate: Int = 44100) throws {
        let frameCount = Int(seconds * Double(sampleRate))
        var data = Data()
        data.reserveCapacity(44 + frameCount * 2)

        func appendUInt32LE(_ value: UInt32) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        func appendUInt16LE(_ value: UInt16) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }

        let byteCount = UInt32(frameCount * 2)
        data.append(contentsOf: Array("RIFF".utf8))
        appendUInt32LE(36 + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendUInt32LE(16)                 // fmt chunk size
        appendUInt16LE(1)                  // PCM
        appendUInt16LE(1)                  // mono
        appendUInt32LE(UInt32(sampleRate))
        appendUInt32LE(UInt32(sampleRate * 2))  // byte rate
        appendUInt16LE(2)                  // block align
        appendUInt16LE(16)                 // bits per sample
        data.append(contentsOf: Array("data".utf8))
        appendUInt32LE(byteCount)

        for frame in 0..<frameCount {
            let phase = 2.0 * Double.pi * frequency * Double(frame) / Double(sampleRate)
            // Short fade in and out so the tone does not click.
            let envelope = min(1.0, min(Double(frame), Double(frameCount - frame)) / 512.0)
            let value = Int16(0.5 * envelope * sin(phase) * Double(Int16.max))
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }

        try data.write(to: url, options: .atomic)
    }

    // MARK: - Loudness through the Rust core

    /// Measures the integrated loudness of the loaded file with the
    /// Rust square-core-poc library (ebur128) through its C ABI.
    /// This is the Phase 3 interoperability path exercised for real:
    /// Swift decodes the file to PCM, Rust measures it.
    func measureLoudness() async {
        guard let url = currentURL else {
            lastError = "Load a file before measuring its loudness."
            return
        }
        isMeasuringLoudness = true
        defer { isMeasuringLoudness = false }
        do {
            let decoded = try Self.readPCMSamples(url: url)
            let samples = decoded.samples
            let channels = decoded.channels
            let sampleRate = Int(decoded.sampleRate)
            let value = await Task.detached(priority: .userInitiated) {
                RustBridge.loudness(samples: samples, channels: channels, sampleRate: sampleRate)
            }.value
            if let value {
                loudnessLUFS = value
            } else {
                lastError = "The Rust loudness measurement returned no result for this file."
            }
        } catch {
            lastError = "Could not decode this file to measure loudness. (\(error.localizedDescription))"
        }
    }

    /// Decodes an audio file to interleaved 16 bit PCM samples.
    static func readPCMSamples(url: URL) throws -> (samples: [Int16], channels: Int, sampleRate: Double) {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCapacity = AVAudioFrameCount(file.length)
        guard frameCapacity > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            throw NSError(domain: "AudioPlayer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The file contains no readable audio frames."])
        }
        try file.read(into: buffer)
        let channels = Int(format.channelCount)
        let frames = Int(buffer.frameLength)
        var samples: [Int16] = []
        samples.reserveCapacity(frames * channels)
        if let floatData = buffer.floatChannelData {
            for frame in 0..<frames {
                for channel in 0..<channels {
                    let value = max(-1.0, min(1.0, Double(floatData[channel][frame])))
                    samples.append(Int16(value * 32767.0))
                }
            }
        } else if let int16Data = buffer.int16ChannelData {
            for frame in 0..<frames {
                for channel in 0..<channels {
                    samples.append(int16Data[channel][frame])
                }
            }
        }
        return (samples, channels, file.fileFormat.sampleRate)
    }

    // MARK: - Audio session, progress, Now Playing, remote commands

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            lastError = "The audio session could not be started. (\(error.localizedDescription))"
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncCurrentTime()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func syncCurrentTime() {
        guard let player else { return }
        currentTime = player.currentTime
        isPlaying = player.isPlaying
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = currentTitle
        info[MPMediaItemPropertyArtist] = "Local file"
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setUpRemoteCommands() {
        guard !didSetUpRemoteCommands else { return }
        didSetUpRemoteCommands = true
        let center = MPRemoteCommandCenter.shared()

        remoteCommandTokens.append(center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        })
        remoteCommandTokens.append(center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        })
        remoteCommandTokens.append(center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        })
        remoteCommandTokens.append(center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playNext() }
            return .success
        })
        remoteCommandTokens.append(center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playPrevious() }
            return .success
        })
        remoteCommandTokens.append(center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = positionEvent.positionTime
            Task { @MainActor in self?.seek(to: position) }
            return .success
        })
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                self.playNext()
            } else {
                self.isPlaying = false
                self.stopProgressTimer()
                self.lastError = "Playback stopped because the file could not be decoded to the end."
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isPlaying = false
            self.stopProgressTimer()
            self.lastError = "A decode error stopped playback. (\(error?.localizedDescription ?? "unknown error"))"
        }
    }
}
