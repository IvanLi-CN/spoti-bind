# SpotiBind 媒体键转发实现状态

> 当前有效规范仍以 `./SPEC.md` 为准；这里记录实现覆盖、交付进度与 rollout 相关事实，避免这些细节散落到 PR / Git 历史里。

## Current Status

- Implementation: multi-player routing implementation present; real-Mac release validation pending
- Lifecycle: active
- Catalog note: SwiftPM app/core/test targets, a window-style `MenuBarExtra`
  surface, a retained Advanced Settings window, an Icon Composer resource-only
  Xcode target, shared bundle assembly, Ad Hoc packaging, CI, and user-facing
  docs are checked in.
- Product identity: SpotiBind is used for the executable, bundle, release
  artifacts, and public documentation; the Fastpotify CLI integration remains
  unchanged.
- Visual evidence: the app exposes pre-start `UIDemoScenario` state for seven
  smoke scenes and two explicit appearances. Popover evidence waits for the
  actual `MenuBarExtra(.window)` host, opens its real status button through
  the app-owned status-bar window, validates the unique AX window and matching
  WindowServer geometry, and captures it in-process; settings evidence is
  delegated to the strict PID/window-ID helper scripts.

## Implementation Coverage

- Requirement coverage: `REQ-FASTPOTIFY-001` through `REQ-FASTPOTIFY-007` are implemented by the Core, App, scripts, workflows, and documentation paths in this repository.
- Verification commands: `swift test`, `scripts/macos/build.sh`,
  `scripts/macos/compile-icon-resources.sh`, `scripts/macos/package.sh`, and
  `scripts/macos/verify-release.sh`.
- Rollout facts: verified main merges publish a public Ad Hoc Release automatically; each GUI player requires a pre-merge Finder trust and cold-start media-key check before it is advertised as supported.

## Coverage / rollout summary

- The multi-player implementation is assembled from the fixed macOS 13 baseline. Local app compilation and XCTest have passed; physical media-key checks remain environment-dependent. Spotifly requires macOS 26.2+ for real-device validation.
- Sonora's tray-only activation policy is treated as a launchable input state.
  The next media key reopens and activates Sonora's main window, waits for its
  PID keyboard input surface, and dispatches the captured gesture once.
  Spotify and Spotifly launch requests explicitly keep the application in the
  background; a launch timeout drains its underlying open operation before the
  next queued gesture can run, while an unresolved launch barrier fails later
  dispatch calls immediately instead of waiting indefinitely.
- Advanced Settings persists Automatic or custom locations for Spotify,
  Fastpotify, Sonora, and Spotifly. Fastpotify accepts an app bundle or CLI;
  Spotify, Sonora, and Spotifly validate the selected bundle identifier.
  Invalid saved locations remain unavailable and expose a settings action
  rather than falling back.
- Accessibility checks are silent at startup. The system prompt is deferred
  until an explicit active-mode selection or a menu media-control click. Status
  refreshes run from the app lifecycle and periodic timer without prompting;
  the synchronous event callback only decodes a recognized media key, performs
  a silent trust check, and routes from the cached readiness and application URL
  state. It never scans player availability or waits for launch. Unknown
  system-defined events and all mouse/keyboard events pass through unchanged.
  A readiness change reconciles the event tap outside the callback.
- PlayerLaunchCoordinator starts the ten-second launch deadline when a launch
  request enters the serial queue. A queued request that expires while an
  earlier gesture is still draining never launches or dispatches. A timed-out
  dispatch remains pending until its runtime task finishes, and a queued
  request remains linked to its predecessor until that predecessor finishes,
  so a late cancellation-insensitive side effect cannot overlap the next
  gesture. Queue wait now returns the caller's timeout at its own deadline while
  the tail operation drains the predecessor and skips its own side effect. The
  timeout gate uses an independent GCD deadline signal so the caller result
  does not depend on cooperative task scheduling. A timed-out launch likewise
  keeps its barrier and queue tail until the launch task has finished.
- PlayerLaunchCoordinator conforms to `PlayerDispatching` and returns a
  `PlayerDispatchResult` for every gesture. Launch failures, launch timeouts,
  target readiness failures, dispatch failures, dispatch timeouts, and launch
  barriers remain distinguishable to AppState without changing the serial
  no-replay contract.
- SystemPlayerRuntime logs only the player identifier, launch stage, NSError
  domain, and code for an `NSWorkspace` launch callback failure. Finder
  recovery is injected through `PlayerApplicationRevealing`; the production
  implementation reveals the selected bundle and tests record the URL.
- Demo mode uses an ephemeral defaults object, neutral display paths, and no
  player/runtime side effects. Its healthy baseline represents Sonora running,
  all four supported players discoverable, and Accessibility authorized. The
  Demo process uses a regular activation policy so an owner can identify it
  during capture; the shipped app remains an accessory app.
- The menu panel keeps its three transport controls on one native Glass surface
  where the system provides it. The Advanced Settings window uses the platform
  window material and fits its content height on first presentation and on an
  Accessibility-guidance visibility change, without overriding subsequent
  user resizing.
- The menu-bar label loads the tightly cropped `spotibind-status-bar.svg` as
  `StatusBarMark.svg`, preserving the full mark at menu-bar scale, and falls
  back to `waveform` when the resource is absent. Opening retained Advanced
  Settings switches the shipped app to regular activation policy; closing the
  window restores accessory, while UI Demo stays regular.
- The Spotify option loads the bundled official monochrome mark as
  `SpotifyMark.svg`, marks it as an AppKit template image, and applies the same
  `.primary` tint treatment as the other player choices.
- The Icon Composer `tinted` specialization uses the dedicated white
  `spotibind-icon-mono.svg` foreground so Clear and Tinted dark styles retain
  contrast; the original black `spotibind-logo-monochrome.svg` remains an
  independent logo asset and is not used as an application-icon source.
- Current visual evidence is scoped to live SpotiBind windows only and covers
  the menu panel plus normal and Accessibility-guidance settings states.

## Remaining Gaps

- Real macOS 13 Fastpotify/Sonora and macOS 26.2+ Spotifly physical-key validation requires access to matching hardware and installed applications. GUI-player support claims remain blocked until the pre-merge Finder trust and cold-start check is recorded.
- Apple's public `MenuBarExtra` API still has no presentation action; the Demo
  capture path uses the app-owned real status-bar window and public AppKit
  `performClick` to open the host, then fails closed after a bounded wait.
  The `player-launch-failure` scene is available for deterministic status-card
  and Finder-action smoke coverage. The four healthy evidence PNGs and the
  bounded four-image launch-failure smoke set are committed below; the
  pre-existing
  `menu-popover.png` remains a legacy asset and is not counted.

## Related Changes

- The multi-player routing and adapter boundary are defined by ADR-0008; record PR, commit, review, and compatibility references here after delivery.

## References

- `./SPEC.md`
- `./HISTORY.md`
