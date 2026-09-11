#!/usr/bin/env bash
# Package Flutter web build for Cloudflare Pages + Chrome/Firefox extensions.
#
# Usage:
#   ./scripts/pack_web_targets.sh [OUT_DIR] [VERSION]
#
# Expects apps/open_fliqlo/build/web from scripts/build_web_wasm.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_BUILD="${ROOT}/apps/open_fliqlo/build/web"
OUT_DIR="${1:-${ROOT}/dist/web}"
VERSION="${2:-0.1.0}"
EXT_SRC="${ROOT}/platforms/browser_extension"

if [[ ! -d "${WEB_BUILD}" ]]; then
  echo "Missing web build: ${WEB_BUILD}" >&2
  echo "Run scripts/build_web_wasm.sh first." >&2
  exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "zip is required" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/cloudflare-pages" \
  "${OUT_DIR}/chrome-extension" \
  "${OUT_DIR}/firefox-extension"

# --- Cloudflare Pages (hosted web) ---
cp -a "${WEB_BUILD}/." "${OUT_DIR}/cloudflare-pages/"
cp "${ROOT}/packaging/web/_headers" "${OUT_DIR}/cloudflare-pages/_headers"

# --- Shared helper: stage extension from web build + overlay manifest ---
stage_extension() {
  local browser="$1"
  local dest="${OUT_DIR}/${browser}-extension"
  local manifest="${EXT_SRC}/${browser}/manifest.json"

  cp -a "${WEB_BUILD}/." "${dest}/"
  # Extension uses its own MV3 manifest (not the PWA web manifest).
  rm -f "${dest}/manifest.json" "${dest}/flutter_service_worker.js"
  cp "${manifest}" "${dest}/manifest.json"

  # Chrome/Firefox require 1–4 numeric components (no semver "+" build metadata).
  python3 - "${dest}/manifest.json" "${VERSION}" <<'PY'
import json, re, sys
path, raw = sys.argv[1], sys.argv[2]
raw = raw.lstrip("v")
m = re.match(r"^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?", raw)
if not m:
    raise SystemExit(f"Cannot derive extension version from {raw!r}")
parts = [p for p in m.groups() if p is not None]
while len(parts) < 3:
    parts.append("0")
ext_version = ".".join(parts[:4])
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data["version"] = ext_version
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"extension version {raw} -> {ext_version}")
PY

  # Drop Flutter PWA link — extension pages should not advertise web manifest.
  python3 - "${dest}/index.html" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace('<link rel="manifest" href="manifest.json">', "")
path.write_text(text, encoding="utf-8")
PY
}

stage_extension chrome
stage_extension firefox

# Verify required extension bits
for browser in chrome firefox; do
  python3 - "${OUT_DIR}/${browser}-extension/manifest.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    m = json.load(f)
assert m.get("manifest_version") == 3, path
assert "chrome_url_overrides" in m and "newtab" in m["chrome_url_overrides"], path
csp = m.get("content_security_policy", {}).get("extension_pages", "")
assert "wasm-unsafe-eval" in csp, f"CSP missing wasm-unsafe-eval: {path}"
print(f"OK {path} version={m.get('version')}")
PY
done

# Zip store-ready packages
(
  cd "${OUT_DIR}/chrome-extension"
  zip -r -q "../OpenFliqlo-chrome-extension-${VERSION}.zip" .
)
(
  cd "${OUT_DIR}/firefox-extension"
  zip -r -q "../OpenFliqlo-firefox-extension-${VERSION}.zip" .
)

# Hosted site tarball (optional artifact; CF deploy uses the folder)
(
  cd "${OUT_DIR}"
  tar -czf "OpenFliqlo-web-${VERSION}.tar.gz" -C cloudflare-pages .
)

echo "Packaged under ${OUT_DIR}:"
find "${OUT_DIR}" -maxdepth 1 -type f | sort
