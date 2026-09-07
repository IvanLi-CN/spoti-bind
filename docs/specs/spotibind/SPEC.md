# SpotiBind 媒体键转发

> This file is the durable topic requirements contract. Current implementation facts belong in `IMPLEMENTATION.md`; lifecycle and change references belong in `HISTORY.md`.

## Context and Scope

- Context: macOS hardware media keys normally follow the system's current Now Playing owner, while SpotiBind must direct supported transport commands to a running Fastpotify instance.
- In scope: public event capture, readiness-gated routing, Fastpotify CLI control, Accessibility status, menu-bar control, and Ad Hoc universal distribution.
- Out of scope: playback ownership inside Fastpotify, private MediaRemote APIs, vendor-specific key remapping, and unrelated distribution channels.

## Terms and Interfaces

- `Media Key`: A hardware media-control gesture whose press and release represent one supported transport intent.
- `Forwarding Readiness`: The cached state where forwarding is enabled, Accessibility is authorized, a usable Fastpotify executable is known, and a recent CLI probe succeeded.
- `Pass-through`: Leaving the original event unconsumed so macOS performs normal routing.
- Interface: Fastpotify CLI verbs `play-pause`, `next`, `previous`, and probe `now-playing --raw`.

## Requirements

### REQ-FASTPOTIFY-001

- The system MUST capture only supported standard `systemDefined` media-key events through the public Core Graphics event-tap API after Accessibility authorization.
- Inputs: play/pause, next, previous press/release payloads and unknown system-defined payloads.
- Outputs: a decoded supported command or an unchanged event for pass-through.

### REQ-FASTPOTIFY-002

- The system MUST consume a supported key only when forwarding is enabled and the cached readiness conditions are all true; otherwise it MUST pass the event through.
- Inputs: forwarding toggle, Accessibility state, executable availability, and recent probe result.
- Outputs: an exclusive Fastpotify route when ready, normal macOS routing when not ready.

### REQ-FASTPOTIFY-003

- The system MUST execute one direct Fastpotify CLI command for each distinct key gesture, ignore repeats within one hold, serialize commands, and never replay an event after dispatch failure.
- Inputs: decoded control verbs and a validated executable URL.
- Outputs: process result and user-visible failure state without shell interpretation.

### REQ-FASTPOTIFY-004

- The system MUST expose forwarding readiness, Accessibility guidance, target selection, enablement, and login-start preference from its menu-bar extra.
- Inputs: current service state and user preferences stored in `UserDefaults`.
- Outputs: a single menu-bar control surface with actionable status and settings links.

### REQ-FASTPOTIFY-005

- The project MUST produce a macOS 13+ Ad Hoc universal artifact containing `arm64` and `x86_64` executable slices, a verifiable checksum, and a Draft Release on version tags.
- Inputs: a semantic version tag and two SwiftPM target-triple builds.
- Outputs: signed `.app`, DMG, `SHA256SUMS`, and a non-published GitHub Draft Release.
- Release and pull-request automation MUST select a toolchain whose compiler
  reports Swift 6 before invoking SwiftPM. Selection MUST resolve the compiler
  through the Xcode developer directory (`DEVELOPER_DIR`/`xcrun`), rather than
  assuming a fixed Xcode binary path. The current hosted runner is macOS 15,
  while the product deployment baseline remains macOS 13.

## Verification

### VER-FASTPOTIFY-001

- Method: XCTest fixtures for supported, repeated, and unknown system-defined payloads plus routing policy states.
- covers: `REQ-FASTPOTIFY-001`, `REQ-FASTPOTIFY-002`
- Pass condition: supported ready events are consumed and mapped; unknown or unready events remain pass-through.

### VER-FASTPOTIFY-002

- Method: XCTest with an injected process runner and serial dispatcher.
- covers: `REQ-FASTPOTIFY-003`
- Pass condition: command arguments are direct, gestures are distinct, repeats are ignored, execution is serialized, and failures are not replayed.

### VER-FASTPOTIFY-003

- Method: menu interaction on a real app bundle and Accessibility permission cycle.
- covers: `REQ-FASTPOTIFY-004`
- Pass condition: all status and control actions are visible from the menu-bar extra and update their state.

### VER-FASTPOTIFY-004

- Method: SwiftPM target-triple build, `lipo`, Ad Hoc code-sign verification, DMG inspection, and tag workflow dry validation.
- covers: `REQ-FASTPOTIFY-005`
- Pass condition: both slices are present, the bundle verifies, the checksum matches, and the tag workflow creates a Draft Release.

## Related ADRs

- [Use public event capture and Fastpotify CLI integration](../../adr/0001-use-public-event-capture-and-cli-integration.md)
- [Use MenuBarExtra with a thin AppKit bridge around a testable Swift core](../../adr/0002-keep-the-appkit-shell-thin.md)
- [Ship V1 outside the App Sandbox with Ad Hoc universal distribution](../../adr/0003-ship-v1-outside-the-app-sandbox-with-ad-hoc-signing.md)
- [Use macOS 13 as the V1 deployment target](../../adr/0005-use-macos-13-as-the-v1-deployment-target.md)
- [Use SwiftPM as the single build entrypoint](../../adr/0006-use-swiftpm-as-the-single-build-entrypoint.md)
- [Rename the pre-release application identity to SpotiBind](../../adr/0007-rename-the-pre-release-application-identity-to-spotibind.md)

## Visual Evidence

- Surface: the SpotiBind menu-bar popover only (`target_app_window`).
- Scope: status, forwarding toggle, target selection, Accessibility settings,
  Launch at Login, and Quit controls; no desktop or unrelated menu-bar content.
- Evidence: [menu-popover.png](./assets/menu-popover.png).
- Capture: verified from a live macOS session with owner confirmation; the
  screenshot contains only the target app's popover.

## References

- `./IMPLEMENTATION.md`
- `./HISTORY.md`
