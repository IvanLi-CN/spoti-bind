# Gate Public Release on the Same-repository Homebrew Cask

Status: accepted

## Context

SpotiBind publishes a universal Ad Hoc DMG through GitHub Releases and exposes
the same download through `Casks/spotibind.rb`. The Cask version and checksum
can otherwise lag behind the public Release because Homebrew compares installed
versions with the Cask declaration; `livecheck` discovery does not update the
Cask or make `brew outdated` use the discovered version.

The public Release and same-repository Cask are therefore one distribution
surface. A Release is not complete while their version, URL, and checksum
identify different assets.

## Decision

Use a single-build, Draft-first release contract:

1. The verified main merge builds and verifies one DMG and `SHA256SUMS`, then
   creates or reuses a Draft GitHub Release for the immutable tag and merge
   SHA.
2. Release automation reads that exact asset and creates a Cask-only PR from
   the same repository. The PR is `type:none`, `channel:stable`, carries an
   immutable no-release marker, and changes only `Casks/spotibind.rb`.
3. The Cask PR uses the existing protected PR checks and GitHub auto-merge. A
   `GITHUB_TOKEN` cannot trigger a new `pull_request` workflow, so the sync
   workflow explicitly dispatches the PR, label, and release-completion checks
   against the Cask branch and waits for their exact job results before
   enabling auto-merge. A finalizer verifies the merged Cask's version,
   canonical release URL, and checksum against the exact Draft assets before
   making the Draft public.
4. A failed sync or finalization keeps the Draft unpublished and recovers the
   same merge SHA, tag, asset set, and Cask identity. It never rebuilds the
   artifact or allocates a successor version.

The existing `v0.2.6` gap is repaired by a Cask-only backfill using the already
published DMG checksum. It does not change `VERSION`, tags, or Release assets.

## Considered Options

- Publish first and update the Cask asynchronously: rejected because it leaves
  a public Distribution Consistency Gap and reproduces the observed upgrade
  failure.
- Rebuild the DMG after the Cask PR: rejected because the checksum would no
  longer prove the asset that was initially reviewed and staged.
- Write the Cask directly to `main`: rejected because it bypasses the existing
  PR-only, signed-commit, DCO, and required-check contract.

## Consequences

- GitHub Release publication becomes an asynchronous Draft-to-Cask-to-public
  state transition, but every transition is keyed by one immutable Release
  Identity.
- Required checks keep a non-canceling per-PR concurrency policy; explicit
  dispatch is only the bot-created Cask PR path and still runs the same
  workflow jobs and branch protection contexts.
- `Cask release sync` and `Finalize Cask release` become expected-success
  workflows and must carry release identity in failure notifications.
- `Casks/spotibind.rb` is part of the release contract, not optional packaging
  metadata.
