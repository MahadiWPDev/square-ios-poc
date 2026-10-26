# Notice and attributions

This repository is a separate iOS proof of concept created by
MD. Hasan Mahadi. It is not the original project and it is not
affiliated with or endorsed by the original author, Spotify or Google.

## Original project

- Square by Lelonio: https://github.com/Lelonio/Square
- An unofficial Android music client for Spotify Premium and
  YouTube Music.
- Licensed under GPL-3.0-or-later. A copy of that licence is kept in
  this repository as LICENSE, and this proof of concept is released
  under the same licence.
- Audited at commit a64b9ee053bdba03398b2f31d65bccc976046612
  (release 2.6.3, 26 October 2026).

## What this proof of concept takes from the original

- Design inspiration only: a floating glass tab bar, a square artwork
  player and a synced lyrics card, re-implemented in original SwiftUI
  code with Apple's own materials and SF Symbols.
- One technical idea with its library: measuring file loudness with
  the ebur128 crate, which the original project credits as MIT
  licensed (https://github.com/sdroege/ebur128). The rust-poc crate in
  this repository wraps that library behind a small C interface.

## What it does not take

- No Kotlin or Rust source code from the original project is copied
  into this repository.
- No icons, images, screenshots or other assets from the original
  project are used. Artwork in the prototype is a generated gradient.
- No Spotify or YouTube content, catalogue, account access, stream,
  protocol re-implementation or private endpoint is included.
- "Square" is used only to name the project this prototype is
  inspired by. Spotify and YouTube Music are trademarks of their
  owners.
