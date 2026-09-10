#!/usr/bin/env bash
# Install Open Fliqlo Lock Screen into ~/.local/share/gnome-shell/extensions/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UUID="open-fliqlo-lockscreen@openfliqlo"
SCHEMA="org.gnome.shell.extensions.open-fliqlo-lockscreen"
SRC="${SCRIPT_DIR}/${UUID}"
DEST="${HOME}/.local/share/gnome-shell/extensions/${UUID}"

if [[ ! -d "${SRC}" ]]; then
  echo "Extension source not found: ${SRC}" >&2
  exit 1
fi

if ! command -v glib-compile-schemas >/dev/null 2>&1; then
  echo "glib-compile-schemas is required (package glib2-devel / libglib2.0-dev)" >&2
  exit 1
fi

mkdir -p "${DEST}"
rsync -a --delete \
  --exclude='.git' \
  "${SRC}/" "${DEST}/"

glib-compile-schemas "${DEST}/schemas"

if command -v restorecon >/dev/null 2>&1; then
  restorecon -Rv "${DEST}" >/dev/null || true
fi

# Prefill binary-path — GNOME Shell PATH often omits ~/.local/bin.
resolve_binary() {
  local candidates=(
    "${HOME}/.local/bin/open_fliqlo"
    "${HOME}/.local/OpenFliqlo-linux-x64-v0.0.1/open_fliqlo"
    "${HOME}/.local/share/open_fliqlo/open_fliqlo"
    "/usr/local/bin/open_fliqlo"
    "/usr/bin/open_fliqlo"
  )
  # shellcheck disable=SC2012
  for d in "${HOME}"/.local/OpenFliqlo-linux*/; do
    [[ -d "$d" ]] || continue
    candidates+=("${d}open_fliqlo")
  done
  if command -v open_fliqlo >/dev/null 2>&1; then
    candidates+=("$(command -v open_fliqlo)")
  fi

  local c real
  for c in "${candidates[@]}"; do
    [[ -e "$c" ]] || continue
    real="$(readlink -f "$c" 2>/dev/null || echo "$c")"
    if [[ -x "$real" ]]; then
      echo "$real"
      return 0
    fi
  done
  return 1
}

if BIN="$(resolve_binary)"; then
  GSETTINGS_SCHEMA_DIR="${DEST}/schemas" \
    gsettings set "${SCHEMA}" binary-path "${BIN}" 2>/dev/null \
    && echo "Set binary-path=${BIN}" \
    || echo "Could not write gsettings (ok if Shell has not loaded the schema yet)."
else
  echo "WARNING: open_fliqlo not found. Set the path in extension preferences." >&2
fi

echo "Installed to ${DEST}"
echo
echo "1. Turn the extension ON in Extension Manager (or):"
echo "     gnome-extensions enable ${UUID}"
echo "2. If this is the first install this session: log out and back in."
echo "3. Lock with Super+L to test."
echo
echo "Prefs: gnome-extensions prefs ${UUID}"
