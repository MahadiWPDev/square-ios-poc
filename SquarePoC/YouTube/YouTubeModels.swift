import Foundation

/// One YouTube video as the app uses it. Built only from YouTube Data
/// API v3 responses; there are no sample or placeholder tracks.
struct YTTrack: Identifiable, Equatable {
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
