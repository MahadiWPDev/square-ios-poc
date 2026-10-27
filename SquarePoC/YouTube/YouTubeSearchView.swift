import SwiftUI

/// Search YouTube (official Data API v3) and play results in
/// YouTube's official embedded player. Search results are always
/// live API data; the view has explicit loading, empty and error
/// states and never falls back to sample content.
struct YouTubeSearchView: View {
    @StateObject private var controller = YouTubePlayerController()
    @State private var query = ""
    @State private var results: [YTTrack] = []
    @State private var isSearching = false
    @State private var errorText: String?
    @State private var hasSearched = false
    @State private var apiKeyDraft = YTAPIKeyStore.key ?? ""
    @State private var hasKey = YTAPIKeyStore.hasKey
    @State private var seekDraft: Double?
    @State private var recents: [YTTrack] = []
    @State private var favoriteIds: Set<String> = []
    @State private var playlists: [YTPlaylist] = []
    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""
    private let service = YouTubeSearchService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let track = controller.track {
                    playerSection(track: track)
                }
                searchBar
                content
            }
            .navigationTitle("YouTube")
            .onAppear(perform: refreshLibrary)
            .onChange(of: controller.track?.id) { _ in refreshLibrary() }
            .alert("New playlist", isPresented: $showingNewPlaylist) {
                TextField("Playlist name", text: $newPlaylistName)
                Button("Create") {
                    let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        YTPlaylistStore.create(name: name)
                        refreshLibrary()
                    }
                    newPlaylistName = ""
                }
                Button("Cancel", role: .cancel) { newPlaylistName = "" }
            }
        }
    }

    private func refreshLibrary() {
        recents = YTLibraryStore.recents()
        favoriteIds = Set(YTLibraryStore.favorites().map(\.id))
        playlists = YTPlaylistStore.all()
    }

    // MARK: Player

    @ViewBuilder
    private func playerSection(track: YTTrack) -> some View {
        VStack(spacing: 8) {
            YouTubePlayerWebView(videoId: track.id, controller: controller)
                .id(track.id)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(Color.black)

            Text(track.title)
                .font(.subheadline.bold())
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                Button {
                    controller.previous()
                } label: {
                    Image(systemName: "backward.fill")
                }
                .disabled(!controller.canPrevious)

                Button {
                    controller.togglePlayPause()
                } label: {
                    Image(systemName: controller.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                }
                .disabled(controller.state == .idle || controller.state == .loading)

                Button {
                    controller.next()
                } label: {
                    Image(systemName: "forward.fill")
                }
                .disabled(!controller.canNext)

                Button {
                    if YTLibraryStore.toggleFavorite(track) {
                        favoriteIds.insert(track.id)
                    } else {
                        favoriteIds.remove(track.id)
                    }
                } label: {
                    Image(systemName: favoriteIds.contains(track.id) ? "heart.fill" : "heart")
                        .foregroundStyle(favoriteIds.contains(track.id) ? .red : .primary)
                }

                Menu {
                    ForEach(playlists) { playlist in
                        Button(playlist.name) {
                            YTPlaylistStore.add(track: track, toPlaylist: playlist.id)
                            refreshLibrary()
                        }
                    }
                    Button("New playlist...") { showingNewPlaylist = true }
                } label: {
                    Image(systemName: "text.badge.plus")
                }

                Text(timeText(controller.currentTime))
                    .font(.caption.monospacedDigit())
                Slider(
                    value: Binding(
                        get: { seekDraft ?? controller.currentTime },
                        set: { seekDraft = $0 }
                    ),
                    in: 0...max(controller.duration, 1)
                ) { editing in
                    if !editing, let value = seekDraft {
                        controller.seek(to: value)
                        seekDraft = nil
                    }
                }
                Text(timeText(controller.duration))
                    .font(.caption.monospacedDigit())
            }

            if controller.state == .buffering || controller.state == .loading {
                Label("Loading…", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if case .failed(let message) = controller.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Text("Plays inside YouTube's official player.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Song or artist name", text: $query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(runSearch)
            Button("Search", action: runSearch)
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        if !hasKey {
            keyEntry
        } else if isSearching {
            Spacer()
            ProgressView("Searching YouTube…")
            Spacer()
        } else if let errorText {
            Spacer()
            Text(errorText)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        } else if hasSearched && results.isEmpty {
            Spacer()
            Text("No results for that search.")
                .foregroundStyle(.secondary)
            Spacer()
        } else if !hasSearched && results.isEmpty && (!recents.isEmpty || !favoriteIds.isEmpty || !playlists.isEmpty) {
            List {
                Section("Playlists") {
                    Button {
                        showingNewPlaylist = true
                    } label: {
                        Label("New playlist", systemImage: "plus")
                    }
                    ForEach(playlists) { playlist in
                        Button {
                            if let first = playlist.tracks.first {
                                controller.select(first, in: playlist.tracks)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(playlist.tracks.isEmpty ? "Empty" : "\(playlist.tracks.count) track(s)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !playlist.tracks.isEmpty {
                                    Image(systemName: "play.circle")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .disabled(playlist.tracks.isEmpty)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            YTPlaylistStore.delete(id: playlists[index].id)
                        }
                        refreshLibrary()
                    }
                }
                if !recents.isEmpty {
                    Section("Recently played") {
                        ForEach(recents) { track in
                            trackRow(track, queue: recents)
                        }
                    }
                }
                let favorites = YTLibraryStore.favorites()
                if !favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(favorites) { track in
                            trackRow(track, queue: favorites)
                        }
                    }
                }
            }
            .listStyle(.plain)
        } else {
            List(results) { track in
                Button {
                    controller.select(track, in: results)
                } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: track.thumbnailURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.25)
                        }
                        .frame(width: 64, height: 36)
                        .clipped()
                        .cornerRadius(4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if !track.durationText.isEmpty {
                            Text(track.durationText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if controller.track?.id == track.id {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var keyEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A free YouTube Data API key is needed for search.")
                .font(.headline)
            Text("Create it in your own Google Cloud project (YouTube Data API v3, free quota). Paste it here once. It is stored only on this phone and is never uploaded anywhere.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Paste API key", text: $apiKeyDraft)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Save key on this phone") {
                let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                YTAPIKeyStore.key = trimmed
                hasKey = true
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private func trackRow(_ track: YTTrack, queue: [YTTrack]) -> some View {
        Button {
            controller.select(track, in: queue)
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: track.thumbnailURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.25)
                }
                .frame(width: 64, height: 36)
                .clipped()
                .cornerRadius(4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if !track.durationText.isEmpty {
                    Text(track.durationText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if controller.track?.id == track.id {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    // MARK: Actions

    private func runSearch() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSearching else { return }
        isSearching = true
        errorText = nil
        Task {
            do {
                let found = try await service.search(query: text)
                results = found
                hasSearched = true
            } catch let error as YTSearchError {
                errorText = error.userMessage
                if error == .missingAPIKey { hasKey = false }
            } catch {
                errorText = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}
