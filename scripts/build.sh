#!/usr/bin/env bash
set -euo pipefail

downloads_dir="build/downloads"
imagebuilder_dir="build/imagebuilder"
artifacts_dir="build/artifacts"
overlay_dir="build/files"

config_datasource="config=config/router.yaml"

openwrt_version="$(gomplate --datasource "$config_datasource" --in '{{ (ds "config").build.openwrt_version }}')"
target="$(gomplate --datasource "$config_datasource" --in '{{ (ds "config").build.target }}')"
subtarget="$(gomplate --datasource "$config_datasource" --in '{{ (ds "config").build.subtarget }}')"
profile="$(gomplate --datasource "$config_datasource" --in '{{ (ds "config").build.profile }}')"
packages="$(gomplate --datasource "$config_datasource" --in '{{ range $pkg := (ds "config").build.packages }}{{ $pkg }} {{ end }}')"
packages="${packages% }"
expected_hash="$(gomplate --datasource "$config_datasource" --in '{{ (ds "config").build.imagebuilder_hash }}')"

imagebuilder="openwrt-imagebuilder-$openwrt_version-$target-$subtarget.Linux-x86_64"
archive="$imagebuilder.tar.zst"
base_url="https://downloads.openwrt.org/releases/$openwrt_version/targets/$target/$subtarget"
archive_path="$downloads_dir/$archive"

artifact_name="openwrt-$openwrt_version-$target-$subtarget-$profile-squashfs-sysupgrade.bin"
artifact_path="$imagebuilder_dir/bin/targets/$target/$subtarget/$artifact_name"

trap 'rm -f "$archive_path.tmp" build/.rootfs build/.rootfs-list' EXIT

download_archive() {
  rm -f "$archive_path.tmp"

  curl \
    --fail \
    --location \
    --retry 3 \
    --retry-all-errors \
    "$base_url/$archive" \
    --output "$archive_path.tmp"

  mv "$archive_path.tmp" "$archive_path"
}

verify_archive() {
  if [ ! -f "$archive_path" ]; then
    return 1
  fi

  [ "$(nix hash file "$archive_path")" = "$expected_hash" ]
}

verify_overlay() {
  for file in \
    etc/config/network \
    etc/config/dhcp \
    etc/config/firewall \
    etc/config/wireless \
    etc/config/dropbear \
    etc/dropbear/authorized_keys \
    etc/adguardhome/adguardhome.yaml \
    etc/crontabs/root \
    etc/uci-defaults/99-service; do

    if ! grep -Fxq "squashfs-root/$file" build/.rootfs-list; then
      printf 'Error: sysupgrade image is missing overlay file: %s\n' "$file" >&2
      exit 1
    fi
  done
}

if [ ! -d "$overlay_dir" ]; then
  printf 'Error: rendered overlay not found: %s\n' "$overlay_dir" >&2
  exit 1
fi

mkdir -p "$downloads_dir"

if ! verify_archive; then
  rm -f "$archive_path"
  download_archive

  if ! verify_archive; then
    actual_hash="$(nix hash file "$archive_path")"

    printf 'Error: ImageBuilder hash mismatch\n' >&2
    printf 'Expected: %s\n' "$expected_hash" >&2
    printf 'Actual:   %s\n' "$actual_hash" >&2
    exit 1
  fi
fi

rm -rf "$imagebuilder_dir"
mkdir -p "$imagebuilder_dir"

tar \
  --zstd \
  -xf "$archive_path" \
  --strip-components=1 \
  -C "$imagebuilder_dir"

make -C "$imagebuilder_dir" image \
  PROFILE="$profile" \
  PACKAGES="$packages" \
  FILES="../files"

if [ ! -f "$artifact_path" ]; then
  printf 'Error: build completed but expected artifact was not produced: %s\n' \
    "$artifact_path" >&2
  exit 1
fi

if ! tar \
  -xOf "$artifact_path" \
  "sysupgrade-$profile/root" \
  >build/.rootfs; then

  printf 'Error: failed to extract root filesystem from: %s\n' \
    "$artifact_path" >&2
  exit 1
fi

unsquashfs="$imagebuilder_dir/staging_dir/host/bin/unsquashfs4"

if [ ! -x "$unsquashfs" ]; then
  printf 'Error: unsquashfs tool not found: %s\n' "$unsquashfs" >&2
  exit 1
fi

"$unsquashfs" -l build/.rootfs >build/.rootfs-list

verify_overlay

rm -rf "$artifacts_dir"
mkdir -p "$artifacts_dir"
chmod 700 "$artifacts_dir"

install \
  -m 600 \
  "$artifact_path" \
  "$artifacts_dir/$artifact_name"

printf 'Build complete. Artifact: %s/%s\n' \
  "$artifacts_dir" "$artifact_name"
