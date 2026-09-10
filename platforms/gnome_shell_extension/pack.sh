#!/usr/bin/env bash
# Pack Open Fliqlo Lock Screen as a GNOME Shell extension zip.
# Layout matches extensions.gnome.org / `gnome-extensions install`:
# files live at the zip root (not nested under the UUID directory).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UUID="open-fliqlo-lockscreen@openfliqlo"
SRC="${SCRIPT_DIR}/${UUID}"
OUT_DIR="${1:-${SCRIPT_DIR}/dist}"
ZIP_NAME="${UUID}.shell-extension.zip"

if [[ ! -d "${SRC}" ]]; then
  echo "Extension source not found: ${SRC}" >&2
  exit 1
fi

if [[ ! -f "${SRC}/metadata.json" ]]; then
  echo "Missing metadata.json in ${SRC}" >&2
  exit 1
fi

if ! command -v glib-compile-schemas >/dev/null 2>&1; then
  echo "glib-compile-schemas is required (package glib2-devel / libglib2.0-dev)" >&2
  exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "zip is required" >&2
  exit 1
fi

# Basic metadata checks (fail CI early without a full GNOME session).
python3 - "${SRC}/metadata.json" "${UUID}" <<'PY'
import json, sys
path, expected_uuid = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    meta = json.load(f)
errors = []
if meta.get("uuid") != expected_uuid:
    errors.append(f"uuid must be {expected_uuid!r}, got {meta.get('uuid')!r}")
if "unlock-dialog" not in meta.get("session-modes", []):
    errors.append("session-modes must include 'unlock-dialog'")
shell = meta.get("shell-version")
if not isinstance(shell, list) or not shell:
    errors.append("shell-version must be a non-empty list")
if not meta.get("settings-schema"):
    errors.append("settings-schema is required")
if errors:
    print("metadata.json validation failed:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)
print(f"metadata ok: uuid={meta['uuid']} shell-version={shell} version-name={meta.get('version-name', '?')}")
PY

STAGE="$(mktemp -d)"
cleanup() { rm -rf "${STAGE}"; }
trap cleanup EXIT

STAGE_EXT="${STAGE}/${UUID}"
mkdir -p "${STAGE_EXT}"
# Prefer rsync; fall back to cp -a for minimal runners.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude='.git' "${SRC}/" "${STAGE_EXT}/"
else
  cp -a "${SRC}/." "${STAGE_EXT}/"
fi

glib-compile-schemas "${STAGE_EXT}/schemas"

mkdir -p "${OUT_DIR}"
OUT_ZIP="$(cd "${OUT_DIR}" && pwd)/${ZIP_NAME}"
rm -f "${OUT_ZIP}"

# Zip contents at root (EGO / gnome-extensions install convention).
(cd "${STAGE_EXT}" && zip -r -q "${OUT_ZIP}" .)

echo "Packed ${OUT_ZIP}"
ls -la "${OUT_ZIP}"
