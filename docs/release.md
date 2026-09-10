# Release

## Build

1. Add exactly one `type:*` label and `channel:stable` to the same-repository PR. New PRs receive `type:patch` and `channel:stable` automatically.
2. Run `scripts/macos/test.sh` with a full Xcode developer toolchain.
3. Use Xcode 26.4+ and run `scripts/macos/compile-icon-resources.sh`.
4. Run `scripts/macos/package.sh` and `scripts/macos/verify-release.sh`.
5. Confirm `lipo -archs` reports both `arm64` and `x86_64`, the bundle
   identifier is `cc.ivanli.spotibind`, `CFBundleIconName` is `SpotiBind`,
   `Assets.car`, `SpotiBind.icns`, and `StatusBarMark.svg` are present, and
   the signature is Ad Hoc.

After all required PR checks pass, `Prepare release version` creates a
GitHub-verified `VERSION`-only commit on the PR branch. Merging that PR to
`main` runs the `Release` workflow, verifies the merge -> preparation -> source
identity, builds the universal Ad Hoc DMG, reserves `vX.Y.Z` for the merge SHA,
and publishes a public GitHub Release with the DMG and `SHA256SUMS`.

`type:none` is the explicit non-product exception and produces no release. Its
final same-repository PR head must carry the immutable trailers
`Release-Type: type:none`, `Release-Channel: channel:stable`, and
`Release-Mode: no-release` (or `bootstrap`). Release recovery uses
`workflow_dispatch` with the exact merged `commit_sha`; post-merge labels are
not consulted, and a tag or asset belonging to another SHA fails closed. The
failure sidecar records the PR, labels, source/merge SHA, version, tag, assets,
run URL, and this recovery instruction.

## Required real-Mac evidence

Physical media-key checks remain release evidence, but do not block publication
of the verified CI artifact. Run the checklist on macOS 13 for each advertised
architecture after publication:

- grant and revoke Accessibility permission and confirm the menu status;
- confirm Automatic, each manual player mode, and Off persist after relaunch;
- with Fastpotify selected, confirm `now-playing --raw` health and verify
  play/pause, next, and previous each reach Fastpotify exactly once per press;
- with Sonora selected, verify Space, Ctrl-Right, and Ctrl-Left reach Sonora
  by PID; close Sonora to its tray and confirm the next media key reopens and
  activates its main window before reaching Sonora exactly once;
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

Record the machine architecture, macOS version, Fastpotify version, and date in
the release evidence. Keep the Ad Hoc/Gatekeeper caveat in user-facing install
guidance.
