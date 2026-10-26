import SwiftUI

/// Root view: three tabs and a mini player.
///
/// Phase 1 turns the Player and Library tabs into the real local
/// audio player. The Home tab keeps the Phase 0 visual shelves as a
/// design reference only; its cards are invented artwork and do not
/// play anything. No Spotify, YouTube or other third party content is
/// used anywhere in the app.
struct ContentView: View {
    @StateObject private var player = AudioPlayer()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            PlayerView(player: player)
                .tabItem { Label("Player", systemImage: "play.circle.fill") }
                .tag(1)

            LibraryView(player: player)
                .tabItem { Label("Library", systemImage: "music.note.list") }
                .tag(2)
        }
        .safeAreaInset(edge: .bottom) {
            if player.hasLoadedTrack {
                MiniPlayerView(player: player) { selectedTab = 1 }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
        }
    }
}

private struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Phase 1 prototype. The Player tab plays your own audio files for real. These shelves are design references only and their cards do not play.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(SampleLibrary.shelves) { shelf in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(shelf.title)
                                .font(.title3.bold())
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(shelf.tracks) { track in
                                        TrackCard(track: track)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Square PoC")
            .background(
                LinearGradient(colors: [.blue.opacity(0.25), .purple.opacity(0.15), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
        }
    }
}

private struct TrackCard: View {
    let track: SampleTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: track.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 140, height: 140)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.85))
                }
            Text(track.title)
                .font(.subheadline.bold())
                .lineLimit(1)
            Text(track.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}

private struct LibraryView: View {
    @ObservedObject var player: AudioPlayer

    var body: some View {
        NavigationStack {
            List {
                Section("Your files") {
                    if player.queue.isEmpty {
                        Text("No files yet. Add audio files from the Player tab.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(player.queue.enumerated()), id: \.offset) { index, url in
                        Button {
                            player.load(at: index, autoplay: true)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: index == player.currentIndex ? "speaker.wave.2.fill" : "music.note")
                                    .foregroundStyle(index == player.currentIndex ? .primary : .secondary)
                                VStack(alignment: .leading) {
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .foregroundStyle(.primary)
                                    Text(url.lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section("Diagnostics") {
                    LabeledContent("Rust library", value: RustBridge.version())
                    LabeledContent("Audio engine", value: "AVAudioPlayer")
                    LabeledContent("Background mode", value: "Audio")
                }
            }
            .navigationTitle("Library")
        }
    }
}

/// Rounded glass surface. Uses the system Liquid Glass effect where
/// the OS provides it and falls back to a material fill elsewhere.
struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

extension View {
    func glassPanel() -> some View {
        modifier(GlassPanel())
    }
}
