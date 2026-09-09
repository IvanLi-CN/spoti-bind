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
  ruleset_body="$(mktemp)"
  trap 'rm -f "$ruleset_body"' EXIT
  printf '%s\n' '{"name":"main release policy","target":"branch","enforcement":"active","conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"rules":[{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":true}},{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"do_not_enforce_on_create":false,"required_status_checks":[{"context":"PR / Swift tests"},{"context":"PR / Build app"},{"context":"Label Gate"},{"context":"Release completion"}]}},{"type":"commit_signature_requirement"}]}' > "$ruleset_body"
  existing_ruleset="$(gh api "repos/${GH_REPO}/rulesets" --jq '.[] | select(.name == "main release policy") | .id' | head -n1)"
  if [[ -n "$existing_ruleset" ]]; then
    gh api --method PUT "repos/${GH_REPO}/rulesets/${existing_ruleset}" --input "$ruleset_body"
  else
    gh api --method POST "repos/${GH_REPO}/rulesets" --input "$ruleset_body"
  fi
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
if ! jq -e 'any(.[]; .name == "main release policy" and .enforcement == "active")' <<<"$rules" >/dev/null; then
  echo 'missing active main release policy ruleset' >&2
  exit 1
fi
if [[ "$mode" == check ]]; then
  echo 'Ruleset contents must be reviewed against .github/quality-gates.json; no remote mutation was performed.'
fi
