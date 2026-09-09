#!/usr/bin/env bash
# Launch Open Fliqlo in screensaver mode when GNOME reports user idle.
# Requires: GNOME Shell / Mutter (Wayland or X11), dbus-send, and open_fliqlo on PATH
# (or set OPEN_FLIQLO_BIN to the binary path).
#
# Usage:
#   ./idle-launch-screensaver.sh [idle_ms]
# Default idle threshold: 300000 (5 minutes).

set -euo pipefail

IDLE_MS="${1:-300000}"
BIN="${OPEN_FLIQLO_BIN:-open_fliqlo}"
INTERVAL_S=5

if ! command -v dbus-send >/dev/null 2>&1; then
  echo "dbus-send is required" >&2
  exit 1
fi

get_idle_ms() {
  # Mutter IdleMonitor (GNOME)
  dbus-send --print-reply --dest=org.gnome.Mutter.IdleMonitor \
    /org/gnome/Mutter/IdleMonitor/Core \
    org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null \
    | awk '/uint64/ { print $2; exit }'
}

running_pid=""

echo "Watching GNOME idle (threshold ${IDLE_MS} ms). Binary: ${BIN}"

while true; do
  idle="$(get_idle_ms || true)"
  if [[ -z "${idle}" ]]; then
    echo "Could not read idle time from Mutter IdleMonitor; is GNOME running?" >&2
    sleep 15
    continue
  fi

  if (( idle >= IDLE_MS )); then
    if [[ -z "${running_pid}" ]] || ! kill -0 "${running_pid}" 2>/dev/null; then
      "${BIN}" --screensaver &
      running_pid=$!
      echo "Started screensaver (pid ${running_pid}) at idle=${idle}ms"
    fi
  else
    # User active again — if screensaver still running, leave it (it exits on input).
    running_pid=""
  fi

  sleep "${INTERVAL_S}"
done
