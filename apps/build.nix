{ pkgs, config, ... }:
let
  inherit (config) openwrtVersion;
  inherit (config) openwrtTarget;
  inherit (config) openwrtSubtarget;
  inherit (config) openwrtProfile;
  inherit (config) openwrtPackages;
  hostSuffix = "Linux-x86_64";
  imageBuilder = "openwrt-imagebuilder-${openwrtVersion}-${openwrtTarget}-${openwrtSubtarget}.${hostSuffix}";
  archive = "${imageBuilder}.tar.zst";
  baseUrl = "https://downloads.openwrt.org/releases/${openwrtVersion}/targets/${openwrtTarget}/${openwrtSubtarget}";

  imageBuilderArchive = pkgs.fetchurl {
    url = "${baseUrl}/${archive}";
    hash = config.imageBuilderHash;
  };

  imageBuilderStore = pkgs.stdenvNoCC.mkDerivation {
    pname = "${imageBuilder}-store";
    version = openwrtVersion;
    src = imageBuilderArchive;
    dontPatchShebangs = true;
    dontFixup = true;
    nativeBuildInputs = [
      pkgs.gnutar
      pkgs.zstd
    ];
    unpackPhase = "true";
    installPhase = ''
      mkdir -p "$out"
      tar --zstd -xf "$src" --strip-components=1 -C "$out"
    '';
  };

  appBuild = pkgs.writeShellApplication {
    name = "build";
    runtimeInputs = [
      pkgs.nix
      pkgs.sops
      pkgs.gomplate
      pkgs.gitMinimal
      pkgs.gnumake
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnutar
      pkgs.gzip
      pkgs.unzip
      pkgs.wget
    ];
    text = ''
      set -euo pipefail

      tmp_dir="$(mktemp -d)"
      trap 'rm -rf "$tmp_dir"' EXIT

      files_dir="$tmp_dir/files"
      config_dir="$files_dir/etc/config"
      adguardhome_dir="$files_dir/etc/adguardhome"
      repo_root="''${NETLAB_ROOT:-$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")}"
      network_secret="''${NETWORK_SECRET:-$repo_root/secrets/network.sops.yaml}"
      wireless_secret="''${WIRELESS_SECRET:-$repo_root/secrets/wireless.sops.yaml}"
      adguardhome_secret="''${ADGUARDHOME_SECRET:-$repo_root/secrets/adguardhome.sops.yaml}"

      if [ ! -r "$network_secret" ]; then
        printf 'Error: network secret file not found or unreadable: %s\n' "$network_secret" >&2
        exit 1
      fi
      if [ ! -r "$wireless_secret" ]; then
        printf 'Error: wireless secret file not found or unreadable: %s\n' "$wireless_secret" >&2
        exit 1
      fi
      if [ ! -r "$adguardhome_secret" ]; then
        printf 'Error: AdGuardHome secret file not found or unreadable: %s\n' "$adguardhome_secret" >&2
        exit 1
      fi

      printf 'Running repository checks before build\n'
      nix flake check

      cp -R "${../files}" "$files_dir"
      chmod -R u+w "$files_dir"
      mkdir -p "$config_dir"
      mkdir -p "$adguardhome_dir"

      network_yaml="$tmp_dir/network.yaml"
      wireless_yaml="$tmp_dir/wireless.yaml"
      adguardhome_yaml="$tmp_dir/adguardhome.yaml"
      sops -d "$network_secret" > "$network_yaml"
      sops -d "$wireless_secret" > "$wireless_yaml"
      sops -d "$adguardhome_secret" > "$adguardhome_yaml"

      printf 'Rendering OpenWrt config templates\n'
      gomplate \
        --datasource "network=file://$network_yaml" \
        --datasource "wireless=file://$wireless_yaml" \
        --datasource "adguardhome=file://$adguardhome_yaml" \
        --file "${../templates/network.tmpl}" \
        --out "$config_dir/network"

      gomplate \
        --datasource "network=file://$network_yaml" \
        --datasource "wireless=file://$wireless_yaml" \
        --datasource "adguardhome=file://$adguardhome_yaml" \
        --file "${../templates/wireless.tmpl}" \
        --out "$config_dir/wireless"

      gomplate \
        --datasource "adguardhome=file://$adguardhome_yaml" \
        --file "${../templates/adguardhome.yaml.tmpl}" \
        --out "$adguardhome_dir/adguardhome.yaml"

      build_root="$tmp_dir/imagebuilder"
      cp -R "${imageBuilderStore}" "$build_root"
      chmod -R u+w "$build_root"

      output_dir="''${BUILD_OUTPUT_DIR:-$repo_root/build-output}"
      rm -rf "$output_dir"
      mkdir -p "$output_dir"

      printf 'Building OpenWrt image using %s\n' "${imageBuilder}"
      make -C "$build_root" image \
        PROFILE='${openwrtProfile}' \
        PACKAGES='${openwrtPackages}' \
        FILES="$files_dir" \
        BIN_DIR="$output_dir"

      printf 'Build complete. Artifacts in: %s\n' "$output_dir"
    '';
  };
in
{
  apps.build = {
    type = "app";
    program = "${appBuild}/bin/build";
    meta.description = "Build OpenWrt firmware image";
  };
}
