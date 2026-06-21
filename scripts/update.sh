#!/usr/bin/env bash
set -euo pipefail

if [ -n "${NETLAB_ROOT:-}" ]; then
  repo_root="$NETLAB_ROOT"
else
  repo_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")"
fi
cd "$repo_root"

config_file="$repo_root/config/router.yaml"
build_dir="${BUILD_DIR:-$repo_root/build}"
downloads_dir="$build_dir/downloads"
host_suffix="Linux-x86_64"

target="$(gomplate --datasource config=file://$config_file --in '{{ (ds "config").build.target }}')"
subtarget="$(gomplate --datasource config=file://$config_file --in '{{ (ds "config").build.subtarget }}')"
current_version="$(gomplate --datasource config=file://$config_file --in '{{ (ds "config").build.openwrt_version }}')"

latest_version="$(
  python3 - <<'PY'
from html.parser import HTMLParser
from urllib.request import urlopen
import re

class LinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        attrs = dict(attrs)
        href = attrs.get("href", "")
        self.links.append(href.rstrip("/"))

parser = LinkParser()
with urlopen("https://downloads.openwrt.org/releases/", timeout=60) as response:
    parser.feed(response.read().decode("utf-8", errors="replace"))

versions = []
for link in parser.links:
    if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", link):
        versions.append(tuple(int(part) for part in link.split(".")))

if not versions:
    raise SystemExit("no OpenWrt release versions found")

print(".".join(str(part) for part in max(versions)))
PY
)"

if [ "$latest_version" = "$current_version" ]; then
  printf 'OpenWrt is already current: %s\n' "$current_version"
  exit 0
fi

imagebuilder="openwrt-imagebuilder-$latest_version-$target-$subtarget.$host_suffix"
archive="$imagebuilder.tar.zst"
base_url="https://downloads.openwrt.org/releases/$latest_version/targets/$target/$subtarget"
archive_url="$base_url/$archive"
archive_path="$downloads_dir/$archive"

mkdir -p "$downloads_dir"

printf 'Current OpenWrt: %s\n' "$current_version"
printf 'Latest OpenWrt:  %s\n' "$latest_version"
printf 'ImageBuilder:    %s\n' "$archive_url"

curl -fL "$archive_url" -o "$archive_path"
imagebuilder_hash="$(nix hash file "$archive_path")"

python3 - "$config_file" "$latest_version" "$imagebuilder_hash" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
version = sys.argv[2]
imagebuilder_hash = sys.argv[3]

lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
in_build = False
updated_version = False
updated_hash = False

for index, line in enumerate(lines):
    stripped = line.strip()
    if line.startswith("build:"):
        in_build = True
        continue
    if in_build and line and not line.startswith(" ") and stripped:
        in_build = False
    if not in_build:
        continue
    newline = "\n" if line.endswith("\n") else ""
    if stripped.startswith("openwrt_version:"):
        lines[index] = f"  openwrt_version: {version}{newline}"
        updated_version = True
    elif stripped.startswith("imagebuilder_hash:"):
        lines[index] = f"  imagebuilder_hash: {imagebuilder_hash}{newline}"
        updated_hash = True

if not updated_version or not updated_hash:
    raise SystemExit("failed to update OpenWrt metadata in config/router.yaml")

path.write_text("".join(lines), encoding="utf-8")
PY

printf 'Updated config/router.yaml to OpenWrt %s with ImageBuilder hash %s\n' "$latest_version" "$imagebuilder_hash"
