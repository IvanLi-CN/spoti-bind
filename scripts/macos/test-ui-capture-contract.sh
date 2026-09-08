#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
theme_script="$script_dir/capture-theme-ui.sh"
settings_script="$script_dir/capture-settings-window.sh"

bash -n "$theme_script" "$settings_script"
[[ ! -e "$script_dir/capture-ui.sh" ]]
grep -Fq 'screencapture -x -l "$window_id"' "$settings_script"
! grep -Fq 'NSPanel' "$script_dir/../../Sources/SpotiBind/UISnapshot.swift"
grep -Fq 'NSStatusBarWindow' "$script_dir/../../Sources/SpotiBind/UISnapshot.swift"
grep -Fq 'performClick(nil)' "$script_dir/../../Sources/SpotiBind/UISnapshot.swift"
grep -Fq 'menuBarExtraStyle(.window)' "$script_dir/../../Sources/SpotiBind/SpotiBindApp.swift"

if "$theme_script" system /tmp/spotibind-contract-test >/dev/null 2>&1; then
    printf 'capture-theme-ui.sh accepted an invalid appearance.\n' >&2
    exit 1
fi
if "$settings_script" invalid /tmp/spotibind-contract-test.png >/dev/null 2>&1; then
    printf 'capture-settings-window.sh accepted an invalid scene.\n' >&2
    exit 1
fi

printf 'UI capture shell contract passed.\n'
