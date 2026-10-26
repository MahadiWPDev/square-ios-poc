import SwiftUI
import UniformTypeIdentifiers

/// The full local player screen (Phase 1).
///
/// Everything here drives the real AudioPlayer: files picked with the
/// document picker, the app generated test tone, transport controls,
/// seeking, the queue, error messages and the Rust powered loudness
/// measurement. The Phase 0 fake timer player is gone.
struct PlayerView: View {
    @ObservedObject var player: AudioPlayer
    @State private var isImporting = false
    @State private var isSeeking = false
    @State private var seekValue: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nowPlayingCard
                    transportControls
                    progressControls
                    actionsSection
                    loudnessSection
                    if let error = player.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Text("Local files only. Nothing is streamed, uploaded or shared. Background playback and lock screen controls use the standard iOS audio session and remote commands.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .navigationTitle("Local Player")
            .background(
                LinearGradient(colors: [.blue.opacity(0.18), .purple.opacity(0.10), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .fileImporter(isPresented: $isImporting,
                          allowedContentTypes: [.audio],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    player.addFiles(urls, autoplay: true)
                case .failure(let error):
                    player.lastError = "File picking failed. (\(error.localizedDescription))"
                }
            }
        }
    }

    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.teal, .blue, .purple],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 170)
                .overlay {
                    Image(systemName: player.isPlaying ? "waveform" : "music.note")
                        .font(.system(size: 54))
                        .foregroundStyle(.white.opacity(0.9))
                }
            Text(player.currentTitle)
                .font(.title3.bold())
                .lineLimit(2)
            Text(player.currentURL?.lastPathComponent ?? "Pick an audio file, or play the generated test tone.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 36) {
            Spacer()
            Button { player.playPrevious() } label: {
                Image(systemName: "backward.fill").font(.title2)
            }
            .disabled(!player.hasLoadedTrack)
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 58))
            }
            .disabled(!player.hasLoadedTrack)
            Button { player.playNext() } label: {
                Image(systemName: "forward.fill").font(.title2)
            }
            .disabled(!player.hasLoadedTrack)
            Spacer()
        }
        .buttonStyle(.plain)
    }

    private var progressControls: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(
                get: { isSeeking ? seekValue : player.currentTime },
                set: { seekValue = $0 }
            ), in: 0...max(player.duration, 0.1)) { editing in
                if editing {
                    isSeeking = true
                    seekValue = player.currentTime
                } else {
                    player.seek(to: seekValue)
                    isSeeking = false
                }
            }
            .disabled(!player.hasLoadedTrack)
            HStack {
                Text(timeLabel(isSeeking ? seekValue : player.currentTime))
                Spacer()
                Text(timeLabel(player.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                isImporting = true
            } label: {
                Label("Add audio files", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                do {
                    let url = try AudioPlayer.makeTestToneURL()
                    if player.queue.contains(url) {
                        player.load(url: url, autoplay: true)
                    } else {
                        player.addFiles([url], autoplay: true)
                    }
                } catch {
                    player.lastError = "The test tone could not be created. (\(error.localizedDescription))"
                }
            } label: {
                Label("Play generated test tone", systemImage: "waveform.path")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if !player.queue.isEmpty {
                Text("\(player.queue.count) file(s) in the queue. Open the Library tab to switch tracks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var loudnessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rust core check")
                .font(.headline)
            Text("Linked library: \(RustBridge.version())")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button {
                Task { await player.measureLoudness() }
            } label: {
                if player.isMeasuringLoudness {
                    ProgressView()
                } else {
                    Label("Measure loudness of this file", systemImage: "gauge.with.dots.needle.67percent")
                }
            }
            .buttonStyle(.bordered)
            .disabled(!player.hasLoadedTrack || player.isMeasuringLoudness)
            if let loudness = player.loudnessLUFS {
                Text(String(format: "Integrated loudness: %.1f LUFS, measured by the Rust ebur128 code linked into this app.", loudness))
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel()
    }

    private func timeLabel(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Compact bar shown above the tab bar while a file is loaded.
/// It reflects the same real AudioPlayer as the full player screen.
struct MiniPlayerView: View {
    @ObservedObject var player: AudioPlayer
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [.teal, .blue],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentTitle)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(player.isPlaying ? "Playing" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            Button { player.playNext() } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .glassPanel()
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
