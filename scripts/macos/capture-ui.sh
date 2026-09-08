#!/usr/bin/env bash
set -euo pipefail

surface="${1:-}"
out="${2:-}"

if [[ -z "$surface" || -z "$out" ]]; then
    echo "Usage: scripts/macos/capture-ui.sh <menu|settings> <out.png>" >&2
    exit 2
fi

case "$surface" in
    menu|settings) ;;
    *)
        echo "Surface must be menu or settings." >&2
        exit 2
        ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_bin="$("$script_dir/build.sh" --configuration debug)"
out_dir="$(dirname "$out")"
prefix="$(basename "$out" .png)"
log="$(mktemp /tmp/spotibind-ui.XXXXXX.log)"

mkdir -p "$out_dir"
rm -f "$out"

cleanup() {
    if [[ -n "${app_pid:-}" ]] && kill -0 "$app_pid" >/dev/null 2>&1; then
        kill "$app_pid" >/dev/null 2>&1 || true
        wait "$app_pid" >/dev/null 2>&1 || true
    fi
    rm -f "$log"
}
trap cleanup EXIT

delay_ms="${SPOTIBIND_UI_SNAPSHOT_DELAY_MS:-900}"
env "SPOTIBIND_UI_DEMO=1" "SPOTIBIND_UI_SNAPSHOT_DIR=$out_dir" "SPOTIBIND_UI_SNAPSHOT_SURFACE=$surface" "SPOTIBIND_UI_SNAPSHOT_PREFIX=$prefix" "SPOTIBIND_UI_SNAPSHOT_DELAY_MS=$delay_ms" "$app_bin" >"$log" 2>&1 &
app_pid=$!

for _ in {1..30}; do
    if [[ -s "$out" ]]; then
        exit 0
    fi
    if ! kill -0 "$app_pid" >/dev/null 2>&1; then
        cat "$log" >&2
        exit 1
    fi
    sleep 0.2
done

cat "$log" >&2
echo "Timed out waiting for scoped $surface snapshot: $out" >&2
exit 1
