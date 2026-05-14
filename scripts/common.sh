#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

: "${OPENWRT_VERSION:?OPENWRT_VERSION must be set}"
: "${OPENWRT_TARGET:?OPENWRT_TARGET must be set}"
: "${OPENWRT_SUBTARGET:?OPENWRT_SUBTARGET must be set}"
: "${OPENWRT_PROFILE:?OPENWRT_PROFILE must be set}"
: "${OPENWRT_PACKAGES:?OPENWRT_PACKAGES must be set}"
KEEP_ARCHIVE="${KEEP_ARCHIVE:-1}"

detect_host_suffix() {
  local os arch

  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os-$arch" in
  Linux-x86_64)
    printf 'Linux-x86_64\n'
    ;;
  Darwin-arm64)
    printf 'Darwin-arm64\n'
    ;;
  Darwin-x86_64)
    printf 'Darwin-x86_64\n'
    ;;
  *)
    printf 'Error: unsupported host platform %s-%s\n' "$os" "$arch" >&2
    printf 'Set OPENWRT_IMAGE_BUILDER manually if you have a compatible archive.\n' >&2
    return 1
    ;;
  esac
}

HOST_SUFFIX="$(detect_host_suffix)"

if [ "$OPENWRT_VERSION" = "snapshots" ]; then
  DEFAULT_IMAGE_BUILDER="openwrt-imagebuilder-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}.${HOST_SUFFIX}"
  OPENWRT_DOWNLOAD_ROOT="snapshots"
else
  DEFAULT_IMAGE_BUILDER="openwrt-imagebuilder-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}.${HOST_SUFFIX}"
  OPENWRT_DOWNLOAD_ROOT="releases/${OPENWRT_VERSION}"
fi

IMAGE_BUILDER="${OPENWRT_IMAGE_BUILDER:-$DEFAULT_IMAGE_BUILDER}"
ARCHIVE="${IMAGE_BUILDER}.tar.zst"
BASE_URL="https://downloads.openwrt.org/${OPENWRT_DOWNLOAD_ROOT}/targets/${OPENWRT_TARGET}/${OPENWRT_SUBTARGET}"
ARCHIVE_URL="${BASE_URL}/${ARCHIVE}"
SHA256_URL="${BASE_URL}/sha256sums"

IMAGE_BUILDER_DIR="${REPO_ROOT}/${IMAGE_BUILDER}"
ARCHIVE_PATH="${REPO_ROOT}/${ARCHIVE}"
FILES_DIR="${REPO_ROOT}/files"
CONFIG_DIR="${FILES_DIR}/etc/config"

export OPENWRT_VERSION OPENWRT_TARGET OPENWRT_SUBTARGET OPENWRT_PROFILE OPENWRT_PACKAGES
export KEEP_ARCHIVE HOST_SUFFIX IMAGE_BUILDER ARCHIVE BASE_URL ARCHIVE_URL SHA256_URL
export IMAGE_BUILDER_DIR ARCHIVE_PATH FILES_DIR CONFIG_DIR REPO_ROOT

require_cmd() {
  local cmd

  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf 'Error: required command "%s" not found in PATH\n' "$cmd" >&2
      return 1
    fi
  done
}
