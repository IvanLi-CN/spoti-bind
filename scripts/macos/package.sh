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

for tool in swift lipo codesign hdiutil shasum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required macOS tool is missing: %s\n' "$tool" >&2
        exit 1
    fi
done

build_root="$(mktemp -d "${TMPDIR:-/tmp}/spotibind-build.XXXXXX")"
trap 'rm -rf "$build_root"' EXIT

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

rm -rf "$app_path"
rm -f "$dmg_path" "$checksums_path"
mkdir -p "$output_dir"
lipo -create "$arm64_binary" "$x86_64_binary" -output "$merged_binary"
"$script_dir/assemble-app.sh" \
    --binary "$merged_binary" \
    --app-path "$app_path" \
    --version "$version"

codesign --force --sign - --timestamp=none "$app_path"
codesign --verify --strict --verbose=2 "$app_path"
hdiutil create \
    -volname "SpotiBind $version" \
    -srcfolder "$app_path" \
    -ov \
    -format UDZO \
    "$dmg_path" >&2

(cd "$output_dir" && shasum -a 256 "$(basename "$dmg_path")" > "$(basename "$checksums_path")")

printf 'app=%s\ndmg=%s\nchecksums=%s\n' "$app_path" "$dmg_path" "$checksums_path"
