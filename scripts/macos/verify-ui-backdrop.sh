#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
controller="$script_dir/../../Sources/SpotiBind/SettingsWindowController.swift"
menu_panel="$script_dir/../../Sources/SpotiBind/SpotiBindApp.swift"
settings_view="$script_dir/../../Sources/SpotiBind/SettingsView.swift"

if rg -q 'NSGlassEffectView|NSVisualEffectView|windowBackgroundOpacity|titlebarAppearsTransparent|window\.isOpaque|window\.backgroundColor' "$controller"; then
    printf 'Settings window must not override the system window surface.\n' >&2
    exit 1
fi

if ! rg -q 'NSWindow\(contentViewController: hostingController\)' "$controller" \
    || ! rg -q 'containerBackground\(\.thinMaterial, for: \.window\)' "$controller" \
    || ! rg -q '#available\(macOS 15\.0, \*\)' "$controller" \
    || ! rg -q 'NSSize\(width: 720, height: 640\)' "$controller" \
    || ! rg -q 'NSSize\(width: 600, height: 520\)' "$controller" \
    || ! rg -q 'problemBannerVisibilityDidChange' "$controller" \
    || ! rg -q 'SettingsContentHeightPreferenceKey' "$settings_view"; then
    printf 'Settings window must retain its native material and event-driven sizing contract.\n' >&2
    exit 1
fi

if rg -q 'buttonStyle\(\.glass' "$menu_panel" \
    || ! rg -q 'glassEffect\(\.regular, in: shape\)' "$menu_panel"; then
    printf 'Menu transport controls must use one native regular Glass surface.\n' >&2
    exit 1
fi

printf 'Settings window standard-surface contract passed.\n'
