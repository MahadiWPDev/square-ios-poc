import SwiftUI

/// App entry point.
///
/// This is a standalone SwiftUI prototype inspired by Square's design
/// language. Phase 1 adds a real local audio player (AVFoundation)
/// and a linked Rust loudness library. It contains no Spotify or
/// YouTube integration and plays no third party content.
@main
struct SquarePoCApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
