#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
python3 .github/scripts/test_release_chain.py
python3 check_quality_gates.py
for workflow in label-gate release-preparation release-completion; do
  file=".github/workflows/${workflow}.yml"
  grep -q 'pull_request_target:' "$file"
  grep -q 'branches: \[main\]' "$file"
  grep -q 'ref:.*default_branch' "$file"
  grep -q 'persist-credentials: false' "$file"
done
if grep -R -q 'pulls/.*\/labels' .github/workflows; then
  echo 'GitHub label reads must use the issue labels endpoint' >&2
  exit 1
fi
grep -q 'expectedHeadOid' .github/workflows/release-preparation.yml
grep -q 'createCommitOnBranch' .github/workflows/release-preparation.yml
grep -q 'repositoryNameWithOwner' .github/workflows/release-preparation.yml
grep -q 'additions' .github/workflows/release-preparation.yml
grep -q 'workflow_dispatch:' .github/workflows/release.yml
grep -q 'commit_sha:' .github/workflows/release.yml
grep -q 'gh release create' .github/workflows/release.yml
grep -q -- '--verify-tag' .github/workflows/release.yml
grep -q 'prerelease=false' .github/workflows/release.yml
grep -q 'gh release upload' .github/workflows/release.yml
grep -q 'select-swift6.sh' .github/workflows/release.yml
grep -q 'TARGET_SHA' .github/workflows/release.yml
grep -q 'Resolve merged PR identity' .github/workflows/release.yml
! grep -q 'issues/\${pr_number}/labels' .github/workflows/release.yml
grep -q 'validate-bootstrap' .github/workflows/release.yml
grep -q 'Release-Mode: (bootstrap|no-release)' .github/workflows/release.yml
grep -q 'skip=true' .github/workflows/release.yml
grep -q 'immutable no-release marker' .github/workflows/release.yml
grep -q 'merge-base --is-ancestor' .github/workflows/release.yml
! grep -q 'labels do not match immutable preparation type' .github/workflows/release.yml
grep -A3 'id: provenance' .github/workflows/release.yml | grep -q 'GH_TOKEN: \${{ github.token }}'
grep -q 'allowed_merge_methods' .github/scripts/align-github-release-policy.sh
grep -q 'merge methods do not match declaration' .github/scripts/align-github-release-policy.sh
! grep -q 'preparation version' .github/workflows/release-completion.yml
grep -q 'release-target-sha.txt' .github/workflows/notify-release-failure.yml
grep -q -- "--repo \"\$GITHUB_REPOSITORY\"" .github/workflows/notify-release-failure.yml
! grep -q 'workflow_dispatch:' .github/workflows/notify-release-failure.yml
! grep -q 'smoke_test:' .github/workflows/notify-release-failure.yml
grep -q 'id-token: write' .github/workflows/notify-release-failure.yml
grep -q 'on_gateway_failure: warn' .github/workflows/notify-release-failure.yml
grep -q 'IvanLi-CN/oidrune/.github/workflows/notify.yml@8667553506eef516af0499a77273f2938387dd37' .github/workflows/notify-release-failure.yml
if grep -q -E 'SHOUTRRR_URL|github-workflows/.github/workflows/release-failure-telegram.yml' .github/workflows/notify-release-failure.yml; then
  echo 'retired Telegram/Shoutrrr notifier contract is still present' >&2
  exit 1
fi
echo "release workflow contracts passed"
