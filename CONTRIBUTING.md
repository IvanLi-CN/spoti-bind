# Contributing

SpotiBind is a SwiftPM-only macOS project. Keep changes inside the
existing package targets and preserve the public API boundary described in
`docs/architecture.md`.

## Local checks

```sh
scripts/macos/test.sh
scripts/macos/build.sh --configuration release
```

Use `scripts/macos/package.sh` when changing bundle metadata, architecture
handling, signing, or release scripts. XCTest needs a complete Xcode
toolchain; Command Line Tools can still build and type-check the app target.

## Pull requests

- Explain the behavior change and its validation evidence.
- Add or update Core XCTest coverage for routing, decoding, and process
  boundaries.
- Keep the PR checks named `PR / Swift tests` and `PR / Build app` passing.
- Do not add private macOS APIs, shell-based command execution, or privileged
  helpers without a new architecture decision.
- Sign commits off with `git commit --signoff`.

The initial repository policy is recorded in
`.github/quality-gates.json`; branch rules are intentionally not changed by
this repository.
