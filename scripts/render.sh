#!/usr/bin/env bash
set -euo pipefail

rm -rf "${BUILD_DIR:?}/generated" "${OVERLAY_DIR:?}"

gomplate \
  --datasource config=config/router.yaml \
  --datasource secrets=stdin:///secrets.yaml \
  --input-dir templates \
  --output-map '{{ env.Getenv "OVERLAY_DIR" }}/{{ strings.TrimSuffix ".tmpl" .in }}'

chmod 700 "$OVERLAY_DIR/etc/uci-defaults/99-service"
