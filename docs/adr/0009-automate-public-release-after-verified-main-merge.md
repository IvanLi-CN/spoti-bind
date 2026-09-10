# Automate Public Release After a Verified Main Merge

Status: accepted

## Decision

Same-repository pull requests carry an exact release intent using one `type:*`
label and `channel:stable`. A trusted `pull_request_target` gate reads labels
from the GitHub API and checks out only the base branch. After source CI passes,
GitHub's `createCommitOnBranch(expectedHeadOid)` creates or verifies a signed,
`VERSION`-only preparation commit with source, type, channel, and version
trailers. `Release completion` is required before merge.

Only a normal two-parent merge to `main` can publish. The release workflow
validates the merge -> preparation -> source chain, builds and verifies the
existing universal Ad Hoc DMG, reserves `vX.Y.Z` for the exact merge SHA, and
creates or reuses a public GitHub Release with `SHA256SUMS`. Dispatch recovery
accepts the exact merged SHA and cannot retarget an existing tag. `type:none`
is an explicit no-release intent.

## Consequences

The public release is deterministic and auditable without introducing a release
queue or a new version source. Fork pull requests are fail-closed for all write
workflows. Physical media-key validation remains real-environment evidence and
does not block publication of the CI-verified artifact. Remote rulesets and
labels remain separately aligned external state. Release failures are sent
through the SHA-pinned Oidrune OIDC workflow; the caller has no legacy webhook
secret dependency.
