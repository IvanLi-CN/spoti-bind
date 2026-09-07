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
- select the installed Fastpotify executable and confirm
  `now-playing --raw` health;
- with another media player in the foreground, verify play/pause, next, and
  previous each reach Fastpotify exactly once per press;
- hold a key and confirm repeats do not issue additional commands;
- disable Fastpotify, disconnect/reconnect the tap, sleep/wake, and confirm
  unready states pass media keys through;
- confirm a command failure is visible and is not replayed.

Record the machine architecture, macOS version, Fastpotify version, and date
in the release checklist attached to the Draft. Do not advertise an
architecture before its macOS 13 physical-key run passes.
