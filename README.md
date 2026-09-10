# SpotiBind

SpotiBind is a small macOS menu-bar companion that routes the standard
play/pause, next, and previous media keys to Fastpotify, Sonora, or Spotifly.
The menu persists an Automatic, player-specific, or Off choice. Automatic uses
running players in Fastpotify, Sonora, Spotifly order and otherwise starts the
first installed launchable player. If permission or a usable target is
missing, macOS keeps its normal media-key behavior. The menu-bar panel also
exposes previous, play/pause, and next controls, while Advanced Settings
provides per-player location overrides and system controls.

When selected Sonora is resident only in the menu bar, its next media key
reopens and activates the Sonora main window, then performs that command once.

## Requirements

- macOS 13.0 or later
- Fastpotify 0.4.1 or later when Fastpotify is selected or installed for
  Automatic mode
- Sonora when Sonora is selected or installed for Automatic mode
- Spotifly on macOS 26.2 or later when Spotifly is selected or installed for
  Automatic mode
- Accessibility permission for SpotiBind

SpotiBind does not require an administrator password, root access, a
System Extension, or an Automation permission. It is intentionally a
non-sandboxed Ad Hoc app because public event taps and launching the separately
installed CLI need those boundaries.

## Install

Download the universal DMG from the GitHub Draft Release, open it, and move
`SpotiBind.app` to `/Applications`. The first launch may require opening
the app from Finder's context menu because an Ad Hoc build is not notarized.
Then open the menu-bar item, choose an active forwarding mode, or use a media
control to trigger the Accessibility prompt.

The release remains a Draft until the macOS 13 arm64 and x86_64 physical-key
checklist has passed. A Draft artifact is for testing, not a claim of complete
release compatibility.

## Behavior

| Player | Play/pause | Next | Previous |
| --- | --- | --- | --- |
| Fastpotify | `fastpotify play-pause` | `fastpotify next` | `fastpotify previous` |
| Sonora | Space | Ctrl-Right | Ctrl-Left |
| Spotifly | Space | Cmd-Right | Cmd-Left |

One command is sent for each press. Repeated events during one hold and the
release event are consumed without sending another command. A command failure
is shown in the menu and is never replayed to another player.

The menu provides the current readiness status, a single-choice target picker,
media controls, a direct issue action, and links to Advanced Settings, About,
and Quit. A cold start waits asynchronously for up to ten seconds and sends
the initiating key once; a timeout never replays it. Accessibility prompting
is deferred until the user enables an active forwarding mode or clicks a
media control. Advanced Settings persists an automatic or custom location for
each player. The legacy `targetPath` preference remains compatible for
Fastpotify until the user explicitly resets its location; Sonora and Spotifly
use their configured application bundles or their fixed bundle identifiers.

## Build and test

SwiftPM remains the only entry point for application code, Core, and XCTest.
The checked-in Icon Composer resource target is the one Xcode exception and
only compiles the native application icon:

```sh
scripts/macos/build.sh
scripts/macos/test.sh
scripts/macos/run.sh
```

Swift tests use a complete Xcode developer toolchain. App packaging additionally
requires Xcode 26.4+ because `scripts/macos/compile-icon-resources.sh` invokes
Icon Composer and the resource-only Xcode target. The SwiftPM app target still
contains all application code, and `scripts/macos/assemble-app.sh` is the
single bundle assembly path used by local runs, captures, and releases.

To produce a local release artifact:

```sh
scripts/macos/package.sh
scripts/macos/verify-release.sh
```

The package script builds `arm64-apple-macosx13.0` and
`x86_64-apple-macosx13.0`, merges the executable with `lipo`, signs the app
with an Ad Hoc identity, creates a compressed DMG, and writes `dist/SHA256SUMS`.

## Architecture

- `SpotiBindCore` contains decoding, player selection, readiness-gated
  routing, shortcut mappings, executable location, and serial launch/dispatch
  coordinators.
- `SpotiBind` contains the SwiftUI `MenuBarExtra`, NSWorkspace discovery
  and launch, PID-directed Core Graphics shortcuts, Accessibility/login item
  lifecycle, and the event-tap bridge.
- `Tests/SpotiBindCoreTests` covers the Core contract with XCTest and
  injected process/player runtimes.

The tap callback performs only synchronous decoding and routing. It never
waits for or launches a process; the actor-backed dispatcher owns the serial
CLI work and its two-second timeout.

See [docs/architecture.md](docs/architecture.md),
[docs/permissions.md](docs/permissions.md),
[docs/testing.md](docs/testing.md), and
[docs/release.md](docs/release.md) for the operational details.

SpotiBind is an independent project and is not affiliated with or endorsed by Spotify.

## License

MIT. See [LICENSE](LICENSE).
