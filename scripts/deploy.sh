#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${NETLAB_ROOT:-$(CDPATH='' cd -- "$script_dir/.." && pwd)}"

# shellcheck source=/dev/null
source "$repo_root/config/openwrt.env"

build_dir="${BUILD_DIR:-$repo_root/build}"
output_dir="${BUILD_OUTPUT_DIR:-$build_dir/output}"
artifact_glob="openwrt-$OPENWRT_VERSION-$OPENWRT_TARGET-$OPENWRT_SUBTARGET-$OPENWRT_PROFILE-squashfs-sysupgrade.*"
artifact_path=""

for candidate in "$output_dir"/$artifact_glob; do
	if [ -f "$candidate" ]; then
		artifact_path="$candidate"
		break
	fi
done

if [ -z "$artifact_path" ]; then
	printf 'Error: expected sysupgrade image not found matching: %s/%s\n' "$output_dir" "$artifact_glob" >&2
	exit 1
fi

artifact_name="$(basename -- "$artifact_path")"
remote_path="/tmp/$artifact_name"

printf 'Uploading firmware to %s@%s:%s\n' "$ROUTER_USER" "$ROUTER_HOST" "$remote_path"
scp -O -P "$ROUTER_PORT" "$artifact_path" "$ROUTER_USER@$ROUTER_HOST:$remote_path"

printf '\n!!! WARNING: This will reboot the router. Do not power it off during upgrade. !!!\n\n'
read -r -p 'Are you sure you want to run sysupgrade? [y/N] ' confirm

if [[ $confirm != [yY] ]]; then
	printf 'Aborted. Firmware was uploaded to %s\n' "$remote_path"
	exit 1
fi

printf 'Running sysupgrade on router with factory-reset mode (-n)\n'
ssh -p "$ROUTER_PORT" "$ROUTER_USER@$ROUTER_HOST" "sysupgrade -n '$remote_path'"
