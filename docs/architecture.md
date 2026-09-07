# Architecture

SpotiBind is split into a testable Swift package core and a thin native
menu-bar executable.

```text
CGEvent.tapCreate (public event tap)
        |
        v
NSEvent systemDefined decoder -> RoutingPolicy -> pass-through / consume / dispatch(MediaKey)
                                                        |
                                                        v
                                      PlayerSelectionResolver + launch queue
                                      /                    |                  \
                                     /                     |                   \
                 Fastpotify CLI dispatcher       Sonora CGEvent PID       Spotifly CGEvent PID
```

## Core boundary

`SpotiBindCore` has no AppKit or SwiftUI dependency. It owns:

- `SystemDefinedMediaKeyDecoder`, which recognizes NX key types 16, 17, and 18
  and distinguishes press, release, and repeat payloads.
- `PlayerMode`, `PlayerAvailabilitySnapshot`, and `PlayerSelectionResolver`,
  which implement persistent modes and deterministic Automatic ordering.
- `ForwardingReadiness` and `RoutingPolicy`, which require a selected target,
  Accessibility authorization, and a non-Off mode before consuming an event.
- `FastpotifyExecutableLocator`, which gives a user-selected app/executable
  precedence over a short list of known paths.
- `FastpotifyCommandDispatcher`, an actor that serializes commands and probes
  `now-playing --raw` through a `FastpotifyProcessRunner` interface.
- `PlayerDispatch` and `PlayerLaunchCoordinator`, which map media keys to the
  three adapter contracts and serialize asynchronous cold-start handoffs.
- `TapFailureTracker`, which makes the event-tap recovery rule deterministic
  and unit-testable.

The process interface accepts a URL and argument array, never a shell command.
This prevents shell expansion and keeps the integration limited to Fastpotify's
documented CLI verbs.

## App boundary

The executable target owns only platform lifecycle:

- `MenuBarExtra(.menu)` renders the status and V1 controls.
- `AppState` polls Accessibility, installed/running player availability, and
  Fastpotify health, persisting the Player Mode, login-item, and legacy
  Fastpotify path override.
- `ApplicationDelegate` sets the accessory activation policy and starts/stops
  the tap.
- `MediaKeyTapController` installs the public session event tap after
  Accessibility authorization. The callback returns the original event for
  pass-through or `nil` for a consumed event. It filters the exact
  `systemDefined` event type before decoding; mouse, keyboard, and all other
  event types are always returned unchanged.
- `SystemPlayerRuntime` discovers and starts application bundles with
  `NSWorkspace`, sends Space/arrow shortcuts to the selected PID through
  `CGEvent.postToPid`, and never activates the target application.
- `SystemProcessRunner` bridges Foundation `Process` callbacks into the Core
  process-runner protocol and applies the two-second timeout.

The callback runs synchronously because Core Graphics requires a synchronous
return value. Dispatch and cold-start work is scheduled only after the policy
has decided to consume a press, so the callback never waits for a process or
application launch.

## Availability baseline

The package declares macOS 13.0 and Swift language mode 6. SwiftUI's
`MenuBarExtra`, `SMAppService.mainApp`, Accessibility checks, and
`CGEvent.tapCreate` are all public APIs available at that baseline. macOS 14
does not provide a required replacement for this V1 path; the implementation
therefore avoids macOS 14-only Observation APIs and keeps `ObservableObject`
state compatible with Ventura.
