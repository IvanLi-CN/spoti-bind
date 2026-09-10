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
- Visual evidence: the app exposes pre-start `UIDemoScenario` state for five
  smoke scenes and two explicit appearances. Popover evidence waits for the
  actual `MenuBarExtra(.window)` host, opens its real status button through
  the app-owned status-bar window, and captures it in-process; settings
  evidence is delegated to the strict PID/window-ID helper scripts.

## Implementation Coverage

- Requirement coverage: `REQ-FASTPOTIFY-001` through `REQ-FASTPOTIFY-006` are implemented by the Core, App, scripts, workflows, and documentation paths in this repository.
- Verification commands: `swift test`, `scripts/macos/build.sh`,
  `scripts/macos/compile-icon-resources.sh`, `scripts/macos/package.sh`, and
  `scripts/macos/verify-release.sh`.
- Rollout facts: verified main merges publish a public Ad Hoc Release automatically; real macOS 13 Accessibility and physical-key checks are retained as post-release evidence.

## Coverage / rollout summary

- The multi-player implementation is assembled from the fixed macOS 13 baseline. Local app compilation and XCTest have passed; physical media-key checks remain environment-dependent. Spotifly requires macOS 26.2+ for real-device validation.
- Sonora's tray-only activation policy is treated as a launchable input state.
  The next media key reopens and activates Sonora's main window, waits for its
  PID keyboard input surface, and dispatches the captured gesture once.
- Advanced Settings persists Automatic or custom locations for Fastpotify,
  Sonora, and Spotifly. Fastpotify accepts an app bundle or CLI; Sonora and
  Spotifly validate the selected bundle identifier. Invalid saved locations
  remain unavailable and expose a settings action rather than falling back.
- Accessibility checks are silent at startup. The system prompt is deferred
  until an explicit active-mode selection or a menu media-control click.
- Demo mode uses an ephemeral defaults object, neutral display paths, and no
  player/runtime side effects. Its healthy baseline represents Sonora running,
  all three supported players discoverable, and Accessibility authorized. The
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
- The Icon Composer `tinted` specialization uses the dedicated white
  `spotibind-icon-mono.svg` foreground so Clear and Tinted dark styles retain
  contrast; the original black `spotibind-logo-monochrome.svg` remains an
  independent logo asset and is not used as an application-icon source.
- Current visual evidence is scoped to live SpotiBind windows only and covers
  the menu panel plus normal and Accessibility-guidance settings states.

## Remaining Gaps

- Real macOS 13 Fastpotify/Sonora and macOS 26.2+ Spotifly physical-key validation requires access to matching hardware and installed applications.
- Apple's public `MenuBarExtra` API still has no presentation action; the Demo
  capture path uses the app-owned real status-bar window and public AppKit
  `performClick` to open the host, then fails closed after a bounded wait.
  The four healthy evidence PNGs are committed below; the pre-existing
  `menu-popover.png` remains a legacy asset and is not counted.

## Related Changes

- The multi-player routing and adapter boundary are defined by ADR-0008; record PR, commit, review, and compatibility references here after delivery.

## References

- `./SPEC.md`
- `./HISTORY.md`
