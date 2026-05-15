{ pkgs, config, ... }:
let
  inherit (config) openwrtVersion;
  inherit (config) openwrtTarget;
  inherit (config) openwrtSubtarget;

  appCheckUpdate = pkgs.writeShellApplication {
    name = "check-update";
    runtimeInputs = [
      pkgs.curl
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnused
      pkgs.nix
    ];
    text = ''
      set -euo pipefail

      host_suffix="Linux-x86_64"
      releases_url="https://downloads.openwrt.org/releases/"
      tmp_dir="$(mktemp -d)"
      trap 'rm -rf "$tmp_dir"' EXIT

      releases_html="$tmp_dir/releases.html"
      curl -fsSL "$releases_url" -o "$releases_html"
      latest_version="$(sed -n 's|.*href="\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)/".*|\1|p' "$releases_html" | sort -V | tail -n 1)"

      if [ -z "$latest_version" ]; then
        printf 'Error: could not determine latest OpenWrt release from %s\n' "$releases_url" >&2
        exit 1
      fi

      update_available=false
      if [ "${openwrtVersion}" != "$latest_version" ]; then
        update_available=true
      fi

      imagebuilder_hash=""
      if [ "$update_available" = true ]; then
        archive="openwrt-imagebuilder-$latest_version-${openwrtTarget}-${openwrtSubtarget}.$host_suffix.tar.zst"
        sha256_url="https://downloads.openwrt.org/releases/$latest_version/targets/${openwrtTarget}/${openwrtSubtarget}/sha256sums"
        sha256sums="$tmp_dir/sha256sums"
        curl -fsSL "$sha256_url" -o "$sha256sums"
        expected_hex="$(awk -v file="$archive" '{ name=$2; sub(/^\*/, "", name); if (name == file) { print $1; exit } }' "$sha256sums")"

        if [ -z "$expected_hex" ]; then
          printf 'Error: checksum for %s not found in %s\n' "$archive" "$sha256_url" >&2
          exit 1
        fi

        imagebuilder_hash="$(nix hash to-sri --type sha256 "$expected_hex")"
      fi

      printf 'CURRENT_OPENWRT_VERSION=%s\n' '${openwrtVersion}'
      printf 'LATEST_OPENWRT_VERSION=%s\n' "$latest_version"
      printf 'OPENWRT_UPDATE_AVAILABLE=%s\n' "$update_available"
      printf 'IMAGEBUILDER_HASH=%s\n' "$imagebuilder_hash"
    '';
  };
in
{
  apps.check-update = {
    type = "app";
    program = "${appCheckUpdate}/bin/check-update";
    meta.description = "Check for newer OpenWrt releases";
  };
}
