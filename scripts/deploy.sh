#!/usr/bin/env bash
set -euo pipefail

config_value() {
  gomplate \
    --datasource config=config/router.yaml \
    --in "{{ (ds \"config\").build.$1 }}"
}

openwrt_version="$(config_value openwrt_version)"
target="$(config_value target)"
subtarget="$(config_value subtarget)"
profile="$(config_value profile)"

router_host="$(config_value router.host)"
router_user="$(config_value router.user)"
router_port="$(config_value router.port)"

artifact_name="openwrt-$openwrt_version-$target-$subtarget-$profile-squashfs-sysupgrade.bin"
artifact_path="build/artifacts/$artifact_name"

remote_path="/tmp/sysupgrade.bin"
destination="$router_user@$router_host"

ssh_opts=(
  -o BatchMode=yes
  -o ConnectTimeout=10
  -p "$router_port"
)

scp_opts=(
  -O
  -o BatchMode=yes
  -o ConnectTimeout=10
  -P "$router_port"
)

if [ ! -f "$artifact_path" ]; then
  printf 'Error: expected sysupgrade image not found: %s\n' "$artifact_path" >&2
  printf 'Run `task build` first.\n' >&2
  exit 1
fi

printf 'Target:   %s:%s\n' "$destination" "$router_port"
printf 'Artifact: %s\n' "$artifact_path"

printf 'Uploading firmware\n'
scp "${scp_opts[@]}" \
  "$artifact_path" \
  "$destination:$remote_path"

printf 'Validating firmware\n'
ssh "${ssh_opts[@]}" \
  "$destination" \
  "sysupgrade -T '$remote_path'"

printf 'Starting sysupgrade -n\n'

if ssh "${ssh_opts[@]}" \
  "$destination" \
  "sysupgrade -n '$remote_path'"; then

  printf 'Sysupgrade completed successfully.\n'
else
  status=$?

  if [ "$status" -eq 255 ]; then
    printf 'SSH connection closed while router is rebooting.\n'
  else
    printf 'Error: sysupgrade/SSH exited with status %d.\n' "$status" >&2
    exit "$status"
  fi
fi
