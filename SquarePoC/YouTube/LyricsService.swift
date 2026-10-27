import Foundation

/// One line of synchronized lyrics.
struct LyricLine: Equatable {
    let time: Double
    let text: String
}

/// Parser for LRC synchronized lyrics, the format LRCLIB returns
/// in its `syncedLyrics` field: one or more `[mm:ss.xx]` stamps
/// followed by the line text.
enum LRCParser {
    static func parse(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for raw in lrc.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            var rest = Substring(line)
            var stamps: [Double] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let stamp = rest[rest.index(after: rest.startIndex)..<close]
                guard let seconds = parseStamp(stamp) else { break }
                stamps.append(seconds)
                rest = rest[rest.index(after: close)...]
            }
            let text = String(rest).trimmingCharacters(in: .whitespaces)
            for stamp in stamps {
                lines.append(LyricLine(time: stamp, text: text))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }

    /// Index of the line that should be highlighted at `time`:
    /// the last line whose stamp is not after the current time,
    /// or nil before the first line starts.
    static func currentLineIndex(in lines: [LyricLine], at time: Double) -> Int? {
        var current: Int?
        for (index, line) in lines.enumerated() {
            if line.time <= time { current = index } else { break }
        }
        return current
    }

    private static func parseStamp(_ stamp: Substring) -> Double? {
        // mm:ss.xx — metadata tags like [ar:Artist] fail the
        // numeric parse and are skipped.
        let parts = stamp.split(separator: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1])
        else { return nil }
        return minutes * 60 + seconds
    }
}

/// What the lyrics lookup produced for a track.
enum LyricsResult: Equatable {
    case synced([LyricLine])
    case plain(String)
    case unavailable
    case failed
}

/// Fetches lyrics from LRCLIB (https://lrclib.net), a free
/// community lyrics database that needs no API key or account.
///
/// Licensing note: song lyrics remain the copyright of their
/// respective owners. LRCLIB serves community-contributed lyrics
/// for personal use; this app displays them on the user's device
/// only, attributes the source, and never stores, edits, or
/// redistributes them. If a track has no entry, the panel simply
/// reports that lyrics are unavailable.
struct LyricsService {
    var session: URLSession = .shared

    func fetch(for track: YTTrack) async -> LyricsResult {
        let title = Self.cleanTitle(track.title)
        let artist = Self.cleanArtist(track.artist)
        guard !title.isEmpty else { return .unavailable }

        if let result = await getLyrics(trackName: title, artistName: artist, duration: track.durationSeconds) {
            return result
        }
        // Fall back to a text search when the exact lookup missed,
        // which is common for decorated YouTube titles.
        return await searchLyrics(trackName: title, artistName: artist) ?? .unavailable
    }

    // MARK: Endpoints

    private struct GetResponse: Decodable {
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    private func getLyrics(trackName: String, artistName: String, duration: Int?) async -> LyricsResult? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var query = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName),
        ]
        if let duration { query.append(URLQueryItem(name: "duration", value: String(duration))) }
        components?.queryItems = query
        guard let url = components?.url else { return .failed }
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 { return nil }
            let decoded = try JSONDecoder().decode(GetResponse.self, from: data)
            return result(from: decoded)
        } catch {
            return .failed
        }
    }

    private func searchLyrics(trackName: String, artistName: String) async -> LyricsResult? {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName),
        ]
        guard let url = components?.url else { return .failed }
        do {
            let (data, _) = try await session.data(from: url)
            let decoded = try JSONDecoder().decode([GetResponse].self, from: data)
            for candidate in decoded {
                if let result = result(from: candidate) { return result }
            }
            return nil
        } catch {
            return .failed
        }
    }

    private func result(from response: GetResponse) -> LyricsResult? {
        if let synced = response.syncedLyrics, !synced.isEmpty {
            let lines = LRCParser.parse(synced)
            if !lines.isEmpty { return .synced(lines) }
        }
        if let plain = response.plainLyrics, !plain.isEmpty {
            return .plain(plain)
        }
        return nil
    }

    // MARK: YouTube title and channel cleanup

    /// "Song Name (Official Music Video)" -> "Song Name",
    /// "Song Name [Lyric Video]" -> "Song Name",
    /// "Artist - Song Name" keeps as is (LRCLIB tolerates it).
    static func cleanTitle(_ title: String) -> String {
        var result = title
        for pair in [("(", ")"), ("[", "]")] {
            while let open = result.range(of: pair.0), let close = result.range(of: pair.1) {
                guard open.lowerBound < close.lowerBound else { break }
                result.removeSubrange(open.lowerBound...close.lowerBound)
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// "Artist - Topic" -> "Artist", "ArtistVEVO" -> "Artist".
    static func cleanArtist(_ artist: String) -> String {
        var result = artist
        if result.hasSuffix(" - Topic") {
            result = String(result.dropLast(" - Topic".count))
        }
        if result.hasSuffix("VEVO") {
            result = String(result.dropLast(4))
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
