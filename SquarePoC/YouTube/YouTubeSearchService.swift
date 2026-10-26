import Foundation

/// Stores the user's own YouTube Data API v3 key on this device only.
/// The key is never part of the source code or the repository; the
/// user creates it for free in their own Google Cloud project and
/// pastes it into the app once.
enum YTAPIKeyStore {
    private static let defaultsKey = "yt_data_api_key"
    static var key: String? {
        get { UserDefaults.standard.string(forKey: defaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }
    static var hasKey: Bool { !(key ?? "").isEmpty }
}

enum YTSearchError: Error, Equatable {
    case missingAPIKey
    case network(String)
    case httpStatus(Int)
    case quotaExceeded
    case decoding(String)

    var userMessage: String {
        switch self {
        case .missingAPIKey:
            return "Add your free YouTube Data API key first. It stays on this phone only."
        case .network(let detail):
            return "Network problem: \(detail)"
        case .httpStatus(let code):
            return "YouTube answered with HTTP \(code). Check the API key and try again."
        case .quotaExceeded:
            return "The free daily quota for this API key is used up. Try again tomorrow."
        case .decoding:
            return "YouTube's answer could not be read."
        }
    }
}

/// Real search against the official YouTube Data API v3.
/// Search itself is `search.list` (video type, music category);
/// durations come from a batched `videos.list` call, because search
/// results do not carry durations.
struct YouTubeSearchService {
    var session: URLSession = .shared

    func search(query: String) async throws -> [YTTrack] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let key = YTAPIKeyStore.key, !key.isEmpty else { throw YTSearchError.missingAPIKey }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoCategoryId", value: "10"),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "key", value: key),
        ]
        let data = try await fetch(components.url!)
        let response: YTSearchResponse
        do {
            response = try JSONDecoder().decode(YTSearchResponse.self, from: data)
        } catch {
            throw YTSearchError.decoding(String(describing: error))
        }
        var tracks = YTMapper.tracks(from: response)
        if !tracks.isEmpty {
            let durations = await fetchDurations(ids: tracks.map(\.id), key: key)
            tracks = YTMapper.applyDurations(durations, to: tracks)
        }
        return tracks
    }

    private func fetchDurations(ids: [String], key: String) async -> [String: Int] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails"),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "key", value: key),
        ]
        guard let url = components.url, let data = try? await fetch(url),
              let response = try? JSONDecoder().decode(YTVideosResponse.self, from: data)
        else { return [:] }
        var result: [String: Int] = [:]
        for item in response.items ?? [] {
            if let duration = item.contentDetails?.duration,
               let seconds = YTMapper.parseISO8601Duration(duration) {
                result[item.id] = seconds
            }
        }
        return result
    }

    private func fetch(_ url: URL) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw YTSearchError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { return data }
        switch http.statusCode {
        case 200: return data
        case 403:
            // The API marks exhausted quota with a 403 whose body
            // names quotaExceeded; surface that instead of a raw code.
            if let body = String(data: data, encoding: .utf8), body.contains("quotaExceeded") {
                throw YTSearchError.quotaExceeded
            }
            throw YTSearchError.httpStatus(403)
        default:
            throw YTSearchError.httpStatus(http.statusCode)
        }
    }
}
