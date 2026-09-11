#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
    printf 'Usage: scripts/macos/capture-settings-window.sh <scene> <out.png>\n' >&2
    exit 2
fi

scene="$1"
out="$2"
case "$scene" in
    healthy|automatic-selection|accessibility-required|no-supported-player|path-unavailable|dispatch-failure) ;;
    *)
        printf 'Unknown UI demo scene: %s\n' "$scene" >&2
        exit 2
        ;;
esac

appearance="${SPOTIBIND_UI_APPEARANCE:-light}"
case "$appearance" in
    light|dark) ;;
    *)
        printf 'SPOTIBIND_UI_APPEARANCE must be light or dark.\n' >&2
        exit 2
        ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
cd "$repo_root"

app_bin="$($script_dir/build.sh --configuration debug)"
run_root="$(mktemp -d "${TMPDIR:-/tmp}/spotibind-settings.XXXXXX")"
probe_bin="$run_root/window-probe"
app_bundle="$run_root/SpotiBind.app"
log="$run_root/capture.log"
ready_file="$run_root/ready"
out_dir="$(dirname "$out")"
mkdir -p "$out_dir"
out_path="$(cd "$out_dir" && pwd)/$(basename "$out")"
rm -f "$out_path"

cleanup() {
    if [[ -n "${app_pid:-}" ]] && kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi
    rm -rf "$run_root"
}
trap cleanup EXIT

"$script_dir/assemble-app.sh" --binary "$app_bin" --app-path "$app_bundle" >/dev/null
swiftc "$script_dir/window-probe.swift" -o "$probe_bin"

SPOTIBIND_UI_DEMO=1 \
SPOTIBIND_UI_DEMO_SCENE="$scene" \
SPOTIBIND_UI_APPEARANCE="$appearance" \
SPOTIBIND_UI_SNAPSHOT_SURFACE=settings-window \
SPOTIBIND_UI_SNAPSHOT_READY_FILE="$ready_file" \
    "$app_bundle/Contents/MacOS/SpotiBind" >"$log" 2>&1 &
app_pid=$!

window_id=""
for _ in {1..40}; do
    if window_id="$($probe_bin "$app_pid" 2>>"$log")"; then
        if [[ "$window_id" =~ ^[0-9]+$ ]]; then
            break
        fi
    fi
    window_id=""
    sleep 0.2
done

if [[ -z "$window_id" ]]; then
    printf 'Unable to find the unique SpotiBind settings window.\n' >&2
    sed -n '1,120p' "$log" >&2 || true
    exit 1
fi

captured=0
for _ in {1..5}; do
    rm -f "$out_path"
    if screencapture -x -l "$window_id" "$out_path" >>"$log" 2>&1 \
        && [[ -s "$out_path" ]] \
        && file "$out_path" | grep -qi 'PNG image'; then
        captured=1
        break
    fi
    sleep 0.2
done

if ((captured == 0)); then
    printf 'WindowServer did not produce a valid settings PNG.\n' >&2
    sed -n '1,160p' "$log" >&2 || true
    rm -f "$out_path"
    exit 1
fi

printf '%s\n' "$out_path"
