# Open Fliqlo as a GNOME (Wayland) screensaver

GNOME on Wayland does **not** support classic `.scr` / xscreensaver modules. Open Fliqlo uses a fullscreen `--screensaver` mode plus an optional idle watcher.

## Quick test

```bash
cd apps/open_fliqlo
flutter run -d linux -a --screensaver
```

Or after a release build:

```bash
./build/linux/x64/release/bundle/open_fliqlo --screensaver
```

- Fullscreen flip clock, cursor hidden  
- Any mouse / keyboard / touch → process exits  

## Desktop entry

Install [packaging/linux/open-fliqlo-screensaver.desktop](../packaging/linux/open-fliqlo-screensaver.desktop) (adjust `Exec=` to your binary path):

```bash
install -Dm644 packaging/linux/open-fliqlo-screensaver.desktop \
  ~/.local/share/applications/open-fliqlo-screensaver.desktop
# Edit Exec= to the real path of open_fliqlo if it is not on PATH
```

You can pin it or run it from the app grid when you want a manual “screensaver”.

## Idle auto-launch (sample)

[packaging/linux/idle-launch-screensaver.sh](../packaging/linux/idle-launch-screensaver.sh) polls Mutter’s `IdleMonitor` and starts `--screensaver` after a threshold (default 5 minutes):

```bash
chmod +x packaging/linux/idle-launch-screensaver.sh
export OPEN_FLIQLO_BIN=/path/to/open_fliqlo
./packaging/linux/idle-launch-screensaver.sh 300000   # idle ms
```

Run from a user systemd service or GNOME Startup Applications if you want it always on.

## Keep-awake

While the clock runs, the app enables `wakelock_plus` (best-effort on desktop). Pair with GNOME power settings so the panel does not blank the display immediately if you want the clock visible.

## Out of scope

- X11 xscreensaver modules  
- GNOME Shell lock-screen extensions  
- Replacing GDM / unlock UI  

See also [linux-gnome.md](linux-gnome.md) for general Linux QA notes.
