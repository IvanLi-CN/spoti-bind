#!/usr/bin/env bash
set -euo pipefail

# Remote policy is intentionally opt-in: review must authorize the one-time
# ruleset/label alignment independently of this repository change.
mode="${1:-check}"
if [[ "$mode" != check && "$mode" != apply ]]; then
  echo "usage: $0 [check|apply]" >&2
  exit 2
fi
: "${GH_REPO:?set GH_REPO to owner/repository}"

required_labels=(type:patch type:minor type:major type:none channel:stable)
if [[ "$mode" == apply ]]; then
  : "${GH_TOKEN:?set GH_TOKEN for remote alignment}"
  gh label create 'type:patch' --repo "$GH_REPO" --color 1D76DB --description 'Release patch bump (default)' --force
  gh label create 'type:minor' --repo "$GH_REPO" --color 5319E7 --description 'Release minor bump' --force
  gh label create 'type:major' --repo "$GH_REPO" --color B60205 --description 'Release major bump' --force
  gh label create 'type:none' --repo "$GH_REPO" --color C5DEF5 --description 'No product release' --force
  gh label create 'channel:stable' --repo "$GH_REPO" --color 0E8A16 --description 'Public stable release' --force
fi

labels="$(gh label list --repo "$GH_REPO" --limit 200 --json name --jq '[.[].name]')"
for label in "${required_labels[@]}"; do
  jq -e --arg label "$label" 'index($label) != null' <<<"$labels" >/dev/null || {
    echo "missing remote label: $label" >&2
    [[ "$mode" == check ]] && exit 1
  }
done
rules="$(gh api "repos/${GH_REPO}/rulesets" --jq '[.[] | {name, enforcement}]' 2>/dev/null || echo '[]')"
printf '%s\n' "remote labels: $labels" "remote rulesets: $rules"
if [[ "$mode" == check ]]; then
  echo 'Ruleset contents must be reviewed against .github/quality-gates.json; no remote mutation was performed.'
fi
