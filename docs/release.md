# Release Checklist

## Build

1. Update `VERSION` to the numeric `X.Y.Z` value for the tag.
2. Run `scripts/macos/test.sh` with a full Xcode developer toolchain.
3. Run `scripts/macos/package.sh` and `scripts/macos/verify-release.sh`.
4. Confirm `lipo -archs` reports both `arm64` and `x86_64`, the bundle
   identifier is `cc.ivanli.spotibind`, and the signature is Ad Hoc.

Pushing a matching `vX.Y.Z` tag runs the same package/verify commands and
creates a GitHub Draft Release with the DMG and `SHA256SUMS`. The workflow does
not publish the release automatically.

## Required real-Mac evidence

Before publishing a Draft, run the checklist on macOS 13 for each advertised
architecture:

- grant and revoke Accessibility permission and confirm the menu status;
- confirm Automatic, each manual player mode, and Off persist after relaunch;
- with Fastpotify selected, confirm `now-playing --raw` health and verify
  play/pause, next, and previous each reach Fastpotify exactly once per press;
- with Sonora selected, verify Space, Ctrl-Right, and Ctrl-Left reach Sonora
  by PID without changing focus;
- with Spotifly selected, verify Space, Cmd-Right, and Cmd-Left reach Spotifly
  by PID on a macOS 26.2+ environment;
- with no supported player running, confirm Automatic starts the first
  installed launchable player in Fastpotify, Sonora, Spotifly order and sends
  the first key exactly once;
- confirm a ten-second cold-start timeout does not replay the key;
- hold a key and confirm repeats do not issue additional commands;
- disable Fastpotify, disconnect/reconnect the tap, sleep/wake, and confirm
  unready states pass media keys through;
- confirm a command failure is visible and is not replayed;
- select Off and confirm the system media-key route remains available.

Record the machine architecture, macOS version, Fastpotify version, and date
in the release checklist attached to the Draft. Do not advertise an
architecture before its macOS 13 physical-key run passes.
