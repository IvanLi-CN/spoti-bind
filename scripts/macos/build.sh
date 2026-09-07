#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
configuration="debug"
product="SpotiBind"
triple=""

while (($# > 0)); do
    case "$1" in
        --configuration)
            configuration="$2"
            shift 2
            ;;
        --triple)
            triple="$2"
            shift 2
            ;;
        --product)
            product="$2"
            shift 2
            ;;
        -h|--help)
            cat <<'USAGE'
Usage: scripts/macos/build.sh [--configuration debug|release] [--triple TRIPLE] [--product PRODUCT]
USAGE
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

cd "$repo_root"
build_args=(build --product "$product" --configuration "$configuration" --disable-sandbox --disable-index-store)
if [[ -n "$triple" ]]; then
    build_args+=(--triple "$triple")
fi

swift "${build_args[@]}" >&2
bin_args=(build --show-bin-path --configuration "$configuration" --disable-sandbox --disable-index-store)
if [[ -n "$triple" ]]; then
    bin_args+=(--triple "$triple")
fi
bin_dir="$(swift "${bin_args[@]}")"
binary="$bin_dir/$product"
if [[ ! -x "$binary" ]]; then
    printf 'Built product is missing or not executable: %s\n' "$binary" >&2
    exit 1
fi
printf '%s\n' "$binary"
