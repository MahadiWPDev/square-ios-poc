# Feature compatibility matrix

Square (Android) features mapped to iOS, prepared in Phase 1 from the
repository audit, the Phase 0 results and the Phase 1 implementation.
Status key: **Done** means implemented and covered by the automated
tests in this repository. **Native** means it needs a Swift
implementation. **Blocked** means licensing, platform or service
policy prevents it in this project.

## Reusable from the Rust side

| Square capability | iOS status | Notes |
| --- | --- | --- |
| Loudness measurement of local files (ebur128, MIT) | **Done** | The Phase 0 square-core-poc crate. Compiled for iOS device and simulator, packaged as an XCFramework, linked into the app and called from Swift through its C ABI. Covered by unit tests. |
| Original Rust core (patched librespot, GPL-3.0) | Investigated, not integrated | It typechecks for aarch64-apple-ios on a macOS runner (cargo check exit status 0 in Phase 0 run 1). Typechecking is not linking or running: its entry points are Android JNI, it would need a new C ABI, an iOS audio sink instead of AudioTrack and AAudio, and a service policy review before any integration. Deliberately excluded for now (see Phase 3 notes in SERVICE-INTEGRATIONS.md). |
| Bungee audio effects (C++, MPL-2.0) | Not yet evaluated | Platform independent DSP in principle. Only worth revisiting if an effects feature is approved. |

## Requires native Swift implementation

| Feature | iOS status | Notes |
| --- | --- | --- |
| Local audio playback | **Done** | AVAudioPlayer: play, pause, resume, seek, queue with next and previous, real duration and progress. Covered by unit tests. |
| File picking | **Done** | System document picker (fileImporter), audio content types, multiple selection, security scoped access. |
| Background playback | Implemented, simulator limited | AVAudioSession playback category plus the audio background mode in the generated Info.plist. Background behaviour cannot be fully proven in a simulator; it needs a device build to verify end to end. |
| Lock screen and remote controls | Implemented, simulator limited | MPNowPlayingInfoCenter metadata plus MPRemoteCommandCenter play, pause, toggle, next, previous and seek position commands. Same device verification caveat. |
| User interface | In progress | SwiftUI rewrite inspired by Square's design language. Home shelves are still visual references; Player and Library tabs are functional. |
| Downloads of the user's own files | Native, not started | Would be plain file management inside the app sandbox. Only for content the user owns or is allowed to download. |
| Lyrics display for local files | Native, not started | LRCLIB is a public lyrics source; would need its own terms check before use. Not part of Phase 1. |

## Blocked by licensing, platform or service policy

| Square feature | Why it is blocked |
| --- | --- |
| Spotify streaming through the reimplemented protocol (librespot) | Violates Spotify's terms; the Square README itself says this protocol use is not allowed. Never implemented here. |
| Spotify playback inside this app | Spotify offers no SDK for streaming audio inside a third party app. The official iOS SDK only remote controls the Spotify app (see SERVICE-INTEGRATIONS.md). |
| YouTube Music playback through private InnerTube endpoints | There is no official YouTube Music API. Private endpoint use is unauthorised and against YouTube's terms. Never implemented here. |
| Downloading Spotify or YouTube content | Not offered by any official API and prohibited by both services' terms. |
| Widevine protected playback fallback | iOS has no Widevine; FairPlay is licensed only for approved content services. |
| Android Auto | No iOS equivalent for this project. CarPlay audio apps need an Apple entitlement that is unrealistic here. |
| App Store or TestFlight distribution of a full port | GPL-3.0 conflicts with Apple's distribution terms, and App Store Review Guideline 5.2.2 and 5.2.3 require documented permission to stream third party catalogues. |

## Selected audio source for Phase 1

**Local audio only**: files the user explicitly selects, plus an app
generated test tone. This is fully legal, needs no account, no API
key and no network, and it exercises the exact playback, queue,
background and loudness machinery any later, separately approved
source would also need.
