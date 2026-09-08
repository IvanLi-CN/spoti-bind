# Testing

SpotiBind validates its behavior at four layers.

- Core XCTest cases cover media-key decoding, mode migration, deterministic
  player selection, shortcut mappings, executable discovery, CLI arguments,
  player path settings and legacy Reset behavior, cold-start timeouts, serial
  dispatch, and event-tap recovery policy.
- The app UI smoke pass covers the window-style menu, the retained settings
  window, 3+2 routing selection, visible problem actions, path chooser/reset,
  and deferred Accessibility prompting in both system appearances.
- Deterministic UI evidence can be captured without Screen Recording through
  `scripts/macos/capture-ui.sh menu <out.png>` and
  `scripts/macos/capture-ui.sh settings <out.png>`. The app renders the real
  menu/settings SwiftUI views in a scoped snapshot window and exits after the
  PNG is written.
- Real-Mac routing must include a Sonora tray-only case: the next media key
  must reopen and activate Sonora's main window, then reach its PID shortcut
  exactly once without replaying the captured gesture.
- macOS CI runs the SwiftPM core tests and builds the app for both advertised target triples.
- Release validation verifies both universal architectures, the Ad Hoc signature, DMG mountability, and published SHA-256 checksums.
- A real Mac release checklist covers Accessibility authorization changes,
  target liveness, another player in the foreground, sleep/wake, and event-tap
  recovery. Fastpotify and Sonora checks run on macOS 13+; Spotifly checks run
  only on a macOS 26.2+ environment that can install its current release.

The real-Mac checklist is a release gate because CI cannot grant Accessibility authorization or reproduce physical media-key routing.

Run the local commands from the repository root:

```sh
scripts/macos/test.sh
scripts/macos/build.sh --configuration release
scripts/macos/package.sh
scripts/macos/verify-release.sh
```

The current Command Line Tools installation can build and sign the app but does
not provide the XCTest module. Use a complete Xcode developer toolchain (or
the macOS CI runner) for `scripts/macos/test.sh`; this does not add an Xcode
project to the repository.

CI explicitly selects an installed Xcode toolchain whose compiler reports
Swift 6 before running tests or packaging. A runner image without Swift 6 is a
configuration failure rather than a reason to lower the package's language
mode.

Because V1 supports macOS 13 and later, a release must include a real macOS 13 validation run for every architecture it claims to support. A build-only deployment-target check is not evidence that Accessibility and physical media-key routing work on that system.

The automated contract names are `PlayerSelectionTests`, `PlayerDispatchTests`,
`PlayerLaunchCoordinatorTests`, `RoutingPolicyTests`,
`MediaKeyDecoderTests`, and `FastpotifyIntegrationTests`.

`MediaKeyEventRouterTests` is the input-safety regression suite: it asserts
that mouse and ordinary keyboard event types cannot enter media-key routing or
be consumed by the event tap.
