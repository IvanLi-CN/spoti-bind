# Use Icon Composer only for native application icon resources

SpotiBind keeps Swift Package Manager as the source, test, and application-code
build entry point. The only Xcode target is a resource-only target that compiles
the checked-in `packaging/macos/IconResources/SpotiBind.icon` document. Icon
Composer owns the Default, Dark, and Mono application icon renditions and the
same source produces the macOS 13 fallback resource. The shared bundle assembler
copies those outputs and the independent transparent status-bar template into
the app before signing.

## Decision Drivers

- macOS application icons need a native layered resource pipeline so the system
  can apply its own corner, shadow, glass, and appearance treatment.
- The product keeps a macOS 13 deployment baseline and therefore needs a
  fallback resource generated from the same source.
- Menu-bar template artwork has different semantics from a Dock/Finder icon and
  must remain an independent transparent monochrome asset.
- SwiftPM's code and XCTest graph must remain stable and reviewable.

## Consequences

Packaging and release runners require Xcode 26.4+ and use `macos-26`; Swift
test jobs continue to use `macos-15`. `scripts/macos/assemble-app.sh` is the
single bundle assembly path for package, run, and UI capture workflows. The app
declares only `CFBundleIconName=SpotiBind`; hand-authored `.icns` metadata does
not override Icon Composer. A missing template resource is handled at runtime
with a `waveform` fallback.

This ADR supersedes the resource/compiler portion of ADR-0006. ADR-0006's
SwiftPM code, test, and deployment-target decisions remain in force.
