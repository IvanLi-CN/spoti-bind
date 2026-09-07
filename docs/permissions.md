# Permissions and Safety

## Accessibility

The app checks Accessibility authorization with the public
`AXIsProcessTrustedWithOptions` API. Startup checks are silent. The first
explicit active-mode selection or menu media-control click may ask macOS to
show its standard prompt; later checks are silent. The menu and Advanced
Settings window expose a direct link to System Settings > Privacy & Security >
Accessibility.

Without authorization, or while forwarding is Off or has no usable target, no
event tap is installed and all media keys remain normal system events. Revoking
authorization while the app is running is handled by the periodic status
refresh; forwarding becomes unready, the existing tap is removed, and it is not
re-created until access and a usable target are restored.

## What the app does not request

- No root or administrator privileges
- No System Extension or privileged helper
- No App Sandbox entitlement
- No Apple Events/Automation permission
- No private MediaRemote or Fastpotify internal socket

The non-sandboxed Ad Hoc boundary is a distribution constraint, not a request
for elevated user privileges. The process is still launched as the logged-in
user and only receives the selected Fastpotify executable and fixed arguments,
or posts ordinary keyboard events to a selected player's existing PID. When
Sonora is tray-resident, the activation-policy check causes `NSWorkspace` to
reopen and activate Sonora before PID delivery; this is the documented
exception to background-only routing and does not inspect its UI.

## Player delivery boundary

Fastpotify delivery uses the documented CLI verbs `play-pause`, `next`, and
`previous`. Sonora and Spotifly delivery uses public Core Graphics
`CGEvent.postToPid` with their released keyboard shortcuts. The app does not
send Apple Events, inspect private media services, run Accessibility UI
scripts, or bring Fastpotify or Spotifly to the foreground. Sonora may come to
the foreground only when it must recreate its main-window input surface.

## Event-tap failures

If macOS disables the tap once, the controller enables it again. A second
failure within the ten-second recovery window disables forwarding visibly and
persists the Off mode. A successful installation resets that window. No
failure path replays a consumed event.
