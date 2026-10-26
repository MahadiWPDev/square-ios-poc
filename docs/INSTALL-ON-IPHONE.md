# Installing the prototype on a physical iPhone

## What Phase 0 produces

The GitHub Actions build produces an **unsigned iOS Simulator build**
of SquarePoC (`SquarePoC-simulator-app.zip`). A simulator build runs
only inside the iOS Simulator on a Mac. It cannot be installed on a
physical iPhone, and no setting changes that. Phase 0 exists to prove
the source compiles and the app runs; device installation is a
separate, later step.

## The three real routes to a physical iPhone

### Route 1: Free provisioning (personal team)

- Needs: a Mac with Xcode (owned, borrowed or rented by the hour),
  your own Apple Account, a USB or Wi-Fi connection to the iPhone.
- Steps on the Mac: open this project in Xcode, sign in with your
  Apple Account under Settings, Accounts, select your Personal Team
  for the SquarePoC target, connect the iPhone, trust the computer on
  the phone, then Run.
- On the iPhone: Settings, General, VPN and Device Management, trust
  your own developer certificate.
- Limits: the app stops launching after 7 days and must be rebuilt or
  re-signed; at most 3 such apps at once; no TestFlight.
- Cost: 0. Blocker for this project today: there is no Mac available,
  and a cloud CI runner cannot sign with your personal team without
  your Apple credentials, which must never be shared.

### Route 2: Apple Developer Program, then Ad Hoc or TestFlight

- Needs: enrolment in the Apple Developer Program, 99 USD per year,
  paid to Apple by you. Nobody should enrol you or pay on your behalf
  without your explicit approval for that purchase.
- After enrolment, a CI workflow like this one can be extended to sign
  a device build and either register your iPhone's UDID for an Ad Hoc
  install or upload the build to App Store Connect for TestFlight.
- TestFlight notes: internal testers (your own App Store Connect
  team) can install without a beta review; external testers need
  Apple's beta review, and a full version of the original app's
  feature set would face the licensing and third party service
  questions documented in the audit. This prototype's reduced feature
  set is a different case, but no TestFlight availability is promised
  before the build and the account exist and the requirements are
  verified.
- Cost: 99 USD per year. This is the only route that gives a build
  that keeps working for a year without re-signing.

### Route 3: Sideloading tools (AltStore or SideStore)

- These tools re-sign the app with your free Apple Account from a
  computer and refresh it about every 7 days.
- Initial setup needs a computer on the same Wi-Fi network. With no
  Mac or PC of your own, this route only works if you can use someone
  else's computer for the setup and the refreshes.
- Cost: 0, with the same 7 day limit as Route 1.

## What is not a route

- Installing the simulator ZIP from this repository on the phone.
- Any service that asks for your Apple Account password. Never share
  it; signing must happen through Xcode, App Store Connect or the
  sideloading tool on a machine you control, never through a website
  form or a chat.

## Recommended next step after Phase 0

Decide between Route 1 with a rented or borrowed Mac for a first
hands-on test (0 cost, 7 day limit), or Route 2 when the prototype is
worth 99 USD per year. That decision, and any payment, is yours
alone.

## Route 1 step by step for this project (friend's Mac, Personal Team)

Verified against this repository. The CI device validation job
proves the project compiles and links for a generic iOS device with
signing disabled; the steps below add your own free signing on the
Mac and install the app on your iPhone.

What you need: the Mac with the current Xcode from the App Store
(free), your iPhone and its cable, your own Apple Account. You type
your Apple Account password only into Xcode on that Mac yourself.
Never send it to anyone, and nothing signing related is stored in
this repository.

1. On the Mac, download this repository: open the repository page on
   GitHub, Code, Download ZIP, and unzip it.
2. The Rust framework is not stored in git. Download
   `SquareCorePOC.xcframework.zip` from the newest `poc-build` release
   on the repository's Releases page, unzip it, and put the resulting
   `SquareCorePOC.xcframework` folder at
   `SquarePoC/Frameworks/SquareCorePOC.xcframework` inside the
   unzipped project (create the `Frameworks` folder if needed).
3. Open `SquarePoC.xcodeproj` in Xcode.
4. Xcode menu, Settings, Accounts, plus button: sign in with your
   own Apple Account. This creates your free Personal Team.
5. In the project navigator select the project, then the SquarePoC
   target, Signing and Capabilities tab: tick "Automatically manage
   signing" and set Team to your name (Personal Team). Repeat the
   same for the SquarePoCTests target.
6. Connect the iPhone by cable, unlock it, and tap Trust on the
   phone if asked. On the iPhone, enable Developer Mode: Settings,
   Privacy and Security, Developer Mode, on, then restart the phone
   and confirm.
7. In Xcode's top bar, choose your iPhone as the run destination and
   press Run (the play button). Xcode builds, signs with your
   Personal Team, installs, and launches the app.
8. If the first launch is blocked, on the iPhone go to Settings,
   General, VPN and Device Management, open the developer app entry
   for your Apple Account, and tap Trust. Then open Square PoC.
9. To test background audio for real: in the Player tab use "Play
   generated test tone" or open one of your own audio files, press
   play, then lock the phone. The tone should keep playing and the
   lock screen should show the player controls.

Limits and troubleshooting:

- The free install stops launching after 7 days. Connect the phone
  to the same Mac and press Run in Xcode again to renew it.
- At most 3 free provisioned apps can be installed at once, and a
  Personal Team can register only a small number of app IDs per
  week.
- If Xcode says the bundle identifier `dev.mahadi.squarepoc` is not
  available, change the app target's Bundle Identifier to something
  unique such as `dev.mahadi.squarepoc.phone` and the test target's
  to the same prefix plus `.tests`, then Run again.
- If the phone's iOS version is newer than the Xcode on the Mac
  supports, update Xcode first; a device build requires a matching
  or newer Xcode.
