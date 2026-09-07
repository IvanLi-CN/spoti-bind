# SpotiBind 媒体键转发实现状态

> 当前有效规范仍以 `./SPEC.md` 为准；这里记录实现覆盖、交付进度与 rollout 相关事实，避免这些细节散落到 PR / Git 历史里。

## Current Status

- Implementation: V1 implementation present; real-Mac release validation pending
- Lifecycle: active
- Catalog note: SwiftPM app/core/test targets, an explicit `MenuBarExtra(.menu)` surface, Ad Hoc packaging, CI, and user-facing docs are checked in.
- Product identity: SpotiBind is used for the executable, bundle, release
  artifacts, and public documentation; the Fastpotify CLI integration remains
  unchanged.

## Implementation Coverage

- Requirement coverage: `REQ-FASTPOTIFY-001` through `REQ-FASTPOTIFY-005` are implemented by the Core, App, scripts, workflows, and documentation paths in this repository.
- Verification commands: `swift test`, `scripts/macos/build.sh`, `scripts/macos/package.sh`, and `scripts/macos/verify-release.sh`.
- Rollout facts: releases remain Draft until real macOS 13 Accessibility and physical-key checks pass for each advertised architecture.

## Coverage / rollout summary

- The first implementation slice is assembled from the fixed macOS 13 baseline. Local app compilation and XCTest have passed; physical media-key checks remain environment-dependent.

## Remaining Gaps

- Real macOS 13 arm64 and x86_64 physical-key validation requires access to matching hardware.

## Related Changes

- None. Record PR, commit, review, and compatibility references here; do not add task history to `SPEC.md`.

## References

- `./SPEC.md`
- `./HISTORY.md`
