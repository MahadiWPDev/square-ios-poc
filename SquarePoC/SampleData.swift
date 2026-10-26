import SwiftUI

/// Local placeholder content for the prototype.
///
/// Nothing here comes from Spotify, YouTube or any other service. The
/// titles are invented so the interface can be exercised without any
/// third party catalogue, account or stream.
struct SampleTrack: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let durationSeconds: Double
    let colors: [Color]
}

struct SampleShelf: Identifiable {
    let id = UUID()
    let title: String
    let tracks: [SampleTrack]
}

enum SampleLibrary {
    static let tracks: [SampleTrack] = [
        SampleTrack(title: "Morning Demo", artist: "Prototype Artist",
                    durationSeconds: 214, colors: [.orange, .pink]),
        SampleTrack(title: "Glass Horizon", artist: "Sample Session",
                    durationSeconds: 187, colors: [.teal, .blue]),
        SampleTrack(title: "River Town Sketch", artist: "Local Recording",
                    durationSeconds: 243, colors: [.green, .mint]),
        SampleTrack(title: "Night Drive Test", artist: "Prototype Artist",
                    durationSeconds: 198, colors: [.indigo, .purple]),
        SampleTrack(title: "Studio Loop One", artist: "Sample Session",
                    durationSeconds: 176, colors: [.yellow, .orange]),
    ]

    static let shelves: [SampleShelf] = [
        SampleShelf(title: "Made for testing", tracks: tracks),
        SampleShelf(title: "Recently played", tracks: Array(tracks.reversed())),
        SampleShelf(title: "Local files shelf", tracks: Array(tracks.prefix(3))),
    ]
}

/// A tiny fake player. It moves a progress value with a timer so the
/// player interface can be checked in the simulator. It plays no audio.
@MainActor
final class SamplePlayer: ObservableObject {
    @Published var current: SampleTrack? = SampleLibrary.tracks.first
    @Published var isPlaying = false
    @Published var progress: Double = 0.25
    @Published var showPlayer = false

    private var timer: Timer?

    func toggle() {
        guard current != nil else { return }
        isPlaying.toggle()
        timer?.invalidate()
        guard isPlaying else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let track = self.current else { return }
                self.progress += 0.25 / track.durationSeconds
                if self.progress >= 1 {
                    self.progress = 0
                    self.isPlaying = false
                    self.timer?.invalidate()
                }
            }
        }
    }

    func play(_ track: SampleTrack) {
        current = track
        progress = 0
        isPlaying = false
        toggle()
    }

    func seek(to value: Double) {
        progress = min(max(value, 0), 1)
    }
}
