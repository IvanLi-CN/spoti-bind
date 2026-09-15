#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
version="$(tr -d '[:space:]' < "$repo_root/VERSION")"
output_dir="$repo_root/dist"

while (($# > 0)); do
    case "$1" in
        --version)
            version="$2"
            shift 2
            ;;
        --output-dir)
            output_dir="$2"
            shift 2
            ;;
        -h|--help)
            cat <<'USAGE'
Usage: scripts/macos/package.sh [--version VERSION] [--output-dir DIRECTORY]
USAGE
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Version must be semantic numeric form, got: %s\n' "$version" >&2
    exit 2
fi

if [[ "$output_dir" != /* ]]; then
    output_dir="$repo_root/$output_dir"
fi
mkdir -p "$output_dir"

for tool in swift lipo codesign ditto hdiutil osascript SetFile shasum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required macOS tool is missing: %s\n' "$tool" >&2
        exit 1
    fi
done

build_root="$(mktemp -d "${TMPDIR:-/tmp}/spotibind-build.XXXXXX")"
dmg_mount=""
dmg_mounted=0

cleanup() {
    if ((dmg_mounted == 1)) && [[ -n "$dmg_mount" ]]; then
        hdiutil detach "$dmg_mount" -quiet >/dev/null 2>&1 || true
    fi
    rm -rf "$build_root"
}
trap cleanup EXIT

build_arch() {
    local arch="$1"
    local triple="$arch-apple-macosx13.0"
    local scratch="$build_root/$arch"
    local bin_dir
    swift build \
        --product SpotiBind \
        --configuration release \
        --triple "$triple" \
        --scratch-path "$scratch" \
        --disable-sandbox \
        --disable-index-store >&2
    bin_dir="$(swift build \
        --show-bin-path \
        --configuration release \
        --triple "$triple" \
        --scratch-path "$scratch" \
        --disable-sandbox \
        --disable-index-store)"
    if [[ ! -x "$bin_dir/SpotiBind" ]]; then
        printf 'Missing %s release binary at %s\n' "$arch" "$bin_dir/SpotiBind" >&2
        exit 1
    fi
    printf '%s\n' "$bin_dir/SpotiBind"
}

arm64_binary="$(build_arch arm64)"
x86_64_binary="$(build_arch x86_64)"

app_path="$output_dir/SpotiBind.app"
dmg_path="$output_dir/SpotiBind-${version}-universal.dmg"
checksums_path="$output_dir/SHA256SUMS"
merged_binary="$build_root/SpotiBind-universal"
dmg_staging="$build_root/dmg-staging"
dmg_readwrite="$build_root/SpotiBind-installer.dmg"
dmg_background="$repo_root/packaging/macos/dmg-background.png"
attach_info="$build_root/dmg-attach.plist"
volume_name="SpotiBind $version"
finder_volume_name=""

if [[ ! -s "$dmg_background" ]]; then
    printf 'DMG background is missing or empty: %s\n' "$dmg_background" >&2
    exit 1
fi

mkdir -p "$output_dir"
rm -rf "$app_path"
rm -f "$dmg_path" "$checksums_path"
lipo -create "$arm64_binary" "$x86_64_binary" -output "$merged_binary"
"$script_dir/assemble-app.sh" \
    --binary "$merged_binary" \
    --app-path "$app_path" \
    --version "$version"

codesign --force --sign - --timestamp=none "$app_path"
codesign --verify --strict --verbose=2 "$app_path"

mkdir -p "$dmg_staging/.background"
ditto "$app_path" "$dmg_staging/SpotiBind.app"
ln -s /Applications "$dmg_staging/Applications"
cp "$dmg_background" "$dmg_staging/.background/background.png"

hdiutil create \
    -fs HFS+ \
    -volname "$volume_name" \
    -srcfolder "$dmg_staging" \
    -ov \
    -format UDRW \
    "$dmg_readwrite" >&2

hdiutil attach \
    -readwrite \
    -noverify \
    -plist \
    "$dmg_readwrite" > "$attach_info"
dmg_mount=""
for entity_index in {0..9}; do
    candidate_mount="$(/usr/libexec/PlistBuddy -c "Print :system-entities:$entity_index:mount-point" "$attach_info" 2>/dev/null || true)"
    if [[ -n "$candidate_mount" && -d "$candidate_mount" ]]; then
        dmg_mount="$candidate_mount"
        break
    fi
done
if [[ -z "$dmg_mount" || ! -d "$dmg_mount" ]]; then
    printf 'Could not determine the mounted DMG path from: %s\n' "$attach_info" >&2
    exit 1
fi
dmg_mounted=1
finder_volume_name="$(basename "$dmg_mount")"

for hidden_path in \
    "$dmg_mount/.background" \
    "$dmg_mount/.fseventsd" \
    "$dmg_mount/.DS_Store"; do
    if [[ -e "$hidden_path" ]]; then
        chflags hidden "$hidden_path"
        SetFile -a V "$hidden_path"
    fi
done

osascript <<EOF
tell application "Finder"
    tell disk "$finder_volume_name"
        open
        set containerWindow to container window
        set current view of containerWindow to icon view
        set toolbar visible of containerWindow to false
        set statusbar visible of containerWindow to false
        set bounds of containerWindow to {100, 100, 920, 600}
        set viewOptions to icon view options of containerWindow
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 14
        set background picture of viewOptions to (POSIX file "$dmg_mount/.background/background.png" as alias)
        set position of item "SpotiBind.app" to {170, 300}
        set position of item "Applications" to {650, 300}
        try
            set position of item ".background" to {1200, 900}
        end try
        try
            set position of item ".fseventsd" to {1320, 900}
        end try
        try
            set position of item ".DS_Store" to {1440, 900}
        end try
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# Finder creates or updates .DS_Store while applying the view settings; keep
# all metadata entries invisible after that write as well.
for hidden_path in \
    "$dmg_mount/.background" \
    "$dmg_mount/.fseventsd" \
    "$dmg_mount/.DS_Store"; do
    if [[ -e "$hidden_path" ]]; then
        chflags hidden "$hidden_path"
        SetFile -a V "$hidden_path"
    fi
done

sync
hdiutil detach "$dmg_mount" -quiet
dmg_mounted=0
hdiutil convert "$dmg_readwrite" \
    -format UDZO \
    -ov \
    -imagekey zlib-level=9 \
    -o "$dmg_path" >&2

(cd "$output_dir" && shasum -a 256 "$(basename "$dmg_path")" > "$(basename "$checksums_path")")

printf 'app=%s\ndmg=%s\nchecksums=%s\n' "$app_path" "$dmg_path" "$checksums_path"
