#!/usr/bin/env bash
# Build Open Fliqlo Flutter Web with Wasm (plus JS fallback).
# Output: apps/open_fliqlo/build/web
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/apps/open_fliqlo"

cd "${APP}"

flutter config --enable-web >/dev/null
flutter pub get

# --wasm: emit dart2wasm + dart2js fallback
# --csp: avoid inline scripts (required for browser extensions)
# --no-web-resources-cdn: keep canvaskit/skwasm local
# --pwa-strategy=none: skip Flutter service worker (breaks chrome-extension://)
flutter build web --release --wasm \
  --csp \
  --no-web-resources-cdn \
  --pwa-strategy=none

echo "Built: ${APP}/build/web"
