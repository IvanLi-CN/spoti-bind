# Testing

SpotiBind validates its behavior at four layers.

- Core XCTest cases cover media-key decoding, mode migration, deterministic
  player selection, shortcut mappings, executable discovery, CLI arguments,
  player path settings and legacy Reset behavior, cold-start timeouts, serial
  dispatch, and event-tap recovery policy.
- The app UI smoke pass covers the window-style menu, the retained settings
  window, 3+2 routing selection, visible problem actions, path chooser/reset,
  and deferred Accessibility prompting in both system appearances.
- UI demo state is selected before `AppState.start()` with
  `SPOTIBIND_UI_DEMO=1`, `SPOTIBIND_UI_DEMO_SCENE`, and
  `SPOTIBIND_UI_APPEARANCE=light|dark`. Supported scenes are `healthy`,
  `accessibility-required`, `no-supported-player`, `path-unavailable`, and
  `dispatch-failure`. Demo mode uses neutral paths and never reads or writes
  the user's defaults, prompts for Accessibility, discovers players, or posts
  media keys.
- Theme evidence uses `scripts/macos/capture-theme-ui.sh <light|dark> <out-dir>`.
  It writes `theme-<appearance>-popover.png` and
  `theme-<appearance>-settings.png`. The popover image is captured only from
  the visible real `MenuBarExtra(.window)` host in the app process. The
  settings image is captured by
  `scripts/macos/capture-settings-window.sh <scene> <out.png>` with a strict
  PID, bundle identity, title, AX role, normal layer, visibility, unique
  WindowServer ID, and `screencapture -x -l`; all failures are bounded and
  fail closed.
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
bash scripts/macos/test-ui-capture-contract.sh
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

`UIDemoScenarioTests` and `UIAppearanceTests` cover the pre-start demo
projection and the light/dark appearance contract. Full healthy visual
evidence is limited to the two supported surfaces, `popover` and
`settings-window`; error scenes are smoke-only and do not produce committed
PNG matrices.
