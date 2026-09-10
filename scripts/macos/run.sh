#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
binary="$("$script_dir/build.sh" --configuration debug)"
run_root="$(mktemp -d "${TMPDIR:-/tmp}/spotibind-run.XXXXXX")"
trap 'rm -rf "$run_root"' EXIT
app_bundle="$run_root/SpotiBind.app"
"$script_dir/assemble-app.sh" --binary "$binary" --app-path "$app_bundle" >/dev/null
exec "$app_bundle/Contents/MacOS/SpotiBind"
