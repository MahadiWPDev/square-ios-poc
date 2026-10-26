import SwiftUI

/// Root view: three tabs and a mini player, in the spirit of Square's
/// floating glass tab bar. The glass look uses Apple's own materials
/// and, on iOS 26, the system Liquid Glass effect. No artwork, icon or
/// code is copied from the Android project.
struct ContentView: View {
    @EnvironmentObject private var player: SamplePlayer

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            SearchPlaceholderView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            LibraryPlaceholderView()
                .tabItem { Label("Library", systemImage: "music.note.list") }
        }
        .safeAreaInset(edge: .bottom) {
            if player.current != nil {
                MiniPlayerView()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
        }
        .sheet(isPresented: $player.showPlayer) {
            PlayerView()
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var player: SamplePlayer

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Phase 0 prototype. Sample tracks only, nothing is streamed.")
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
                                            .onTapGesture { player.play(track) }
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

private struct MiniPlayerView: View {
    @EnvironmentObject private var player: SamplePlayer

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: player.current?.colors ?? [.gray],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.current?.title ?? "Nothing playing")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(player.current?.artist ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .glassPanel()
        .contentShape(Rectangle())
        .onTapGesture { player.showPlayer = true }
    }
}

private struct SearchPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Search is not part of Phase 0",
                                   systemImage: "magnifyingglass",
                                   description: Text("Catalogue search arrives only with an approved later phase."))
                .navigationTitle("Search")
        }
    }
}

private struct LibraryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            List(SampleLibrary.tracks) { track in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: track.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading) {
                        Text(track.title)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
