#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
cd "$repo_root"

bash .github/scripts/test-release-workflows.sh
bash scripts/macos/test-ui-capture-contract.sh
swift test --disable-sandbox --disable-index-store -j 2
scripts/macos/verify-ui-backdrop.sh
PATH=/usr/bin:/bin scripts/macos/verify-ui-backdrop.sh
