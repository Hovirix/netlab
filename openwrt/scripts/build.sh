#!/usr/bin/env bash
# shellcheck source=./common.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

require_cmd make

if [ ! -d "$IMAGE_BUILDER_DIR" ]; then
	printf 'Error: image builder directory "%s" not found. Run setup first.\n' "$IMAGE_BUILDER_DIR" >&2
	exit 1
fi

if [ ! -f "$CONFIG_DIR/network" ] || [ ! -f "$CONFIG_DIR/wireless" ]; then
	printf 'Error: rendered config files missing in %s. Run render first.\n' "$CONFIG_DIR" >&2
	exit 1
fi

printf 'Building OpenWrt image using %s\n' "$IMAGE_BUILDER"
make -C "$IMAGE_BUILDER_DIR" image \
	PROFILE="$OPENWRT_PROFILE" \
	PACKAGES="$OPENWRT_PACKAGES" \
	FILES="$FILES_DIR"

output_dir="$IMAGE_BUILDER_DIR/bin/targets/$OPENWRT_TARGET/$OPENWRT_SUBTARGET"
if [ ! -d "$output_dir" ]; then
	printf 'Error: output directory not found: %s\n' "$output_dir" >&2
	exit 1
fi

if ! ls "$output_dir"/*.bin >/dev/null 2>&1 && ! ls "$output_dir"/*.itb >/dev/null 2>&1; then
	printf 'Error: no firmware artifacts found in %s\n' "$output_dir" >&2
	exit 1
fi

printf 'Build complete. Artifacts in: %s\n' "$output_dir"
