# Use player adapters and public PID-directed key routing

The multi-player forwarding feature keeps one routing contract in SpotiBind and
delegates delivery through adapters. Fastpotify remains a fixed,
direct CLI integration. Spotify, Spotifly, and Sonora receive ordinary
keyboard events posted to the already-running application PID with the public
Core Graphics `CGEvent.postToPid` API. The app never changes those upstream
projects.

This decision supersedes ADR-0001's single-player integration boundary for the
player-selection and delivery scope. Its public event-tap and Fastpotify CLI
principles remain compatible and are retained as historical context.

## Decision Drivers

- The menu must support Automatic, each supported player, and Off with a
  persistent, testable selection contract.
- Automatic mode needs deterministic running-instance ordering and a bounded,
  non-blocking cold-start handoff.
- Spotify, Spotifly, and Sonora do not expose a supported third-party command protocol;
  their documented in-app keyboard shortcuts are the stable public behavior.
- Private MediaRemote APIs, Apple Events, and Accessibility UI scripting would
  add permissions or violate the target boundary. Sonora is the explicit
  exception to background-only routing: its tray state requires reopening and
  activating the main window before its released keyboard shortcuts exist.
- A standalone Fastpotify CLI must remain a direct-control fallback and must
  never be started with no arguments.

## Considered Options

- Keep a Fastpotify-only toggle: rejected because it cannot select or route to
  the additional players.
- Use private MediaRemote or Apple Events: rejected because those APIs either
  violate the integration boundary or require an unnecessary permission.
- Use Accessibility UI scripting: rejected because it depends on foreground
  UI structure and adds a fragile permission path.
- Change or fork the player applications: rejected because delivery must work
  against their released interfaces without upstream modifications.

## Implementation Boundary

Core owns `PlayerMode`, the supported-player list, availability snapshots,
deterministic resolution, keyboard shortcut mappings, generic routing
decisions, and the serial launch coordinator. The AppKit shell owns
`NSWorkspace` discovery and launch, Fastpotify executable probing, and
`CGEvent` construction/posting. A press captures its resolved target before it
is enqueued. A cold-start target is polled for at most ten seconds; the
original press is dispatched once after launch and is never replayed after a
timeout.

## Consequences

The app now requires Accessibility for both event capture and PID-directed
keyboard delivery, but it does not request Automation or private media
permissions. A Sonora media key may bring its main window to the foreground
when the app is tray-resident; Spotify, Fastpotify, and Spotifly retain
background-only routing. macOS 13 remains the baseline for Spotify, Fastpotify,
and Sonora. Spotifly
real-device validation is only advertised on an environment that supports its
current macOS 26.2 requirement. The menu visual evidence must cover only this
app's MenuBarExtra popover.
