#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
output_dir="$repo_root/.build/icon-resources"

while (($# > 0)); do
    case "$1" in
        --output-dir)
            output_dir="$2"
            shift 2
            ;;
        -h|--help)
            cat <<'USAGE'
Usage: scripts/macos/compile-icon-resources.sh [--output-dir DIRECTORY]

Compiles the Icon Composer document and creates macOS fallback resources.
USAGE
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

if [[ "$output_dir" != /* ]]; then
    output_dir="$repo_root/$output_dir"
fi

while [[ "$output_dir" == */ && "$output_dir" != "/" ]]; do
    output_dir="${output_dir%/}"
done
if [[ "$output_dir" == */.. \
    || "$output_dir" == */../* \
    || "$output_dir" == */. \
    || "$output_dir" == */./* ]]; then
    printf 'Output directory must be a dedicated child path: %s\n' "$output_dir" >&2
    exit 2
fi
case "$(basename "$output_dir")" in
    .|..)
        printf 'Output directory must be a dedicated child path: %s\n' "$output_dir" >&2
        exit 2
        ;;
esac
requested_parent="$(dirname "$output_dir")"
tmp_dir="$(printenv TMPDIR || true)"
[[ -n "$tmp_dir" ]] || tmp_dir="/tmp"
while [[ "$requested_parent" == */ && "$requested_parent" != "/" ]]; do
    requested_parent="${requested_parent%/}"
done
while [[ "$tmp_dir" == */ && "$tmp_dir" != "/" ]]; do
    tmp_dir="${tmp_dir%/}"
done
case "$requested_parent" in
    "$repo_root/.build"|/tmp|/private/tmp|/var/tmp|/private/var/tmp|"$tmp_dir") ;;
    *)
        printf 'Output directory must be a dedicated child of an approved disposable directory: %s\n' "$output_dir" >&2
        exit 2
        ;;
esac
mkdir -p "$requested_parent"
output_parent="$(cd "$requested_parent" && pwd -P)"
output_base="$(basename "$output_dir")"
if [[ "$output_parent" == "/" ]]; then
    output_dir="/$output_base"
else
    output_dir="$output_parent/$output_base"
fi
tmp_dir="$(cd "$tmp_dir" && pwd -P)"
repo_root="$(cd "$repo_root" && pwd -P)"
build_parent="$repo_root/.build"
if [[ -d "$build_parent" ]]; then
    build_parent="$(cd "$build_parent" && pwd -P)"
fi
var_tmp_parent="$(cd /var/tmp && pwd -P)"
case "$output_dir" in
    /|"$repo_root"|/tmp|/private/tmp|/var/tmp|/private/var/tmp|"$tmp_dir")
        printf 'Refusing to remove a broad output directory: %s\n' "$output_dir" >&2
        exit 2
        ;;
esac
case "$output_parent" in
    "$build_parent"|/tmp|/private/tmp|"$var_tmp_parent"|"$tmp_dir") ;;
    *)
        printf 'Output directory parent is not an approved disposable directory: %s\n' "$output_dir" >&2
        exit 2
        ;;
esac

icon_doc="$repo_root/packaging/macos/IconResources/SpotiBind.icon"
icon_project="$repo_root/packaging/macos/IconResources/IconResources.xcodeproj"
if [[ ! -e "$icon_doc" ]]; then
    printf 'Icon Composer document is missing: %s\n' "$icon_doc" >&2
    exit 1
fi
if [[ ! -d "$icon_project" ]]; then
    printf 'Icon resource target is missing: %s\n' "$icon_project" >&2
    exit 1
fi

mono_source="$icon_doc/Assets/spotibind-icon-mono.svg"
if [[ ! -s "$mono_source" ]]; then
    printf 'High-contrast Mono icon source is missing: %s\n' "$mono_source" >&2
    exit 1
fi
if ! rg -q -U '<path\s*\n\s*fill="#fff"\s*\n\s*mask=' "$mono_source"; then
    printf 'Mono icon source must provide a white masked foreground: %s\n' "$mono_source" >&2
    exit 1
fi

developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
xcodebuild_bin="$developer_dir/usr/bin/xcodebuild"
ictool_bin="$(dirname "$developer_dir")/Applications/Icon Composer.app/Contents/Executables/ictool"
iconutil_bin="$(DEVELOPER_DIR="$developer_dir" xcrun --find iconutil 2>/dev/null || true)"
if [[ ! -x "$xcodebuild_bin" || ! -x "$ictool_bin" ]]; then
    printf 'Xcode 26.4+ with xcodebuild and ictool is required to compile app icons.\n' >&2
    exit 1
fi

xcode_version="$($xcodebuild_bin -version | awk 'NR == 1 { print $2 }')"
required_major=26
required_minor=4
xcode_major="${xcode_version%%.*}"
xcode_minor="${xcode_version#*.}"
xcode_minor="${xcode_minor%%.*}"
if [[ ! "$xcode_major" =~ ^[0-9]+$ || ! "$xcode_minor" =~ ^[0-9]+$ ]] \
    || ((xcode_major < required_major)) \
    || ((xcode_major == required_major && xcode_minor < required_minor)); then
    printf 'Xcode %s is too old; Icon Composer resources require Xcode 26.4+.\n' "$xcode_version" >&2
    exit 1
fi

rm -rf "$output_dir"
mkdir -p "$output_dir/previews" "$output_dir/default.iconset"

export_preview() {
    local rendition="$1"
    local size="$2"
    local output="$output_dir/previews/${rendition}-${size}.png"
    "$ictool_bin" "$icon_doc" \
        --export-image \
        --output-file "$output" \
        --platform macOS \
        --rendition "$rendition" \
        --width "$size" \
        --height "$size" \
        --scale 1
}

for rendition in Default Dark Mono; do
    for size in 16 32 128 512; do
        export_preview "$rendition" "$size"
    done
done

for size in 16 32 64 128 256 512 1024; do
    export_preview Default "$size"
    cp "$output_dir/previews/Default-${size}.png" "$output_dir/default.iconset/icon_${size}x${size}.png"
done

for size in 16 32 128 256 512; do
    retina_size=$((size * 2))
    if [[ -f "$output_dir/previews/Default-${retina_size}.png" ]]; then
        cp "$output_dir/previews/Default-${retina_size}.png" "$output_dir/default.iconset/icon_${size}x${size}@2x.png"
    fi
done

for icon_file in \
    icon_16x16.png icon_16x16@2x.png \
    icon_32x32.png icon_32x32@2x.png \
    icon_128x128.png icon_128x128@2x.png \
    icon_256x256.png icon_256x256@2x.png \
    icon_512x512.png icon_512x512@2x.png; do
    if [[ ! -s "$output_dir/default.iconset/$icon_file" ]]; then
        printf 'Incomplete fallback iconset; missing %s.\n' "$icon_file" >&2
        exit 1
    fi
done

if [[ -n "$iconutil_bin" ]]; then
    "$iconutil_bin" --convert icns --output "$output_dir/SpotiBind.icns" "$output_dir/default.iconset"
else
    printf 'iconutil is required for the macOS 13 fallback icon.\n' >&2
    exit 1
fi

roundtrip_iconset="$output_dir/icns-roundtrip.iconset"
"$iconutil_bin" --convert iconset --output "$roundtrip_iconset" "$output_dir/SpotiBind.icns"
for icon_file in \
    icon_16x16.png icon_16x16@2x.png \
    icon_32x32.png icon_32x32@2x.png \
    icon_128x128.png icon_128x128@2x.png \
    icon_256x256.png icon_256x256@2x.png \
    icon_512x512.png icon_512x512@2x.png; do
    if [[ ! -s "$roundtrip_iconset/$icon_file" ]]; then
        printf 'Generated ICNS is missing %s.\n' "$icon_file" >&2
        exit 1
    fi
done
rm -rf "$roundtrip_iconset"

derived_dir="$(mktemp -d "${TMPDIR:-/tmp}/spotibind-icon-build.XXXXXX")"
trap 'rm -rf "$derived_dir"' EXIT
DEVELOPER_DIR="$developer_dir" "$xcodebuild_bin" \
    -project "$icon_project" \
    -scheme IconResources \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_dir" \
    -quiet

assets_car="$(find "$derived_dir" -type f -name Assets.car -print -quit)"
if [[ -z "$assets_car" ]]; then
    printf 'Icon resource target did not produce Assets.car.\n' >&2
    exit 1
fi
cp "$assets_car" "$output_dir/Assets.car"

printf 'compiled_icon_resources=%s\n' "$output_dir"
