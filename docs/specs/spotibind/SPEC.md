# SpotiBind 媒体键转发

> This file is the durable topic requirements contract. Current implementation facts belong in `IMPLEMENTATION.md`; lifecycle and change references belong in `HISTORY.md`.

## Context and Scope

- Context: macOS hardware media keys normally follow the system's current Now Playing owner, while SpotiBind must direct supported transport commands to one selected supported player.
- In scope: public event capture, persistent player selection, deterministic automatic discovery, Fastpotify CLI control, PID-directed Spotifly/Sonora shortcuts, Sonora main-window reopening when required for its input surface, Accessibility status, menu-bar control, and Ad Hoc universal distribution.
- Out of scope: playback ownership inside any player, private MediaRemote APIs, Apple Events, Accessibility UI scripting, upstream player changes, and unrelated distribution channels.

## Terms and Interfaces

- `Media Key`: A hardware media-control gesture whose press and release represent one supported transport intent.
- `Player Mode`: One of Automatic, Fastpotify, Sonora, Spotifly, or Off; the value is persisted in `UserDefaults`.
- `Player Availability Snapshot`: An injected, testable view of whether each supported player is installed, running, launchable, or must be reopened before dispatch.
- `Player Input Surface`: The public input surface required by a PID keyboard adapter. Sonora's on-screen main window provides that surface; a tray-resident instance must be reopened before it can receive the adapter shortcut.
- `Player Selection`: The target resolved from the current mode and availability snapshot. Automatic prefers running players in `Fastpotify`, `Sonora`, `Spotifly` order, then the first launchable installed player in that order.
- `Forwarding Readiness`: The cached state where a non-Off mode is selected, Accessibility is authorized, and the resolver has a usable target.
- `Pass-through`: Leaving the original event unconsumed so macOS performs normal routing.
- Interfaces: Fastpotify CLI verbs `play-pause`, `next`, `previous`, and probe `now-playing --raw`; Spotifly PID shortcuts Space, Cmd-Right, Cmd-Left; Sonora PID shortcuts Space, Ctrl-Right, Ctrl-Left.

## Requirements

### REQ-FASTPOTIFY-001

- The system MUST capture only supported standard `systemDefined` media-key events through the public Core Graphics event-tap API after Accessibility authorization.
- Inputs: play/pause, next, previous press/release payloads and unknown system-defined payloads.
- Outputs: a decoded supported command or an unchanged event for pass-through.

### REQ-FASTPOTIFY-002

- The system MUST persist one Player Mode and consume a supported key only when Accessibility is authorized and that mode resolves to a usable target; Off and unresolved modes MUST pass the event through.
- Automatic mode MUST prefer running targets in `Fastpotify`, `Sonora`, `Spotifly` order, then launch the first installed launchable target in that order. A tray-resident Sonora counts as running for this ordering but resolves to a reopen handoff. A standalone Fastpotify CLI MUST NOT be launched without an application bundle.
- A player MUST be considered running for PID routing only when its adapter has a usable input surface. Sonora running with only its tray icon MUST resolve as a launchable target; the system MUST reopen its main window before consuming and dispatching the media-key gesture.
- Inputs: Player Mode, Accessibility state, and a Player Availability Snapshot.
- Outputs: an exclusive route to the resolved player when ready, normal macOS routing when not ready.

### REQ-FASTPOTIFY-003

- The system MUST execute one player-specific command for each distinct key gesture, ignore repeats within one hold, serialize commands, and never replay an event after dispatch failure.
- Fastpotify MUST use fixed direct CLI arguments. Spotifly MUST receive ordinary keyboard events targeted by PID without activating or focusing the application. Sonora MUST receive ordinary keyboard events targeted by PID; when it is cold or tray-resident, the system MUST launch or reopen and activate Sonora's main window, wait for its input surface, then dispatch the first key exactly once. Sonora MUST NOT be hidden because its released shortcuts require the main window's workspace context.
- Inputs: decoded control keys and the target captured when the press is submitted.
- Outputs: a player dispatch result and user-visible failure state without shell interpretation.

### REQ-FASTPOTIFY-004

- The system MUST expose a single-choice target menu containing Automatic, Fastpotify, Sonora, Spotifly, and Off, plus Accessibility guidance and login-start preference from its menu-bar extra.
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

### REQ-FASTPOTIFY-006

- The system MUST migrate legacy `forwardingEnabled=false` to Off and otherwise default a missing Player Mode to Automatic. A legacy `targetPath` MUST remain a Fastpotify CLI path override only.
- A launch handoff MUST wait asynchronously for at most ten seconds, dispatch the first key once after the target is running, and never replay it after timeout. Later independent gestures MUST remain ordered.

## Verification

### VER-FASTPOTIFY-001

- Method: `PlayerSelectionTests`, `RoutingPolicyTests`, and `MediaKeyDecoderTests` with injected availability snapshots.
- covers: `REQ-FASTPOTIFY-001`, `REQ-FASTPOTIFY-002`
- Pass condition: automatic ordering, manual selection, Off, unknown, and unresolved events match the contract.

### VER-FASTPOTIFY-002

- Method: `PlayerDispatchTests`, `PlayerLaunchCoordinatorTests`, and `FastpotifyIntegrationTests` with injected runtimes.
- covers: `REQ-FASTPOTIFY-003`, `REQ-FASTPOTIFY-006`
- Pass condition: all three adapter mappings, serial delivery, one-time cold-start delivery, timeout behavior, and legacy migration pass.

### VER-FASTPOTIFY-003

- Method: menu interaction on a real app bundle and Accessibility permission cycle.
- covers: `REQ-FASTPOTIFY-004`
- Pass condition: the five single-choice modes, status, Accessibility link, login toggle, and Quit are visible from the menu-bar extra and update their state.

### VER-FASTPOTIFY-004

- Method: SwiftPM target-triple build, `lipo`, Ad Hoc code-sign verification, DMG inspection, and tag workflow dry validation.
- covers: `REQ-FASTPOTIFY-005`
- Pass condition: both slices are present, the bundle verifies, the checksum matches, and the tag workflow creates a Draft Release.

## Related ADRs

- [Use MenuBarExtra with a thin AppKit bridge around a testable Swift core](../../adr/0002-keep-the-appkit-shell-thin.md)
- [Ship V1 outside the App Sandbox with Ad Hoc universal distribution](../../adr/0003-ship-v1-outside-the-app-sandbox-with-ad-hoc-signing.md)
- [Use macOS 13 as the V1 deployment target](../../adr/0005-use-macos-13-as-the-v1-deployment-target.md)
- [Use SwiftPM as the single build entrypoint](../../adr/0006-use-swiftpm-as-the-single-build-entrypoint.md)
- [Rename the pre-release application identity to SpotiBind](../../adr/0007-rename-the-pre-release-application-identity-to-spotibind.md)
- [Use player adapters and public PID-directed key routing](../../adr/0008-use-player-adapters-and-public-pid-key-routing.md)

## Visual Evidence

- Surface: the SpotiBind menu-bar popover only (`target_app_window`).
- Scope: status, the five-mode target picker, Accessibility settings, Launch at
  Login, and Quit controls; no desktop or unrelated menu-bar content.
- Evidence: [menu-popover.png](./assets/menu-popover.png).
- Capture: verified from a live macOS session with owner confirmation; the
  screenshot contains only the target app's popover.

## References

- `./IMPLEMENTATION.md`
- `./HISTORY.md`
