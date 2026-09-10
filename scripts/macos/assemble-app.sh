#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

binary=""
app_path=""
version=""
compiled_resources=""
owns_compiled_resources=0

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

if [[ "$app_path" != /* ]]; then
    app_path="$repo_root/$app_path"
fi
case "$app_path" in
    /|"$repo_root"|"$repo_root/"|*.app) ;;
    *)
        printf 'App path must be a dedicated .app bundle path: %s\n' "$app_path" >&2
        exit 2
        ;;
esac
if [[ "$app_path" == */.. || "$app_path" == */../* || "$app_path" == */. || "$app_path" == */./* ]]; then
    printf 'App path must not contain parent or current-directory components: %s\n' "$app_path" >&2
    exit 2
fi
app_parent="$(dirname "$app_path")"
mkdir -p "$app_parent"
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
    owns_compiled_resources=1
    "$script_dir/compile-icon-resources.sh" --output-dir "$compiled_resources" >/dev/null
fi

for resource in Assets.car SpotiBind.icns; do
    if [[ ! -s "$compiled_resources/$resource" ]]; then
        printf 'Compiled icon resource is missing: %s\n' "$compiled_resources/$resource" >&2
        exit 1
    fi
done

if [[ ! -s "$repo_root/assets/spotibind-logo-monochrome.svg" ]]; then
    printf 'Status bar template source is missing or empty.\n' >&2
    exit 1
fi

staging_path="$(mktemp -d "$app_parent/.spotibind-app.XXXXXX")"
published=0
cleanup() {
    if ((published == 0)); then
        rm -rf "$staging_path"
    fi
    if ((owns_compiled_resources == 1)); then
        rm -rf "$compiled_resources"
    fi
}
trap cleanup EXIT
mkdir -p "$staging_path/Contents/MacOS" "$staging_path/Contents/Resources"
cp "$binary" "$staging_path/Contents/MacOS/SpotiBind"
cp "$repo_root/packaging/macos/Info.plist" "$staging_path/Contents/Info.plist"
cp "$compiled_resources/Assets.car" "$staging_path/Contents/Resources/Assets.car"
cp "$compiled_resources/SpotiBind.icns" "$staging_path/Contents/Resources/SpotiBind.icns"
cp "$repo_root/assets/spotibind-logo-monochrome.svg" "$staging_path/Contents/Resources/StatusBarMark.svg"

if [[ -n "$version" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$staging_path/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$staging_path/Contents/Info.plist"
fi

for resource in \
    "$staging_path/Contents/MacOS/SpotiBind" \
    "$staging_path/Contents/Info.plist" \
    "$staging_path/Contents/Resources/Assets.car" \
    "$staging_path/Contents/Resources/SpotiBind.icns" \
    "$staging_path/Contents/Resources/StatusBarMark.svg"; do
    if [[ ! -s "$resource" ]]; then
        printf 'Staged app resource is missing or empty: %s\n' "$resource" >&2
        exit 1
    fi
done
chmod +x "$staging_path/Contents/MacOS/SpotiBind"
rm -rf "$app_path"
mv "$staging_path" "$app_path"
published=1
printf 'app=%s\n' "$app_path"
