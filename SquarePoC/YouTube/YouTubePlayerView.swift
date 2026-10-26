import SwiftUI
import WebKit

/// Playback through YouTube's official embedded (IFrame) player.
/// The app never touches a direct stream URL: search metadata comes
/// from the Data API, and the audio/video itself plays inside
/// YouTube's own player, which is the playback route YouTube
/// permits for third party apps.
@MainActor
final class YouTubePlayerController: ObservableObject {
    enum PlaybackState: Equatable {
        case idle
        case loading
        case playing
        case paused
        case buffering
        case ended
        case failed(String)
    }

    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var track: YTTrack?

    weak var webView: WKWebView?

    func select(_ track: YTTrack) {
        self.track = track
        state = .loading
        currentTime = 0
        duration = Double(track.durationSeconds ?? 0)
    }

    func play() { webView?.evaluateJavaScript("player && player.playVideo()") }
    func pause() { webView?.evaluateJavaScript("player && player.pauseVideo()") }
    func togglePlayPause() {
        if state == .playing { pause() } else { play() }
    }
    func seek(to seconds: Double) {
        webView?.evaluateJavaScript("player && player.seekTo(\(seconds), true)")
        currentTime = seconds
    }

    // MARK: Messages from the IFrame player page

    func handleStateMessage(_ body: Any) {
        if let code = body as? NSNumber {
            switch code.intValue {
            case 1: state = .playing
            case 2: state = .paused
            case 3: state = .buffering
            case 0: state = .ended
            case 5: if state == .loading { state = .paused }
            default: break
            }
            return
        }
        if let text = body as? String {
            if text == "ready" {
                // The user tapped this track to hear it: start at once.
                play()
            } else if text.hasPrefix("error:") {
                let code = text.dropFirst("error:".count)
                if code == "101" || code == "150" {
                    state = .failed("This video's owner does not allow playback in other apps.")
                } else {
                    state = .failed("The YouTube player reported an error (\(code)).")
                }
            }
        }
    }

    func handleTimeMessage(_ body: Any) {
        guard let text = body as? String else { return }
        let parts = text.split(separator: "/")
        guard parts.count == 2, let cur = Double(parts[0]), let dur = Double(parts[1]) else { return }
        currentTime = cur
        if dur > 0 { duration = dur }
    }
}

/// The WKWebView that hosts the official player page for one video.
/// SwiftUI rebuilds it per track via `.id(track.id)`.
struct YouTubePlayerWebView: UIViewRepresentable {
    let videoId: String
    @ObservedObject var controller: YouTubePlayerController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        content.add(context.coordinator, name: "ytstate")
        content.add(context.coordinator, name: "yttime")
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        controller.webView = webView
        webView.loadHTMLString(Self.pageHTML(videoId: videoId), baseURL: URL(string: "https://www.youtube-nocookie.com"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "ytstate")
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "yttime")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let controller: YouTubePlayerController
        init(controller: YouTubePlayerController) { self.controller = controller }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            Task { @MainActor in
                switch message.name {
                case "ytstate": controller.handleStateMessage(message.body)
                case "yttime": controller.handleTimeMessage(message.body)
                default: break
                }
            }
        }
    }

    /// The embed page: the IFrame API creates YouTube's own player,
    /// and a small bridge forwards state and time to the app. The
    /// video id is validated before it reaches this page.
    static func pageHTML(videoId: String) -> String {
        let safeId = videoId.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } ? videoId : ""
        return """
        <!DOCTYPE html>
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;height:100%}#player{width:100%;height:100%}</style>
        </head><body>
        <div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var player = null;
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            width: '100%', height: '100%',
            videoId: '\(safeId)',
            playerVars: { playsinline: 1, rel: 0, modestbranding: 1 },
            events: {
              onReady: function() { window.webkit.messageHandlers.ytstate.postMessage('ready'); },
              onStateChange: function(e) { window.webkit.messageHandlers.ytstate.postMessage(e.data); },
              onError: function(e) { window.webkit.messageHandlers.ytstate.postMessage('error:' + e.data); }
            }
          });
        }
        setInterval(function() {
          if (player && player.getCurrentTime) {
            window.webkit.messageHandlers.yttime.postMessage(player.getCurrentTime() + '/' + player.getDuration());
          }
        }, 500);
        </script>
        </body></html>
        """
    }
}
