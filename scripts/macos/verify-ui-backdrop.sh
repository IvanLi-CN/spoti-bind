#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
controller="$script_dir/../../Sources/SpotiBind/SettingsWindowController.swift"
menu_panel="$script_dir/../../Sources/SpotiBind/SpotiBindApp.swift"
settings_view="$script_dir/../../Sources/SpotiBind/SettingsView.swift"

matches() {
    local pattern="$1"
    local path="$2"

    if command -v rg >/dev/null 2>&1; then
        rg -q -- "$pattern" "$path"
    else
        grep -E -q -- "$pattern" "$path"
    fi
}

if matches 'NSGlassEffectView|NSVisualEffectView|windowBackgroundOpacity|titlebarAppearsTransparent|window\.isOpaque|window\.backgroundColor' "$controller"; then
    printf 'Settings window must not override the system window surface.\n' >&2
    exit 1
fi

if ! matches 'NSWindow\(contentViewController: hostingController\)' "$controller" \
    || ! matches 'containerBackground\(\.thinMaterial, for: \.window\)' "$controller" \
    || ! matches '#available\(macOS 15\.0, \*\)' "$controller" \
    || ! matches 'NSSize\(width: 720, height: 640\)' "$controller" \
    || ! matches 'NSSize\(width: 600, height: 520\)' "$controller" \
    || ! matches 'problemBannerVisibilityDidChange' "$controller" \
    || ! matches 'SettingsContentHeightPreferenceKey' "$settings_view"; then
    printf 'Settings window must retain its native material and event-driven sizing contract.\n' >&2
    exit 1
fi

if matches 'buttonStyle\(\.glass' "$menu_panel" \
    || ! matches 'glassEffect\(\.regular, in: shape\)' "$menu_panel"; then
    printf 'Menu transport controls must use one native regular Glass surface.\n' >&2
    exit 1
fi

printf 'Settings window standard-surface contract passed.\n'
