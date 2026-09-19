# Testing

SpotiBind validates its behavior at four layers.

- Core XCTest cases cover media-key decoding, mode migration, deterministic
  player selection, shortcut mappings, executable discovery, CLI arguments,
  player path settings and legacy Reset behavior, cold-start timeouts, serial
  dispatch, and event-tap recovery policy.
- The app UI smoke pass covers the window-style menu, the retained settings
  window, 3x2 routing selection, visible problem actions, path chooser/reset,
  and deferred Accessibility prompting in both system appearances.
- UI demo state is selected before `AppState.start()` with
  `SPOTIBIND_UI_DEMO=1`, `SPOTIBIND_UI_DEMO_SCENE`, and
  `SPOTIBIND_UI_APPEARANCE=light|dark`. Supported scenes are `healthy`,
  `automatic-selection`, `accessibility-required`, `no-supported-player`,
  `path-unavailable`, `dispatch-failure`, and `player-launch-failure`. Demo
  mode uses neutral paths and never reads or writes the user's defaults,
  prompts for Accessibility, discovers players, or posts media keys.
- Theme evidence uses `scripts/macos/capture-theme-ui.sh <light|dark> <out-dir> [scene]`.
  It writes `theme-<appearance>-popover.png` and
  `theme-<appearance>-settings.png`. The popover image is captured only from
  the visible real `MenuBarExtra(.window)` host in the app process. Demo mode
  opens that host through the app-owned status-bar window and public AppKit
  `performClick`, verifies the unique AX `AXWindow` with an empty title and
  matching size, then captures its unique WindowServer window ID with
  `screencapture -x -l`. The settings image is captured by
  `scripts/macos/capture-settings-window.sh <scene> <out.png>` with a strict
  PID, bundle identity, title, AX role, normal layer, visibility, unique
  WindowServer ID, and `screencapture -x -l`; all failures are bounded and
  fail closed.
- Real-Mac routing must include a Sonora tray-only case: the next media key
  must reopen and activate Sonora's main window, then reach its PID shortcut
  exactly once without replaying the captured gesture.
- Real-Mac routing must include Spotify Desktop: Space, Down Arrow, and Up
  Arrow must reach the Spotify PID exactly once per press without activating
  the app.
- Real-Mac application lifecycle must include a duplicate packaged-app launch:
  invoke `open` on the same `.app` while SpotiBind is running, including with
  Advanced Settings hidden or minimized. The existing PID and settings window
  must be reused, the window must return to the front without losing its frame
  or unsaved state, and closing it must restore the accessory presentation.
- Representative packaged-app evidence: a temporary Ad Hoc bundle with an
  isolated bundle identifier was launched twice through
  `NSWorkspace.openApplication`, the public Launch Services API equivalent of
  a normal `open` request. The second request retained the original PID and
  one Accessibility settings window; no `open -n` or forced second instance
  was used. The local command policy blocked invoking the shell `open`
  executable directly, so this evidence covers the Launch Services handoff
  through its native API path rather than the shell wrapper.
- macOS CI runs the SwiftPM core tests and builds the app for both advertised target triples.
- The app build and release jobs use `macos-26` with Xcode 26.4+ for the
  Icon Composer resource target; Swift test jobs remain on `macos-15`.
- Release validation verifies both universal architectures, the Ad Hoc
  signature, the DMG's mounted installation layout (application bundle,
  `/Applications` alias, Finder view metadata, and background), the Icon
  Composer `Assets.car`, the macOS 13 fallback icon, and published SHA-256
  checksums.
- A real Mac release checklist covers Accessibility authorization changes,
  Tap Quarantine recovery through revocation and restoration, target liveness,
  another player in the foreground, and sleep/wake. Fastpotify and Sonora
  checks run on macOS 13+; Spotifly checks run only on a macOS 26.2+
  environment that can install its current release.

Before a GUI player is claimed as supported, the candidate artifact must pass a
pre-merge real-Mac check: approve the player's first launch from Finder, close
the player, cold-start SpotiBind, and verify one initiating media key is
delivered exactly once. Record macOS version, architecture, player version, and
result. The broader real-Mac checklist below remains supplementary post-release
evidence because CI cannot grant Accessibility authorization or reproduce all
physical media-key routing; this gate does not add a GitHub Actions required
context or change the automatic release workflow.

Run the local commands from the repository root:

```sh
scripts/macos/test.sh
bash scripts/macos/test-ui-capture-contract.sh
scripts/macos/build.sh --configuration release
scripts/macos/package.sh
scripts/macos/verify-release.sh
```

The complete Xcode developer toolchain is required for XCTest and for the
resource-only Icon Composer target. Run `scripts/macos/compile-icon-resources.sh`
before packaging when checking the resource chain directly. The repository's
Xcode project does not compile Swift source or tests.

CI explicitly selects an installed Xcode toolchain whose compiler reports
Swift 6 before running tests or packaging. A runner image without Swift 6 is a
configuration failure rather than a reason to lower the package's language
mode.

Because V1 supports macOS 13 and later, release evidence should include a real macOS 13 validation run for every architecture it claims to support. A build-only deployment-target check is not evidence that Accessibility and physical media-key routing work on that system.

The automated contract names are `ApplicationDelegateTests`,
`PlayerSelectionTests`, `PlayerDispatchTests`,
`PlayerLaunchCoordinatorTests`, `RoutingPolicyTests`,
`MediaKeyDecoderTests`, and `FastpotifyIntegrationTests`.

`MediaKeyEventRouterTests`, `MediaKeyTapControllerTests`, and
`AppStateAccessibilityPollingTests` form the input-safety regression suite:
they assert that auxiliary mouse system-defined events, mouse events, and
ordinary keyboard event types cannot enter media-key routing or be consumed by
the event tap; that running Accessibility revocation is observed; and that a
system-disabled tap remains quarantined until trust is revoked and restored.

`UIDemoScenarioTests` and `UIAppearanceTests` cover the pre-start demo
projection and the light/dark appearance contract. Full healthy visual
evidence is limited to the two supported surfaces, `popover` and
`settings-window`; `player-launch-failure` and the other error scenes are
smoke-only and do not produce committed complete PNG matrices. This change
records a bounded four-image `player-launch-failure` smoke set for the real
popover and settings surfaces after their WindowServer gates pass. The legacy
`docs/specs/spotibind/assets/menu-popover.png` is not counted as a current
evidence asset.
