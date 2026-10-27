import Foundation

/// One YouTube video as the app uses it. Built only from YouTube Data
/// API v3 responses; there are no sample or placeholder tracks.
struct YTTrack: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let artist: String
    let thumbnailURL: URL?
    var durationSeconds: Int?

    var durationText: String {
        guard let durationSeconds else { return "" }
        return "\(durationSeconds / 60):" + String(format: "%02d", durationSeconds % 60)
    }
}

/// On-device library for the YouTube tab: recently played tracks
/// and favorites, stored as JSON in UserDefaults. Nothing leaves
/// the phone; no account or server is involved.
enum YTLibraryStore {
    private static let recentsKey = "yt_recents"
    private static let favoritesKey = "yt_favorites"
    private static let recentsLimit = 20

    static func recents() -> [YTTrack] { load(recentsKey) }
    static func favorites() -> [YTTrack] { load(favoritesKey) }

    static func recordRecent(_ track: YTTrack) {
        var items = load(recentsKey)
        items.removeAll { $0.id == track.id }
        items.insert(track, at: 0)
        save(Array(items.prefix(recentsLimit)), key: recentsKey)
    }

    static func isFavorite(_ id: String) -> Bool {
        load(favoritesKey).contains { $0.id == id }
    }

    /// Returns the favorite state after the toggle.
    @discardableResult
    static func toggleFavorite(_ track: YTTrack) -> Bool {
        var items = load(favoritesKey)
        if let index = items.firstIndex(where: { $0.id == track.id }) {
            items.remove(at: index)
            save(items, key: favoritesKey)
            return false
        }
        items.insert(track, at: 0)
        save(items, key: favoritesKey)
        return true
    }

    private static func load(_ key: String) -> [YTTrack] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([YTTrack].self, from: data)
        else { return [] }
        return items
    }

    private static func save(_ items: [YTTrack], key: String) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// A user-created playlist of YouTube tracks. Stored locally as
/// JSON in UserDefaults (same pattern as YTLibraryStore). Track
/// metadata only; no audio is ever downloaded or stored.
struct YTPlaylist: Identifiable, Equatable, Codable {
    var id: String
    var name: String
    var tracks: [YTTrack]
}

enum YTPlaylistStore {
    private static let key = "yt_playlists"

    static func all() -> [YTPlaylist] { load() }

    @discardableResult
    static func create(name: String) -> YTPlaylist {
        let playlist = YTPlaylist(id: UUID().uuidString, name: name, tracks: [])
        var items = load()
        items.insert(playlist, at: 0)
        save(items)
        return playlist
    }

    static func delete(id: String) {
        save(load().filter { $0.id != id })
    }

    /// Adds the track unless it is already in the playlist.
    static func add(track: YTTrack, toPlaylist id: String) {
        var items = load()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if !items[index].tracks.contains(where: { $0.id == track.id }) {
            items[index].tracks.append(track)
        }
        save(items)
    }

    static func remove(trackId: String, fromPlaylist id: String) {
        var items = load()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].tracks.removeAll { $0.id == trackId }
        save(items)
    }

    private static func load() -> [YTPlaylist] {
        // Corrupt or missing stored data must never crash the app:
        // it simply reads as an empty library.
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([YTPlaylist].self, from: data)
        else { return [] }
        return items
    }

    private static func save(_ items: [YTPlaylist]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - YouTube Data API v3 response shapes (search.list)

struct YTSearchResponse: Decodable {
    struct Item: Decodable {
        struct ID: Decodable { let videoId: String? }
        struct Snippet: Decodable {
            struct Thumbnails: Decodable {
                struct Thumb: Decodable { let url: String }
                let medium: Thumb?
                let high: Thumb?
            }
            let title: String
            let channelTitle: String
            let thumbnails: Thumbnails?
        }
        let id: ID
        let snippet: Snippet
    }
    let items: [Item]?
}

// MARK: - YouTube Data API v3 response shapes (videos.list)

struct YTVideosResponse: Decodable {
    struct Item: Decodable {
        struct ContentDetails: Decodable { let duration: String }
        let id: String
        let contentDetails: ContentDetails?
    }
    let items: [Item]?
}

enum YTMapper {
    /// Maps a search response to tracks, dropping items without a
    /// video id and decoding the HTML entities the API returns in
    /// titles (for example `&amp;`).
    static func tracks(from response: YTSearchResponse) -> [YTTrack] {
        (response.items ?? []).compactMap { item in
            guard let videoId = item.id.videoId, !videoId.isEmpty else { return nil }
            let thumb = item.snippet.thumbnails?.medium?.url ?? item.snippet.thumbnails?.high?.url
            return YTTrack(
                id: videoId,
                title: decodeEntities(item.snippet.title),
                artist: decodeEntities(item.snippet.channelTitle),
                thumbnailURL: thumb.flatMap(URL.init(string:)),
                durationSeconds: nil
            )
        }
    }

    static func applyDurations(_ durations: [String: Int], to tracks: [YTTrack]) -> [YTTrack] {
        tracks.map { track in
            var copy = track
            copy.durationSeconds = durations[track.id]
            return copy
        }
    }

    static func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    /// Parses the ISO 8601 durations the API returns, for example
    /// `PT3M25S`, `PT1H2M3S`, `PT45S`. Returns nil for live streams
    /// (`P0D`) and malformed values.
    static func parseISO8601Duration(_ text: String) -> Int? {
        guard text.hasPrefix("PT") else { return nil }
        var total = 0
        var number = ""
        var sawComponent = false
        for ch in text.dropFirst(2) {
            if ch.isNumber {
                number.append(ch)
            } else {
                guard let value = Int(number) else { return nil }
                switch ch {
                case "H": total += value * 3600
                case "M": total += value * 60
                case "S": total += value
                default: return nil
                }
                sawComponent = true
                number = ""
            }
        }
        return sawComponent ? total : nil
    }
}
