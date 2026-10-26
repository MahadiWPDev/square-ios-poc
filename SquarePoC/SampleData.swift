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

/// Phase 1 note: the fake timer based SamplePlayer from Phase 0 was
/// removed. Playback is now handled by the real AudioPlayer in
/// AudioPlayer.swift, and these sample cards remain as visual design
/// references on the Home tab only.
