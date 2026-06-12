#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${NETLAB_ROOT:-$(CDPATH='' cd -- "$script_dir/.." && pwd)}"

# shellcheck source=/dev/null
source "$repo_root/config/openwrt.env"

build_dir="${BUILD_DIR:-$repo_root/build}"
stage_dir="${STAGE_DIR:-$build_dir/staged-files}"
downloads_dir="$build_dir/downloads/$OPENWRT_VERSION-$OPENWRT_TARGET-$OPENWRT_SUBTARGET"
imagebuilder_name="openwrt-imagebuilder-$OPENWRT_VERSION-$OPENWRT_TARGET-$OPENWRT_SUBTARGET.$OPENWRT_HOST_SUFFIX"
archive="$imagebuilder_name.tar.zst"
base_url="https://downloads.openwrt.org/releases/$OPENWRT_VERSION/targets/$OPENWRT_TARGET/$OPENWRT_SUBTARGET"
archive_path="$downloads_dir/$archive"
sha256sums_path="$downloads_dir/sha256sums"
imagebuilder_dir="$build_dir/$imagebuilder_name"
output_dir="${BUILD_OUTPUT_DIR:-$build_dir/output}"

if [ ! -d "$stage_dir/etc/config" ]; then
	printf "Error: staged files missing. Run 'task render' first.\n" >&2
	exit 1
fi

mkdir -p "$downloads_dir"

if [ ! -f "$sha256sums_path" ]; then
	curl -fsSL "$base_url/sha256sums" -o "$sha256sums_path"
fi

if [ ! -f "$archive_path" ]; then
	curl -fL "$base_url/$archive" -o "$archive_path"
fi

expected_sha256="${OPENWRT_IMAGEBUILDER_SHA256:-}"
if [ -z "$expected_sha256" ]; then
	expected_sha256="$(awk -v file="$archive" '{ name=$2; sub(/^\*/, "", name); if (name == file) { print $1; exit } }' "$sha256sums_path")"
fi

if [ -z "$expected_sha256" ]; then
	printf 'Error: checksum for %s not found in %s\n' "$archive" "$sha256sums_path" >&2
	exit 1
fi

printf '%s  %s\n' "$expected_sha256" "$archive" | (cd "$downloads_dir" && sha256sum -c -)

if [ ! -d "$imagebuilder_dir" ]; then
	mkdir -p "$imagebuilder_dir"
	tar --zstd -xf "$archive_path" --strip-components=1 -C "$imagebuilder_dir"
fi

rm -rf "$output_dir"
mkdir -p "$output_dir"

make -C "$imagebuilder_dir" image \
	PROFILE="$OPENWRT_PROFILE" \
	PACKAGES="$OPENWRT_PACKAGES" \
	FILES="$stage_dir" \
	BIN_DIR="$output_dir"

printf 'Build complete. Artifacts in: %s\n' "$output_dir"
