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
  -q
  -o BatchMode=yes
  -o ConnectTimeout=10
  -P "$router_port"
)

if [ ! -f "$artifact_path" ]; then
  printf 'Error: expected sysupgrade image not found: %s\n' "$artifact_path" >&2
  printf 'Run `task build` first.\n' >&2
  exit 1
fi

printf 'Deploying %s to %s:%s\n' "$artifact_name" "$destination" "$router_port"

printf 'Uploading firmware... '
scp "${scp_opts[@]}" \
  "$artifact_path" \
  "$destination:$remote_path"
printf 'ok\n'

printf 'Validating firmware... '
ssh "${ssh_opts[@]}" \
  "$destination" \
  "sysupgrade -T '$remote_path' >/dev/null"
printf 'ok\n'

printf 'Starting sysupgrade... '

if upgrade_output="$(ssh "${ssh_opts[@]}" \
  "$destination" \
  "sysupgrade -n '$remote_path'" 2>&1)"; then

  printf 'router is rebooting.\n'
else
  status=$?

  case "$status" in
  246)
    # ubus exits with -10 after sysupgrade stops it, which the shell reports as 246.
    printf 'router is rebooting.\n'
    ;;
  255)
    printf 'router is rebooting.\n'
    ;;
  *)
    printf 'failed\n' >&2
    printf '%s\n' "$upgrade_output" >&2
    printf 'Error: sysupgrade/SSH exited with status %d.\n' "$status" >&2
    exit "$status"
    ;;
  esac
fi
