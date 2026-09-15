# Quarantine the media event tap after any system disable

When Core Graphics disables SpotiBind's active media event tap, the app removes it immediately and retains the selected Player Mode rather than retrying the tap or persisting Off mode. The tap returns only after Accessibility monitoring has observed a complete untrusted-to-trusted transition, because preserving ordinary system input is more important than recovering media-key forwarding from an ambiguous system disable.

## Considered Options

- Retry once, then persist Off: recovers transient tap failures but can reintroduce an active tap after Accessibility was revoked and discards the person's routing choice.
- Quarantine until an Accessibility revocation and restoration: delays forwarding recovery but fails open for all system input and preserves the selected player.
