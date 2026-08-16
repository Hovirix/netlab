#!/usr/bin/env bash
set -euo pipefail

downloads_dir="build/downloads"
imagebuilder_dir="build/imagebuilder"
artifacts_dir="build/artifacts"
host_suffix="Linux-x86_64"
config_datasource="config=file://$PWD/config/router.yaml"

openwrt_version="$(gomplate --datasource "$config_datasource" --in '{{ (ds "config").build.openwrt_version }}')"
target="$(gomplate --datasource "$config_datasource" --in '{{ (ds "config").build.target }}')"
subtarget="$(gomplate --datasource "$config_datasource" --in '{{ (ds "config").build.subtarget }}')"
profile="$(gomplate --datasource "$config_datasource" --in '{{ (ds "config").build.profile }}')"
packages="$(gomplate --datasource "$config_datasource" --in '{{ range $pkg := (ds "config").build.packages }}{{ $pkg }} {{ end }}')"
packages="${packages% }"
expected_hash="$(gomplate --datasource "$config_datasource" --in '{{ (ds "config").build.imagebuilder_hash }}')"
imagebuilder="openwrt-imagebuilder-$openwrt_version-$target-$subtarget.$host_suffix"
archive="$imagebuilder.tar.zst"
base_url="https://downloads.openwrt.org/releases/$openwrt_version/targets/$target/$subtarget"
archive_path="$downloads_dir/$archive"

mkdir -p "$downloads_dir" "$artifacts_dir"

if [ ! -f "$archive_path" ]; then
  curl -fL "$base_url/$archive" -o "$archive_path"
fi

actual_hash="$(nix hash file "$archive_path")"
if [ "$actual_hash" != "$expected_hash" ]; then
  printf 'Error: ImageBuilder hash mismatch\nexpected: %s\nactual:   %s\n' "$expected_hash" "$actual_hash" >&2
  exit 1
fi

rm -rf "$imagebuilder_dir"
mkdir -p "$imagebuilder_dir"
tar --zstd -xf "$archive_path" --strip-components=1 -C "$imagebuilder_dir"
rm -rf "${artifacts_dir:?}"/*

make -C "$imagebuilder_dir" image \
  PROFILE="$profile" \
  PACKAGES="$packages" \
  FILES="build/files" \
  BIN_DIR="$artifacts_dir"

printf 'Build complete. Artifacts in: %s\n' "$artifacts_dir"
