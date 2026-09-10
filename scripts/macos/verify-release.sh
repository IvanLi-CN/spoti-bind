#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
version="$(tr -d '[:space:]' < "$repo_root/VERSION")"
app_path="$repo_root/dist/SpotiBind.app"
dmg_path="$repo_root/dist/SpotiBind-${version}-universal.dmg"
checksums_path="$repo_root/dist/SHA256SUMS"

while (($# > 0)); do
    case "$1" in
        --app)
            app_path="$2"
            shift 2
            ;;
        --dmg)
            dmg_path="$2"
            shift 2
            ;;
        --checksums)
            checksums_path="$2"
            shift 2
            ;;
        -h|--help)
            cat <<'USAGE'
Usage: scripts/macos/verify-release.sh [--app APP] [--dmg DMG] [--checksums SHA256SUMS]
USAGE
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

for path in "$app_path" "$dmg_path" "$checksums_path"; do
    if [[ ! -e "$path" ]]; then
        printf 'Release artifact is missing: %s\n' "$path" >&2
        exit 1
    fi
done

binary="$app_path/Contents/MacOS/SpotiBind"
plist="$app_path/Contents/Info.plist"
assets_car="$app_path/Contents/Resources/Assets.car"
fallback_icon="$app_path/Contents/Resources/SpotiBind.icns"
status_template="$app_path/Contents/Resources/StatusBarMark.svg"
if [[ ! -x "$binary" ]]; then
    printf 'App executable is missing or not executable: %s\n' "$binary" >&2
    exit 1
fi
if [[ ! -f "$plist" ]]; then
    printf 'App Info.plist is missing: %s\n' "$plist" >&2
    exit 1
fi
for resource in "$assets_car" "$fallback_icon" "$status_template"; do
    if [[ ! -s "$resource" ]]; then
        printf 'App resource is missing or empty: %s\n' "$resource" >&2
        exit 1
    fi
done

archs="$(lipo -archs "$binary")"
[[ " $archs " == *" arm64 "* ]] || { printf 'arm64 slice missing: %s\n' "$archs" >&2; exit 1; }
[[ " $archs " == *" x86_64 "* ]] || { printf 'x86_64 slice missing: %s\n' "$archs" >&2; exit 1; }

codesign --verify --strict --verbose=2 "$app_path"
signature="$(codesign -dv --verbose=4 "$app_path" 2>&1 || true)"
if ! grep -q '^Signature=adhoc$' <<< "$signature"; then
    printf 'Expected an Ad Hoc signature.\n%s\n' "$signature" >&2
    exit 1
fi

minimum="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")"
[[ "$minimum" == "13.0" ]] || { printf 'Unexpected minimum system version: %s\n' "$minimum" >&2; exit 1; }
identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")"
[[ "$identifier" == "cc.ivanli.spotibind" ]] || { printf 'Unexpected bundle identifier: %s\n' "$identifier" >&2; exit 1; }
icon_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$plist")"
[[ "$icon_name" == "SpotiBind" ]] || { printf 'Unexpected bundle icon name: %s\n' "$icon_name" >&2; exit 1; }

hdiutil imageinfo "$dmg_path" >/dev/null
checksum_dir="$(cd "$(dirname "$checksums_path")" && pwd)"
(cd "$checksum_dir" && shasum -a 256 -c "$(basename "$checksums_path")")

printf 'Verified universal Ad Hoc release: %s\n' "$dmg_path"
