#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
    printf 'Usage: scripts/macos/capture-theme-ui.sh <light|dark> <out-dir>\n' >&2
    exit 2
fi

appearance="$1"
out_dir="$2"
case "$appearance" in
    light|dark) ;;
    *)
        printf 'Appearance must be light or dark.\n' >&2
        exit 2
        ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
cd "$repo_root"
mkdir -p "$out_dir"
out_dir="$(cd "$out_dir" && pwd)"

app_bin="$($script_dir/build.sh --configuration debug)"
run_root="$(mktemp -d "${TMPDIR:-/tmp}/spotibind-popover.XXXXXX")"
app_bundle="$run_root/SpotiBind.app"
log="$run_root/capture.log"
popover_output="$out_dir/theme-$appearance-popover.png"
settings_output="$out_dir/theme-$appearance-settings.png"
rm -f "$popover_output" "$settings_output"

cleanup() {
    if [[ -n "${app_pid:-}" ]] && kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi
    rm -rf "$run_root"
}
trap cleanup EXIT

mkdir -p "$app_bundle/Contents/MacOS"
cp "$app_bin" "$app_bundle/Contents/MacOS/SpotiBind"
cp "$repo_root/packaging/macos/Info.plist" "$app_bundle/Contents/Info.plist"
chmod +x "$app_bundle/Contents/MacOS/SpotiBind"

printf 'Waiting for the owner to open the real SpotiBind menu-bar popover...\n' >&2
SPOTIBIND_UI_DEMO=1 \
SPOTIBIND_UI_DEMO_SCENE=healthy \
SPOTIBIND_UI_APPEARANCE="$appearance" \
SPOTIBIND_UI_SNAPSHOT_SURFACE=popover \
SPOTIBIND_UI_SNAPSHOT_OUTPUT="$popover_output" \
    "$app_bundle/Contents/MacOS/SpotiBind" >"$log" 2>&1 &
app_pid=$!

for _ in {1..60}; do
    if [[ -s "$popover_output" ]] && file "$popover_output" | grep -qi 'PNG image'; then
        break
    fi
    if ! kill -0 "$app_pid" 2>/dev/null; then
        break
    fi
    sleep 0.2
done

if [[ ! -s "$popover_output" ]] || ! file "$popover_output" | grep -qi 'PNG image'; then
    printf 'The real MenuBarExtra(.window) host was not captured.\n' >&2
    sed -n '1,160p' "$log" >&2 || true
    rm -f "$popover_output"
    exit 1
fi

SPOTIBIND_UI_APPEARANCE="$appearance" \
    "$script_dir/capture-settings-window.sh" healthy "$settings_output"

printf '%s\n%s\n' "$popover_output" "$settings_output"
