# SpotiBind 媒体键转发实现状态

> 当前有效规范仍以 `./SPEC.md` 为准；这里记录实现覆盖、交付进度与 rollout 相关事实，避免这些细节散落到 PR / Git 历史里。

## Current Status

- Implementation: multi-player routing implementation present; real-Mac release validation pending
- Lifecycle: active
- Catalog note: SwiftPM app/core/test targets, an explicit `MenuBarExtra(.menu)` surface, Ad Hoc packaging, CI, and user-facing docs are checked in.
- Product identity: SpotiBind is used for the executable, bundle, release
  artifacts, and public documentation; the Fastpotify CLI integration remains
  unchanged.

## Implementation Coverage

- Requirement coverage: `REQ-FASTPOTIFY-001` through `REQ-FASTPOTIFY-006` are implemented by the Core, App, scripts, workflows, and documentation paths in this repository.
- Verification commands: `swift test`, `scripts/macos/build.sh`, `scripts/macos/package.sh`, and `scripts/macos/verify-release.sh`.
- Rollout facts: releases remain Draft until real macOS 13 Accessibility and physical-key checks pass for each advertised architecture.

## Coverage / rollout summary

- The multi-player implementation is assembled from the fixed macOS 13 baseline. Local app compilation and XCTest have passed; physical media-key checks remain environment-dependent. Spotifly requires macOS 26.2+ for real-device validation.
- Sonora's tray-only activation policy is treated as a launchable input state.
  The next media key reopens and activates Sonora's main window, waits for its
  PID keyboard input surface, and dispatches the captured gesture once.

## Remaining Gaps

- Real macOS 13 Fastpotify/Sonora and macOS 26.2+ Spotifly physical-key validation requires access to matching hardware and installed applications.

## Related Changes

- The multi-player routing and adapter boundary are defined by ADR-0008; record PR, commit, review, and compatibility references here after delivery.

## References

- `./SPEC.md`
- `./HISTORY.md`
