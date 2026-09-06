# Use public event capture and Fastpotify CLI integration

SpotiBind captures media-key events with the public Swift `CGEvent.tapCreate` API after Accessibility authorization and sends documented Fastpotify CLI control verbs as process arguments. It supports Fastpotify `0.4.1` and later, the earliest verified release with the required CLI contract. It deliberately avoids private `MediaRemote` APIs, Apple Events, and Fastpotify's internal loopback socket, so the app can consume keys without depending on private platform or Fastpotify implementation details.

## Considered Options

- `NSEvent` global monitoring cannot reliably consume the system event.
- `MPRemoteCommandCenter` is the current public API for an app that is itself a Now Playing owner, but it cannot reserve commands for a companion app while another player owns Now Playing.
- Fastpotify's loopback socket is an internal implementation detail rather than a supported integration contract.
- Apple Events would add an Automation permission and target the wrong integration boundary.

## Implementation Boundary

The tap listens for AppKit's public `NSEvent.EventType.systemDefined` event type. Its decoder recognizes only the documented IOKit auxiliary-control key values for play/pause, next, and previous. The event payload has no dedicated high-level public media-key model, so its small decoding boundary is isolated, unit-tested, and passes through unrecognized payloads. The tap callback never launches or waits for a process.
