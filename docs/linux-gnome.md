# Linux — GNOME on Wayland

Open Fliqlo’s primary Linux QA target is **GNOME Shell on Wayland**.

## Run

```bash
cd apps/open_fliqlo
flutter run -d linux
```

Or from the repo root (after Melos bootstrap):

```bash
melos run run:linux
```

## Expectations

- App starts in fullscreen with a hidden title bar.
- Esc exits fullscreen; F11 toggles fullscreen.
- Fractional scaling (125% / 150%) should keep digits sharp via Flutter’s rasterizer; if digits look soft, check GNOME Settings → Displays → Scale.
- Keep-awake uses `wakelock_plus` (best-effort on desktop).

## Out of scope (P0)

- KDE Plasma, Hyprland, Sway, and X11 sessions are best-effort only.
- No xscreensaver / GNOME screensaver plugin integration yet.

## Screen saver on GNOME

See [screensaver-gnome.md](screensaver-gnome.md) for `--screensaver`, the idle-launch script, and `.desktop` entry.
