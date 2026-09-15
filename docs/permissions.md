# Permissions and Safety

## Accessibility

The app checks Accessibility authorization with the public
`AXIsProcessTrustedWithOptions` API. Startup checks are silent. An explicit
active-mode selection or menu media-control click may ask macOS to show its
standard prompt; opening the Accessibility settings link never prompts. A
silent trust monitor runs once per second in the main run loop's common modes,
so it observes both revocation and restoration while menu tracking is active.
The menu and Advanced Settings window expose a direct link to System Settings
> Privacy & Security > Accessibility.

Without authorization, or while forwarding is Off or has no usable target, no
event tap is installed and all media keys remain normal system events. Revoking
authorization while the app is running makes forwarding unready and removes the
existing tap. When Core Graphics disables the tap for any reason, SpotiBind
enters Tap Quarantine: it keeps the Player Mode but does not retry the active
tap. Reinstallation requires the trust monitor to observe revocation and a
later restoration. The synchronous tap callback only reads cached readiness;
it does not make an Accessibility query on the system input path.

## What the app does not request

- No root or administrator privileges
- No System Extension or privileged helper
- No App Sandbox entitlement
- No Apple Events/Automation permission
- No private MediaRemote or Fastpotify internal socket

The non-sandboxed Ad Hoc boundary is a distribution constraint, not a request
for elevated user privileges. The process is still launched as the logged-in
user and only receives the selected Fastpotify executable and fixed arguments,
or posts ordinary keyboard events to a selected player's existing PID. The
standalone Fastpotify CLI is permission-independent; invoking that standalone
tool does not require this app's authorization. SpotiBind's own global capture
and menu dispatch remain gated by Accessibility, including when Fastpotify is
the selected target. This is an app-boundary statement, not a claim about
unrelated system permissions. When Sonora is
tray-resident, the
activation-policy check causes `NSWorkspace` to reopen and activate Sonora
before PID delivery; this is the documented exception to background-only
routing and does not inspect its UI.

## Player delivery boundary

Fastpotify delivery uses the documented CLI verbs `play-pause`, `next`, and
`previous`. Sonora and Spotifly delivery uses public Core Graphics
`CGEvent.postToPid` with their released keyboard shortcuts. Apple's public
`CGEvent.postToPid` contract does not declare a TCC prerequisite; SpotiBind's
separate Accessibility gate protects its global event-tap capture and tap
lifecycle. This documentation does not infer a runtime TCC result that was not
tested here. The app does not send Apple Events, inspect private media services,
run Accessibility UI scripts, or bring Fastpotify or Spotifly to the
foreground. Sonora may come to the foreground only when it must recreate its
main-window input surface.

## Event-tap failures

If macOS disables the tap, the controller disables and invalidates it without
retrying or changing the selected Player Mode. The app emits a Unified Logging
event for the quarantine and for every trust or tap lifecycle transition; it
does not log raw input data. No failure path replays a consumed event.
