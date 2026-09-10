# Quality Gates

The repository's intended protection policy is deliberately small for a solo-maintained project.

- Changes to `main` arrive through pull requests.
- `PR / Swift tests` and `PR / Build app` are the only required checks. Swift
  tests run on `macos-15`; the app build runs on `macos-26` so Xcode 26.4+ can
  compile the Icon Composer resource target through the checked-in packaging
  scripts.
- Commits must be verified cryptographically by GitHub and include a DCO signoff.
- No review-count requirement is imposed initially, so the maintainer can merge their own pull requests.
- Version tags matching `vX.Y.Z` create a Draft Release; no workflow publishes a release automatically.

The GitHub repository currently has no branch rule or ruleset. Applying this policy to GitHub is an external change and remains a separate, explicitly authorized step after the workflows exist.
