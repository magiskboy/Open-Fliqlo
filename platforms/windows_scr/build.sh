#!/usr/bin/env bash
# Build Flutter Windows release + OpenFliqlo.scr (requires Windows host or CI).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT/apps/open_fliqlo"
SCR="$ROOT/platforms/windows_scr"
OUT="$ROOT/dist/windows-screensaver"

echo "Building Flutter Windows release..."
(cd "$APP" && flutter build windows --release)

FLUTTER_OUT="$APP/build/windows/x64/runner/Release"
mkdir -p "$OUT"
cp -a "$FLUTTER_OUT/." "$OUT/"

if command -v dotnet >/dev/null 2>&1; then
  echo "Building SCR host with dotnet..."
  (cd "$SCR" && dotnet publish -c Release -r win-x64 --self-contained false -o "$SCR/bin")
  cp "$SCR/bin/OpenFliqlo.exe" "$OUT/OpenFliqlo.scr"
  echo "Wrote $OUT/OpenFliqlo.scr"
else
  echo "dotnet not found — copy OpenFliqlo.scr manually after building platforms/windows_scr on Windows."
  echo "Flutter payload is in $OUT"
fi

echo "Done. Install: place contents of $OUT on Windows and select OpenFliqlo.scr as the screen saver."
