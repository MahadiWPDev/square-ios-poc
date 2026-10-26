# Square PoC for iOS

A Phase 0 proof of concept: a standalone SwiftUI prototype inspired by
the design of [Square](https://github.com/Lelonio/Square), the
unofficial Android music client for Spotify Premium and YouTube Music,
plus a small Rust investigation into what of its audio stack can
compile for iOS.

This repository is separate from the original project. The original
Android code is not modified and none of it is copied here. See
[NOTICE.md](NOTICE.md) for attributions and licence details.

## What Phase 0 proves

1. A minimal SwiftUI app with a glass tab bar, home shelves, a mini
   player and a full player sheet compiles on a real macOS runner
   with a current Xcode, installs into an iOS simulator, launches,
   and is screenshotted, all in GitHub Actions.
2. A small, legally distributable slice of the audio stack used by
   Square (loudness measurement with the MIT licensed ebur128 crate)
   compiles for `aarch64-apple-ios` and `aarch64-apple-ios-sim` and
   packages as an XCFramework.
3. Whether the original project's own Rust core typechecks for iOS is
   tested and logged as an experiment, not assumed.

## What Phase 0 is not

- Not a port. There is no Spotify or YouTube integration, no real
  catalogue, no streaming, no downloads and no account sign-in.
- Not installable on a physical iPhone. The build is an unsigned
  simulator build. See
  [docs/INSTALL-ON-IPHONE.md](docs/INSTALL-ON-IPHONE.md) for the exact
  routes and costs to a real device.
- Not on TestFlight, and no TestFlight availability is promised.

## Layout

- `SquarePoC/` the SwiftUI app sources.
- `SquarePoC.xcodeproj` the Xcode project.
- `rust-poc/` the square-core-poc Rust crate and its C header.
- `.github/workflows/ios-poc.yml` the macOS build and Rust jobs.
- `docs/` installation notes and, after the first run, the Phase 0
  results.

## Build results

Every push runs the workflow. Builds are published as pre-releases
named "Phase 0 PoC build N" with the simulator app ZIP, the full
xcodebuild log, a simulator screenshot and the Rust outputs attached.

## Licence

GPL-3.0-or-later, the same licence as the original project. See
[LICENSE](LICENSE).
