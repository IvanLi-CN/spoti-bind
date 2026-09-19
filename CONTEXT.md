# SpotiBind

SpotiBind is a macOS menu-bar companion that directs hardware media controls to a selected supported desktop player. It owns interception, routing, and delivery reporting; each player owns playback.

## Input and Routing

**Media Key**:
A hardware media-control key gesture whose press and release represent one supported transport intent.
_Avoid_: Hotkey, shortcut

**Supported Player**:
A desktop player with a released input surface that SpotiBind can target for the three supported media-key commands.
_Avoid_: Official app, music service

**Spotify**:
The official Spotify macOS desktop client, represented as a distinct Supported Player from Spotifly.
_Avoid_: Official Spotify app, Spotifly

**Forwarding**:
The choice to consume a supported Media Key and request its matching command from the selected player adapter.
_Avoid_: Synchronization, media control

**Forwarding Readiness**:
The state in which a non-Off Player Mode resolves to a usable target and Accessibility is authorized before an event is consumed.
_Avoid_: Connected, installed

**Pass-through**:
Leaving a Media Key unconsumed so macOS performs its normal media-key routing.
_Avoid_: Fallback command, replay

**Tap Quarantine**:
The input-safety state entered after macOS disables the event tap, in which SpotiBind retains the selected Player Mode but leaves every input unconsumed until Accessibility has been revoked and granted again.
_Avoid_: Off mode, tap retry

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

**Launch-at-Login Preference**:
The user's choice to have SpotiBind start after the current macOS user logs in.
_Avoid_: Boot startup, system daemon, background service

**Ad Hoc Build**:
A macOS application build signed without a Developer ID identity and therefore not notarized or attributable to a verified publisher.
_Avoid_: Notarized release, App Store build

**Menu Bar Extra**:
The app's only visible application scene, providing forwarding status and commands from the macOS menu bar.
_Avoid_: Preferences window, background-only daemon

**Draft Release**:
A GitHub Release created from a version tag with its universal Ad Hoc DMG and checksum attached, but held unpublished until the real-Mac release checklist and distribution-consistency checks pass.
_Avoid_: Automatic publication, updater channel

**Release Identity**:
The immutable tuple connecting one verified main merge, one numeric version and tag, and the exact universal DMG plus its checksum.
_Avoid_: Current version, latest build, release label

**Same-repository Homebrew Cask**:
The Homebrew Cask under the same repository's `Casks/` tree that points to the public Release asset for the same Release Identity.
_Avoid_: Separate tap version, livecheck result

**Cask Sync PR**:
A non-product pull request whose only product-facing change is aligning the same-repository Homebrew Cask with one Release Identity; it does not allocate a version or create a product Release.
_Avoid_: Release PR, version bump PR

**Distribution Consistency Gap**:
The state in which the public GitHub Release and same-repository Homebrew Cask identify different versions or different release assets.
_Avoid_: Homebrew upgrade bug, Release Authorization

**Compatibility Baseline**:
The lowest macOS version the V1 app and its core package promise to support: macOS 13.0.
_Avoid_: Build-host version, latest-only target

**Application Icon**:
The layered Default, Dark, and Mono SpotiBind mark used as the macOS application identity, with system-provided presentation applied by the platform.
_Avoid_: Status Bar Template Mark, baked screenshot

**Status Bar Template Mark**:
The transparent monochrome mark used by the menu-bar extra so macOS can tint it for the current menu-bar appearance.
_Avoid_: Application Icon, colored app tile

**Bundle Assembly**:
The product boundary that combines executable, metadata, application resources, and runtime template assets into the signed `.app`.
_Avoid_: SwiftPM build graph, source compilation

**Settings Presentation Mode**:
The visible application state represented by a regular app when retained Advanced Settings is open and an accessory app during normal menu-bar operation.
_Avoid_: Window size, player mode

**Duplicate Launch Request**:
A Launch Services request for the SpotiBind Application Identity received while its existing process is still alive; it does not represent permission to create a second process.
_Avoid_: Second instance, restart

**Settings Handoff**:
The existing SpotiBind instance's response to a Duplicate Launch Request: reuse the retained Advanced Settings window and bring it to the foreground.
_Avoid_: New settings window, process handoff
