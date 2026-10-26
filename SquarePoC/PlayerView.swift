import SwiftUI

/// Full player sheet: square artwork, progress, transport controls and
/// a static lyrics card, mirroring the layout ideas of the original
/// app in native SwiftUI. The artwork is a generated gradient, the
/// lyrics are placeholder lines, and the audio engine is a timer.
struct PlayerView: View {
    @EnvironmentObject private var player: SamplePlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            if let track = player.current {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: track.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 64))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .shadow(radius: 20, y: 10)

                VStack(spacing: 4) {
                    Text(track.title)
                        .font(.title2.bold())
                    Text(track.artist)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 6) {
                    Slider(value: Binding(
                        get: { player.progress },
                        set: { player.seek(to: $0) }
                    ))
                    HStack {
                        Text(timeLabel(player.progress * track.durationSeconds))
                        Spacer()
                        Text(timeLabel(track.durationSeconds))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 36) {
                    Image(systemName: "backward.fill").font(.title3)
                    Button {
                        player.toggle()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                    }
                    .buttonStyle(.plain)
                    Image(systemName: "forward.fill").font(.title3)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Lyrics")
                        .font(.headline)
                    Text("Placeholder lines for the prototype.")
                    Text("Real lyrics need an approved data source.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassPanel()
            }

            Spacer()

            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding(20)
        .background(
            LinearGradient(colors: [.indigo.opacity(0.25), .clear],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func timeLabel(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
