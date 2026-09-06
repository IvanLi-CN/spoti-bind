# SpotiBind

SpotiBind is a small macOS menu-bar companion that routes the standard
play/pause, next, and previous media keys to a running Fastpotify instance.
When the app is ready, it consumes those three system-defined events even when
another media player is in the foreground. If permission, the executable, or
the health probe is missing, macOS keeps its normal media-key behavior.

## Requirements

- macOS 13.0 or later
- Fastpotify 0.4.1 or later
- Fastpotify's `fastpotify` executable, either in a known location or selected
  from the app menu
- Accessibility permission for SpotiBind

SpotiBind does not require an administrator password, root access, a
System Extension, or an Automation permission. It is intentionally a
non-sandboxed Ad Hoc app because public event taps and launching the separately
installed CLI need those boundaries.

## Install

Download the universal DMG from the GitHub Draft Release, open it, and move
`SpotiBind.app` to `/Applications`. The first launch may require opening
the app from Finder's context menu because an Ad Hoc build is not notarized.
Then open the menu-bar item and grant Accessibility access when prompted.

The release remains a Draft until the macOS 13 arm64 and x86_64 physical-key
checklist has passed. A Draft artifact is for testing, not a claim of complete
release compatibility.

## Behavior

| Media key gesture | Fastpotify command |
| --- | --- |
| Play/pause press | `fastpotify play-pause` |
| Next press | `fastpotify next` |
| Previous press | `fastpotify previous` |

One command is sent for each press. Repeated events during one hold and the
release event are consumed without sending another command. A command failure
is shown in the menu and is never replayed to another player.

The menu provides the current readiness status, a forwarding toggle, target
selection, an Accessibility settings link, and an opt-in Launch at Login
toggle. The target must answer `fastpotify now-playing --raw` successfully
before media keys are consumed.

## Build and test

The repository has one Swift Package Manager entry point and does not require
an `.xcodeproj`:

```sh
scripts/macos/build.sh
scripts/macos/test.sh
scripts/macos/run.sh
```

Command Line Tools are enough to compile the app and perform the Ad Hoc
bundle/signing steps. XCTest requires a complete Xcode developer-toolchain (as
provided by CI); the app target itself remains SwiftPM-only.

To produce a local release artifact:

```sh
scripts/macos/package.sh
scripts/macos/verify-release.sh
```

The package script builds `arm64-apple-macosx13.0` and
`x86_64-apple-macosx13.0`, merges the executable with `lipo`, signs the app
with an Ad Hoc identity, creates a compressed DMG, and writes `dist/SHA256SUMS`.

## Architecture

- `SpotiBindCore` contains decoding, readiness-gated routing, executable
  location, and a serial direct-process dispatcher.
- `SpotiBind` contains the SwiftUI `MenuBarExtra`, Accessibility/login
  item lifecycle, and the Core Graphics event-tap bridge.
- `Tests/SpotiBindCoreTests` covers the Core contract with XCTest and an
  injected process runner.

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
