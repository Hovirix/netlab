#!/usr/bin/env bash
# shellcheck source=./common.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

require_cmd wget tar sha256sum

if [ -d "$IMAGE_BUILDER_DIR" ]; then
  printf 'Image builder already exists: %s\n' "$IMAGE_BUILDER_DIR"
  exit 0
fi

if [ ! -f "$ARCHIVE_PATH" ]; then
  printf 'Downloading image builder: %s\n' "$ARCHIVE_URL"
  wget -O "$ARCHIVE_PATH" "$ARCHIVE_URL"
fi

tmp_sha256="$(mktemp)"
cleanup() {
  rm -f "$tmp_sha256"
}
trap cleanup EXIT

printf 'Downloading checksums: %s\n' "$SHA256_URL"
wget -O "$tmp_sha256" "$SHA256_URL"

expected_sum="$(awk -v file="$ARCHIVE" '{ name=$2; sub(/^\*/, "", name); if (name == file) { print $1; exit } }' "$tmp_sha256")"
if [ -z "$expected_sum" ]; then
  printf 'Error: checksum for %s not found in %s\n' "$ARCHIVE" "$SHA256_URL" >&2
  exit 1
fi

actual_sum="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
if [ "$expected_sum" != "$actual_sum" ]; then
  printf 'Error: checksum mismatch for %s\n' "$ARCHIVE_PATH" >&2
  printf 'Expected: %s\n' "$expected_sum" >&2
  printf 'Actual:   %s\n' "$actual_sum" >&2
  exit 1
fi

printf 'Checksum verified: %s\n' "$ARCHIVE"

printf 'Extracting archive: %s\n' "$ARCHIVE_PATH"
tar --zstd -xf "$ARCHIVE_PATH" -C "$REPO_ROOT"

[ -d "$IMAGE_BUILDER_DIR" ]

if [ "$KEEP_ARCHIVE" != "1" ]; then
  rm -f "$ARCHIVE_PATH"
  printf 'Removed archive: %s\n' "$ARCHIVE_PATH"
fi

printf 'Setup complete: %s\n' "$IMAGE_BUILDER_DIR"
