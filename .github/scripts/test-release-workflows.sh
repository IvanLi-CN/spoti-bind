#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
python3 .github/scripts/test_release_chain.py
python3 check_quality_gates.py
for workflow in label-gate release-preparation release-completion; do
  file=".github/workflows/${workflow}.yml"
  grep -q 'pull_request_target:' "$file"
  grep -q 'ref:.*default_branch' "$file"
  grep -q 'persist-credentials: false' "$file"
done
grep -q 'expectedHeadOid' .github/workflows/release-preparation.yml
grep -q 'createCommitOnBranch' .github/workflows/release-preparation.yml
grep -q 'repositoryNameWithOwner' .github/workflows/release-preparation.yml
grep -q 'additions' .github/workflows/release-preparation.yml
grep -q 'workflow_dispatch:' .github/workflows/release.yml
grep -q 'commit_sha:' .github/workflows/release.yml
grep -q 'gh release create' .github/workflows/release.yml
grep -q 'gh release upload' .github/workflows/release.yml
echo "release workflow contracts passed"
