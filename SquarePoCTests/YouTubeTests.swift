import XCTest
@testable import SquarePoC

final class YouTubeTests: XCTestCase {

    // MARK: Search response parsing (real API shape, recorded fixture)

    private let searchFixture = """
    {
      "items": [
        { "id": { "kind": "youtube#video", "videoId": "dQw4w9WgXcQ" },
          "snippet": { "title": "Tom &amp; Jerry &#39;Theme&#39;",
                       "channelTitle": "Classic &quot;Toons&quot;",
                       "thumbnails": { "medium": { "url": "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg" } } } },
        { "id": { "kind": "youtube#channel", "channelId": "UC123" },
          "snippet": { "title": "A channel, not a video", "channelTitle": "Someone",
                       "thumbnails": { "medium": { "url": "https://example.com/x.jpg" } } } },
        { "id": { "kind": "youtube#video", "videoId": "abc123_-XYZ" },
          "snippet": { "title": "Second Song", "channelTitle": "Second Artist",
                       "thumbnails": { "high": { "url": "https://i.ytimg.com/vi/abc123_-XYZ/hqdefault.jpg" } } } }
      ]
    }
    """

    func testSearchResponseMapsOnlyVideosAndDecodesEntities() throws {
        let response = try JSONDecoder().decode(YTSearchResponse.self, from: Data(searchFixture.utf8))
        let tracks = YTMapper.tracks(from: response)
        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks[0].id, "dQw4w9WgXcQ")
        XCTAssertEqual(tracks[0].title, "Tom & Jerry 'Theme'")
        XCTAssertEqual(tracks[0].artist, "Classic \"Toons\"")
        XCTAssertEqual(tracks[0].thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg")
        XCTAssertEqual(tracks[1].thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/abc123_-XYZ/hqdefault.jpg")
    }

    func testEmptySearchResponseMapsToNoTracks() throws {
        let response = try JSONDecoder().decode(YTSearchResponse.self, from: Data(#"{"items": []}"#.utf8))
        XCTAssertTrue(YTMapper.tracks(from: response).isEmpty)
    }

    // MARK: Durations

    func testISO8601DurationParsing() {
        XCTAssertEqual(YTMapper.parseISO8601Duration("PT3M25S"), 205)
        XCTAssertEqual(YTMapper.parseISO8601Duration("PT1H2M3S"), 3723)
        XCTAssertEqual(YTMapper.parseISO8601Duration("PT45S"), 45)
        XCTAssertEqual(YTMapper.parseISO8601Duration("PT10M"), 600)
        XCTAssertNil(YTMapper.parseISO8601Duration("P0D"))
        XCTAssertNil(YTMapper.parseISO8601Duration("PT"))
        XCTAssertNil(YTMapper.parseISO8601Duration("nonsense"))
    }

    func testApplyDurationsAndDurationText() {
        let tracks = [
            YTTrack(id: "a", title: "A", artist: "X", thumbnailURL: nil, durationSeconds: nil),
            YTTrack(id: "b", title: "B", artist: "Y", thumbnailURL: nil, durationSeconds: nil),
        ]
        let updated = YTMapper.applyDurations(["a": 205], to: tracks)
        XCTAssertEqual(updated[0].durationText, "3:25")
        XCTAssertEqual(updated[1].durationText, "")
    }

    // MARK: Player state machine (messages from the official player)

    @MainActor
    func testPlayerStateTransitionsFromPlayerMessages() {
        let controller = YouTubePlayerController()
        let track = YTTrack(id: "dQw4w9WgXcQ", title: "Song", artist: "Artist", thumbnailURL: nil, durationSeconds: 205)
        controller.select(track)
        XCTAssertEqual(controller.state, .loading)
        XCTAssertEqual(controller.duration, 205)

        controller.handleStateMessage(NSNumber(value: 3))
        XCTAssertEqual(controller.state, .buffering)
        controller.handleStateMessage(NSNumber(value: 1))
        XCTAssertEqual(controller.state, .playing)
        controller.handleStateMessage(NSNumber(value: 2))
        XCTAssertEqual(controller.state, .paused)
        controller.handleStateMessage(NSNumber(value: 0))
        XCTAssertEqual(controller.state, .ended)
    }

    @MainActor
    func testPlayerReportsEmbeddingRestrictionAsError() {
        let controller = YouTubePlayerController()
        controller.handleStateMessage("error:150")
        guard case .failed(let message) = controller.state else {
            return XCTFail("expected failed state, got \(controller.state)")
        }
        XCTAssertTrue(message.contains("does not allow"))
    }

    @MainActor
    func testPlayerTimeUpdates() {
        let controller = YouTubePlayerController()
        controller.handleTimeMessage("42.5/205")
        XCTAssertEqual(controller.currentTime, 42.5, accuracy: 0.001)
        XCTAssertEqual(controller.duration, 205, accuracy: 0.001)
        controller.handleTimeMessage("garbage")
        XCTAssertEqual(controller.currentTime, 42.5, accuracy: 0.001)
    }

    // MARK: Embed page

    func testEmbedPageCarriesVideoIdAndRejectsBadIds() {
        let page = YouTubePlayerWebView.pageHTML(videoId: "dQw4w9WgXcQ")
        XCTAssertTrue(page.contains("videoId: 'dQw4w9WgXcQ'"))
        let bad = YouTubePlayerWebView.pageHTML(videoId: "x';alert(1);//")
        XCTAssertFalse(bad.contains("alert(1)"))
    }
}
