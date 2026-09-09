# Quality Gates

The repository's intended protection policy is deliberately small for a solo-maintained project.

- Changes to `main` arrive through pull requests.
- `PR / Swift tests`, `PR / Build app`, `Label Gate`, and `Release completion` are required checks.
- Commits must be verified cryptographically by GitHub and include a DCO signoff.
- No review-count requirement is imposed initially, so the maintainer can merge their own pull requests.
- A same-repository PR defaults to `type:patch` and `channel:stable`; merging a verified preparation commit to `main` automatically publishes the public `vX.Y.Z` Release.

The GitHub repository's branch ruleset, labels, and notifier secret are remote state. They are aligned idempotently with `gh` after PR review and checked against this declaration; this repository change does not silently mutate remote policy.
