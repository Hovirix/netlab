{ pkgs, config, ... }:

let
  inherit (config)
    openwrtVersion
    openwrtTarget
    openwrtSubtarget
    openwrtProfile
    routerHost
    routerUser
    routerPort
    ;
  appSysupgrade = pkgs.writeShellApplication {
    name = "sysupgrade";

    runtimeInputs = [
      pkgs.openssh
      pkgs.coreutils
    ];

    text = ''
      set -euo pipefail

      output_dir="''${BUILD_OUTPUT_DIR:-$PWD/build-output}"
      artifact_dir="$output_dir/targets/${openwrtTarget}/${openwrtSubtarget}"
      artifact_glob="openwrt-${openwrtVersion}-${openwrtTarget}-${openwrtSubtarget}-${openwrtProfile}-squashfs-sysupgrade.*"
      artifact_path=""

      for candidate in "$artifact_dir"/$artifact_glob; do
        if [ -f "$candidate" ]; then
          artifact_path="$candidate"
          break
        fi
      done

      if [ -z "$artifact_path" ]; then
        printf 'Error: expected sysupgrade image not found matching: %s/%s\n' "$artifact_dir" "$artifact_glob" >&2
        exit 1
      fi

      artifact_name="$(basename "$artifact_path")"
      remote_path="/tmp/$artifact_name"

      printf 'Uploading firmware to %s@%s:%s\n' \
        "${routerUser}" \
        "${routerHost}" \
        "$remote_path"

      scp -O \
        -P "${routerPort}" \
        "$artifact_path" \
        "${routerUser}@${routerHost}:$remote_path"

      printf '\n!!! WARNING: This will reboot the router. Do not power it off during upgrade. !!!\n\n'

      read -r -p 'Are you sure you want to run sysupgrade? [y/N] ' confirm

      if [[ $confirm != [yY] ]]; then
        printf 'Aborted. Firmware was uploaded to %s\n' "$remote_path"
        exit 1
      fi

      printf 'Running sysupgrade on router with factory-reset mode (-n)\n'

      ssh \
        -p "${routerPort}" \
        "${routerUser}@${routerHost}" \
        "sysupgrade -n '$remote_path'"
    '';
  };

in
{
  apps.sysupgrade = {
    type = "app";
    program = "${appSysupgrade}/bin/sysupgrade";
    meta.description = "Deploy OpenWrt sysupgrade image";
  };
}
