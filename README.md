# Open Fliqlo

Cross-platform fullscreen flip clock for **iOS**, **Android**, **Windows**, and **Linux (GNOME / Wayland)**. Inspired by the classic Fliqlo aesthetic — large flipping digits on a black background.

> Not affiliated with Fliqlo®. P0 is a fullscreen app (not an OS screensaver).

## Features (P0)

- Flip clock `HH:MM` (+ optional seconds)
- Tap to toggle seconds · long-press for settings
- 12/24h, dim, scale, flaps
- Keep screen awake on mobile; fullscreen on desktop

## Structure

```
apps/open_fliqlo/       Flutter app
packages/fliqlo_core/   Clock engine + settings
packages/fliqlo_ui/     FlipDigit, ClockFace, SettingsSheet
docs/                   Behavior + Linux/GNOME notes
```

## Prerequisites

- Flutter stable (3.24+)
- For Linux desktop: GTK development packages (see [docs/linux-gnome.md](docs/linux-gnome.md))

## Setup

```bash
dart pub global activate melos
melos bootstrap
```

## Run

```bash
# Linux (GNOME/Wayland)
melos run run:linux
# or
cd apps/open_fliqlo && flutter run -d linux

# Windows
melos run run:windows

# Mobile
cd apps/open_fliqlo && flutter run -d <device>
```

## Test / analyze

```bash
melos run test
melos run analyze
```

## Fonts

Digit glyphs use [`gluqlo.ttf`](packages/fliqlo_ui/fonts/gluqlo.ttf) from [Gluqlo](https://github.com/alexanderk23/gluqlo) (ISC; © Kuźniarski Jacek, Alexander Kovalenko) — see [packages/fliqlo_ui/fonts/LICENSE-gluqlo.txt](packages/fliqlo_ui/fonts/LICENSE-gluqlo.txt).

## License

MIT — see [LICENSE](LICENSE).
