#!/usr/bin/env bash
set -euo pipefail

if (($# < 2 || $# > 3)); then
    printf 'Usage: scripts/macos/capture-theme-ui.sh <light|dark> <out-dir> [scene]\n' >&2
    exit 2
fi

appearance="$1"
out_dir="$2"
scene="${3:-healthy}"
case "$appearance" in
    light|dark) ;;
    *)
        printf 'Appearance must be light or dark.\n' >&2
        exit 2
        ;;
esac
case "$scene" in
    healthy|automatic-selection|accessibility-required|no-supported-player|path-unavailable|dispatch-failure) ;;
    *)
        printf 'Unknown UI demo scene: %s\n' "$scene" >&2
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
probe_bin="$run_root/popover-window-probe"
log="$run_root/capture.log"
ready_file="$run_root/ready"
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

"$script_dir/assemble-app.sh" --binary "$app_bin" --app-path "$app_bundle" >/dev/null
swiftc "$script_dir/popover-window-probe.swift" -o "$probe_bin"

SPOTIBIND_UI_DEMO=1 \
SPOTIBIND_UI_DEMO_SCENE="$scene" \
SPOTIBIND_UI_APPEARANCE="$appearance" \
SPOTIBIND_UI_SNAPSHOT_SURFACE=popover \
SPOTIBIND_UI_SNAPSHOT_READY_FILE="$ready_file" \
    "$app_bundle/Contents/MacOS/SpotiBind" >"$log" 2>&1 &
app_pid=$!

window_id=""
for _ in {1..300}; do
    ready_pid="$(awk -F= '/^pid=/{print $2}' "$ready_file" 2>/dev/null || true)"
    ready_window="$(awk -F= '/^window=/{print $2}' "$ready_file" 2>/dev/null || true)"
    if [[ "$ready_pid" == "$app_pid" ]] \
        && [[ "$ready_window" =~ ^[0-9]+$ ]] \
        && window_id="$($probe_bin "$app_pid" "$ready_window" 2>>"$log")" \
        && [[ "$window_id" =~ ^[0-9]+$ ]] \
        && screencapture -x -l "$window_id" "$popover_output" >>"$log" 2>&1 \
        && [[ -s "$popover_output" ]] \
        && file "$popover_output" | grep -qi 'PNG image'; then
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
    "$script_dir/capture-settings-window.sh" "$scene" "$settings_output"

printf '%s\n%s\n' "$popover_output" "$settings_output"
