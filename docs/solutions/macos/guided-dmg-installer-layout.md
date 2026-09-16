---
title: Build a guided macOS DMG installer layout
module: macOS packaging
problem_type: release-packaging
component: scripts/macos/package.sh
tags:
  - macos
  - dmg
  - finder
  - release
status: active
related_specs:
  - docs/specs/spotibind/SPEC.md
---

# Guided macOS DMG installer layout

## Context

A DMG that contains only an application bundle opens with a generic Finder
view. A polished installer needs a stable drag-and-drop relationship between
the application and `/Applications`, a clean background, and no packaging
metadata in the user's primary view.

## Symptoms

- Finder reopens the window with icons shifted or arranged automatically.
- The arrow and the two icons look visually misaligned even when the artwork
  itself is centered.
- The application icon is missing on macOS versions that do not consume the
  compiled Icon Composer catalog.
- `.background`, `.fseventsd`, or `.DS_Store` appears in the default icon grid
  when hidden files are enabled.
- A compressed read-only DMG cannot accept the Finder metadata needed for a
  persistent layout.

## Root cause

Finder stores icon positions, view options, and the background reference in
`.DS_Store` on the mounted volume. Creating a compressed DMG directly from a
source folder does not provide a writable volume on which those settings can
be recorded. Finder coordinates also describe the icon view, while the
background artwork has its own pixel coordinate system; centering one does not
automatically center the other.

The modern app icon and the macOS 13 fallback are separate delivery paths.
`CFBundleIconName` and `Assets.car` cover the Icon Composer path, while an
explicit `CFBundleIconFile` pointing to `SpotiBind.icns` keeps the fallback
resource discoverable.

## Resolution

1. Generate the visual background with `cvm-imagegen` using `gpt-image-2`.
   Keep the generated image clean and bright, then add copy and the arrow in a
   deterministic overlay/composition step. Do not rely on the image model to
   place UI labels or align Finder icons. The committed final background is
   `packaging/macos/dmg-background.png`.
2. Stage `SpotiBind.app`, a `/Applications` symbolic link, and
   `.background/background.png` in a temporary directory.
3. Create a writable HFS image (`UDRW`) and attach it read-write. Configure
   Finder's icon view through AppleScript with a fixed window and explicit
   positions:

   - window bounds: `{100, 100, 920, 600}`
   - icon view with no automatic arrangement
   - icon size `128`, label size `14`
   - `SpotiBind.app`: `{170, 300}`
   - `Applications`: `{650, 300}`

   Keep the artwork's arrow centered on the line between those two icon
   centers. The current overlay uses an arrow tip near the midpoint of the
   820-wide Finder content coordinate system.
4. Mark `.background`, `.fseventsd`, and `.DS_Store` hidden with both
   `chflags hidden` and `SetFile -a V`. Assign their icon positions outside the
   normal window area as a second defense for Finder configurations that show
   invisible files. Finder may rewrite `.DS_Store`, so reapply the invisible
   attributes after closing the window.
5. Detach the writable image and convert it to a compressed UDZO image. Keep
   cleanup able to detach the volume if any intermediate command fails.
6. Validate the compressed artifact by mounting it read-only. Check the app,
   background, `.DS_Store`, `/Applications` symlink target, hidden attributes,
   universal slices, signature, and checksum. Separately read back Finder
   positions on a mounted candidate when changing artwork or layout coordinates.

## Guardrails / Reuse notes

- Never try to persist Finder layout directly in a compressed read-only DMG.
- Treat icon positions and background pixels as two related but independent
  coordinate systems; update them together and verify the mounted result.
- Keep generated bitmap artwork deterministic at packaging time: the release
  script should consume a checked-in final PNG, while the image-generation
  workflow remains the design input process.
- Keep hidden metadata outside the default view even though invisible flags
  are set. This protects users who enable hidden-file display in Finder.
- Do not remove quarantine or bypass Finder for release validation. The Ad Hoc
  Gatekeeper behavior is a separate installation concern.
- The local machine may lack Icon Composer and therefore fail before
  `Assets.car` validation. The release gate must run in the full Xcode
  environment; do not weaken the verifier to accommodate an incomplete local
  bundle.

## Verification

Run the repository checks from the project root:

```sh
scripts/macos/test.sh
bash -n scripts/macos/package.sh scripts/macos/verify-release.sh
scripts/macos/package.sh
scripts/macos/verify-release.sh
```

For a visual layout change, mount the resulting DMG and read back the Finder
positions before publishing. The expected primary positions are
`SpotiBind.app = {170, 300}` and `Applications = {650, 300}`.

## References

- `scripts/macos/package.sh`
- `scripts/macos/verify-release.sh`
- `packaging/macos/Info.plist`
- `packaging/macos/dmg-background.png`
- `docs/release.md`
- `docs/testing.md`
- `docs/adr/0003-ship-v1-outside-the-app-sandbox-with-ad-hoc-signing.md`
- `docs/adr/0010-use-icon-composer-for-native-application-icon-resources.md`
