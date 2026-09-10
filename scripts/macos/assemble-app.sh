#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

binary=""
app_path=""
version=""
compiled_resources=""

while (($# > 0)); do
    case "$1" in
        --binary)
            binary="$2"
            shift 2
            ;;
        --app-path)
            app_path="$2"
            shift 2
            ;;
        --version)
            version="$2"
            shift 2
            ;;
        --compiled-resources)
            compiled_resources="$2"
            shift 2
            ;;
        -h|--help)
            cat <<'USAGE'
Usage: scripts/macos/assemble-app.sh --binary PATH --app-path PATH [--version VERSION] [--compiled-resources DIRECTORY]
USAGE
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

if [[ -z "$binary" || -z "$app_path" ]]; then
    printf '%s\n' '--binary and --app-path are required.' >&2
    exit 2
fi
if [[ ! -x "$binary" ]]; then
    printf 'Application binary is missing or not executable: %s\n' "$binary" >&2
    exit 1
fi

if [[ -n "$version" && ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Version must be semantic numeric form, got: %s\n' "$version" >&2
    exit 2
fi

if [[ -z "$compiled_resources" ]]; then
    compiled_resources="$(mktemp -d "${TMPDIR:-/tmp}/spotibind-icon-resources.XXXXXX")"
    trap 'rm -rf "$compiled_resources"' EXIT
    "$script_dir/compile-icon-resources.sh" --output-dir "$compiled_resources" >/dev/null
fi

for resource in Assets.car SpotiBind.icns; do
    if [[ ! -f "$compiled_resources/$resource" ]]; then
        printf 'Compiled icon resource is missing: %s\n' "$compiled_resources/$resource" >&2
        exit 1
    fi
done

rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary" "$app_path/Contents/MacOS/SpotiBind"
cp "$repo_root/packaging/macos/Info.plist" "$app_path/Contents/Info.plist"
cp "$compiled_resources/Assets.car" "$app_path/Contents/Resources/Assets.car"
cp "$compiled_resources/SpotiBind.icns" "$app_path/Contents/Resources/SpotiBind.icns"
cp "$repo_root/assets/spotibind-logo-monochrome.svg" "$app_path/Contents/Resources/StatusBarMark.svg"

if [[ -n "$version" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app_path/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$app_path/Contents/Info.plist"
fi

chmod +x "$app_path/Contents/MacOS/SpotiBind"
printf 'app=%s\n' "$app_path"
