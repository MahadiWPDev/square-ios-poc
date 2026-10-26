# Music service integrations: what is officially permitted

Researched in Phase 1 (26 October 2026) from the services' own
developer documentation. Conclusion up front: neither Spotify nor
YouTube Music offers a permitted way for a third party app to stream
their catalogue inside its own player. That is why Phase 1 is local
audio only.

## Spotify

Official options, per Spotify for Developers:

1. **iOS SDK (App Remote)**. Lets an app interact with the Spotify
   app running in the background: authentication, playback control
   and player state, always in sync because the Spotify app itself
   does the playing, networking and caching.
   - Requires the Spotify app installed on a physical device.
   - Requires a Spotify developer app registration (client ID,
     redirect URI) and user authorisation with the app-remote-control
     scope.
   - On demand playback of specific tracks requires the user's
     Spotify Premium.
   - It is a remote control, not a streaming SDK: no audio ever
     plays inside our app, no downloads, and the Spotify app must be
     actively playing for the connection to stay alive.
2. **Web API**. Catalogue metadata, search, playlists and user
   library data over HTTPS with OAuth. It does not provide a stream
   for third party playback. The old 30 second preview URLs are not
   a playback feature to build on.
3. **Web Playback SDK**. Browser only (desktop web), not available
   to iOS apps.

What Square does on Android instead (reimplementing the Spotify
protocol with a patched librespot) is exactly what Spotify's terms
prohibit, so it is permanently out of scope for this project.

A future, separately approved milestone could add App Remote as a
companion remote control. It would still not turn this app into a
Spotify player, and it needs a physical iPhone with the Spotify app
to test, which the simulator pipeline cannot do.

## YouTube Music

- There is **no official YouTube Music API**. Multiple developer
  sources state this directly; YouTube Music data in third party
  tools comes from the YouTube Data API or from unofficial,
  unauthorised endpoints.
- The **YouTube Data API v3** covers YouTube videos, playlists and
  metadata. Playback of YouTube content must use YouTube's official
  players (for example the IFrame player in a web view), the API
  terms prohibit downloading, and background audio playback of
  YouTube content is not permitted.
- Square's Android approach (NewPipeExtractor and a vendored
  InnerTube client hitting private endpoints, solving challenges)
  is unauthorised protocol use. It is out of scope here, permanently.

## Square features that cannot be reproduced through supported APIs

- In app streaming of the Spotify catalogue.
- In app streaming of YouTube Music.
- Downloads or offline copies from either service.
- Account synchronisation of playback (history, queue) beyond what
  the Spotify Web API exposes as data.
- Background playback of YouTube content.
