#!/usr/bin/env bash
set -euo pipefail

if [ -n "${NETLAB_ROOT:-}" ]; then
  repo_root="$NETLAB_ROOT"
else
  repo_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")"
fi
cd "$repo_root"

build_dir="${BUILD_DIR:-$repo_root/build}"
artifacts_dir="$build_dir/artifacts"

openwrt_version="$(gomplate --datasource config=file://$repo_root/config/router.yaml --in '{{ (ds "config").build.openwrt_version }}')"
target="$(gomplate --datasource config=file://$repo_root/config/router.yaml --in '{{ (ds "config").build.target }}')"
subtarget="$(gomplate --datasource config=file://$repo_root/config/router.yaml --in '{{ (ds "config").build.subtarget }}')"
profile="$(gomplate --datasource config=file://$repo_root/config/router.yaml --in '{{ (ds "config").build.profile }}')"
router_host="$(gomplate --datasource config=file://$repo_root/config/router.yaml --in '{{ (ds "config").build.router.host }}')"
router_user="$(gomplate --datasource config=file://$repo_root/config/router.yaml --in '{{ (ds "config").build.router.user }}')"
router_port="$(gomplate --datasource config=file://$repo_root/config/router.yaml --in '{{ (ds "config").build.router.port }}')"

artifact_glob="openwrt-$openwrt_version-$target-$subtarget-$profile-squashfs-sysupgrade.*"
artifact_path=""

for candidate in "$artifacts_dir"/$artifact_glob; do
  if [ -f "$candidate" ]; then
    artifact_path="$candidate"
    break
  fi
done

if [ -z "$artifact_path" ]; then
  printf 'Error: expected sysupgrade image not found matching: %s/%s\n' "$artifacts_dir" "$artifact_glob" >&2
  printf 'Run `just build` first.\n' >&2
  exit 1
fi

artifact_name="$(basename "$artifact_path")"
remote_path="/tmp/$artifact_name"

printf 'Target router: %s@%s:%s\n' "$router_user" "$router_host" "$router_port"
printf 'Artifact: %s\n' "$artifact_path"
printf 'Remote path: %s\n\n' "$remote_path"
printf 'WARNING: sysupgrade -n will flash the image, reset config, and reboot the router.\n\n'

read -r -p 'Continue with upload and sysupgrade? [y/N] ' confirm
if [[ $confirm != [yY] ]]; then
  printf 'Aborted.\n'
  exit 1
fi

printf 'Uploading firmware with scp -O\n'
scp -O -P "$router_port" "$artifact_path" "$router_user@$router_host:$remote_path"

printf 'Running sysupgrade -n on router\n'
ssh -p "$router_port" "$router_user@$router_host" "sysupgrade -n '$remote_path'"
