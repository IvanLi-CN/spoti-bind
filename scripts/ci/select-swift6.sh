#!/usr/bin/env bash
set -euo pipefail

minimum_xcode_version=""
while (($# > 0)); do
    case "$1" in
        --minimum-xcode)
            minimum_xcode_version="$2"
            shift 2
            ;;
        -h|--help)
            printf 'Usage: scripts/ci/select-swift6.sh [--minimum-xcode VERSION]\n'
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

selected_developer_dir=""
version_at_least() {
    awk -v have="$1" -v need="$2" '
        BEGIN {
            split(have, h, "[.]"); split(need, n, "[.]")
            for (i = 1; i <= 3; i++) {
                hv = (h[i] == "" ? 0 : h[i] + 0)
                nv = (n[i] == "" ? 0 : n[i] + 0)
                if (hv > nv) exit 0
                if (hv < nv) exit 1
            }
            exit 0
        }
    '
}
while IFS= read -r xcode_app; do
    developer_dir="$xcode_app/Contents/Developer"
    if [[ ! -d "$developer_dir" ]]; then
        continue
    fi
    swift_binary="$(DEVELOPER_DIR="$developer_dir" xcrun --find swift 2>/dev/null || true)"
    xcode_version="$(DEVELOPER_DIR="$developer_dir" xcodebuild -version 2>/dev/null | awk 'NR == 1 { print $2 }')"
    if [[ -n "$minimum_xcode_version" ]] && ! version_at_least "$xcode_version" "$minimum_xcode_version"; then
        continue
    fi
    if [[ -x "$swift_binary" ]] && "$swift_binary" --version | grep -q 'Apple Swift version 6\.'; then
        selected_developer_dir="$developer_dir"
        break
    fi
done < <(find /Applications -maxdepth 1 -type d -name 'Xcode*.app' -print | sort -r)

if [[ -z "$selected_developer_dir" ]]; then
    printf 'No Swift 6 Xcode toolchain was found on this runner.\n' >&2
    swift --version >&2 || true
    exit 1
fi

sudo xcode-select --switch "$selected_developer_dir"
printf 'Selected developer directory: %s\n' "$selected_developer_dir"
swift --version
