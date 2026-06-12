#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${NETLAB_ROOT:-$(CDPATH='' cd -- "$script_dir/.." && pwd)}"

# shellcheck source=/dev/null
source "$repo_root/config/openwrt.env"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

releases_url="https://downloads.openwrt.org/releases/"
releases_html="$tmp_dir/releases.html"
curl -fsSL "$releases_url" -o "$releases_html"

latest_version="$(sed -n 's|.*href="\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)/".*|\1|p' "$releases_html" | sort -V | tail -n 1)"

if [ -z "$latest_version" ]; then
	printf 'Error: could not determine latest OpenWrt release from %s\n' "$releases_url" >&2
	exit 1
fi

update_available=false
if [ "$OPENWRT_VERSION" != "$latest_version" ]; then
	update_available=true
fi

imagebuilder_sha256=""
if [ "$update_available" = true ]; then
	archive="openwrt-imagebuilder-$latest_version-$OPENWRT_TARGET-$OPENWRT_SUBTARGET.$OPENWRT_HOST_SUFFIX.tar.zst"
	sha256_url="https://downloads.openwrt.org/releases/$latest_version/targets/$OPENWRT_TARGET/$OPENWRT_SUBTARGET/sha256sums"
	sha256sums="$tmp_dir/sha256sums"
	curl -fsSL "$sha256_url" -o "$sha256sums"
	imagebuilder_sha256="$(awk -v file="$archive" '{ name=$2; sub(/^\*/, "", name); if (name == file) { print $1; exit } }' "$sha256sums")"

	if [ -z "$imagebuilder_sha256" ]; then
		printf 'Error: checksum for %s not found in %s\n' "$archive" "$sha256_url" >&2
		exit 1
	fi
fi

printf 'CURRENT_OPENWRT_VERSION=%s\n' "$OPENWRT_VERSION"
printf 'LATEST_OPENWRT_VERSION=%s\n' "$latest_version"
printf 'OPENWRT_UPDATE_AVAILABLE=%s\n' "$update_available"
printf 'OPENWRT_IMAGEBUILDER_SHA256=%s\n' "$imagebuilder_sha256"
