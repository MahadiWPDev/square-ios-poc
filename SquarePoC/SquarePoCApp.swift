import SwiftUI

/// Phase 0 proof of concept entry point.
///
/// This is a standalone SwiftUI prototype inspired by Square's design
/// language. It contains no Spotify or YouTube integration, no copied
/// assets and no playback of third party content. Sample data is local
/// and clearly labelled, so the build can be verified end to end before
/// any real feature work is approved.
@main
struct SquarePoCApp: App {
    @StateObject private var player = SamplePlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
        }
    }
}
