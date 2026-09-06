# SpotiBind

SpotiBind is a macOS menu-bar companion that directs hardware media controls to an existing Fastpotify instance. It owns interception, routing, and delivery reporting; Fastpotify owns playback.

## Input and Routing

**Media Key**:
A hardware media-control key gesture whose press and release represent one supported transport intent.
_Avoid_: Hotkey, shortcut

**Forwarding**:
The choice to consume a supported Media Key and request its matching command from the selected player adapter.
_Avoid_: Synchronization, media control

**Forwarding Readiness**:
The state in which a non-Off Player Mode resolves to a usable target and Accessibility is authorized before an event is consumed.
_Avoid_: Connected, installed

**Pass-through**:
Leaving a Media Key unconsumed so macOS performs its normal media-key routing.
_Avoid_: Fallback command, replay

**Dispatch Failure**:
A failure discovered after an event was consumed for forwarding; it is reported to the person using the app but does not cause the original event to be emitted again.
_Avoid_: Retry, pass-through

## Integration and Distribution

**Control Verb**:
One member of the fixed Fastpotify command vocabulary that SpotiBind supports, initially `play-pause`, `next`, or `previous`; other players use their released keyboard shortcuts.
_Avoid_: Arbitrary command, script

**Application Identity**:
The stable macOS bundle identifier `cc.ivanli.spotibind`, used to associate the app with its Accessibility authorization, preferences, and login-item registration.
_Avoid_: Package name, display name

**Ad Hoc Build**:
A macOS application build signed without a Developer ID identity and therefore not notarized or attributable to a verified publisher.
_Avoid_: Notarized release, App Store build

**Menu Bar Extra**:
The app's only visible application scene, providing forwarding status and commands from the macOS menu bar.
_Avoid_: Preferences window, background-only daemon

**Draft Release**:
A GitHub Release created from a version tag with its universal Ad Hoc DMG and checksum attached, but held unpublished until the real-Mac release checklist passes.
_Avoid_: Automatic publication, updater channel

**Compatibility Baseline**:
The lowest macOS version the V1 app and its core package promise to support: macOS 13.0.
_Avoid_: Build-host version, latest-only target
