# Open Fliqlo

Cross-platform fullscreen flip clock for **iOS**, **Android**, **Windows**, and **Linux (GNOME / Wayland)**. Inspired by the classic Fliqlo aesthetic — large flipping digits on a black background.

> Not affiliated with Fliqlo®.

## Features

- Flip clock `HH:MM` (+ optional seconds, AM/PM in 12-hour mode)
- Tap to toggle seconds · long-press for settings (interactive app)
- 12/24h, dim, scale, flaps
- Keep screen awake on mobile; fullscreen on desktop
- OS screen saver integrations (see matrix below)

## Screen saver matrix

| Platform | Integration | Docs |
|---|---|---|
| **Windows** | `OpenFliqlo.scr` → `open_fliqlo.exe --screensaver` | [screensaver-windows.md](docs/screensaver-windows.md) |
| **Android** | `DreamService` (system Screen saver) | [screensaver-android.md](docs/screensaver-android.md) |
| **Linux GNOME** | `--screensaver` + idle script / `.desktop` | [screensaver-gnome.md](docs/screensaver-gnome.md) |
| **iOS** | Flip clock **app only** (no system screensaver API) | [ios-ci.md](docs/ios-ci.md) |

Shared modes: `--screensaver`, `--configure`, `--preview` (see S0 in app `LaunchMode`).

## Structure

```
apps/open_fliqlo/           Flutter app (iOS/Android/Windows/Linux)
packages/fliqlo_core/       Clock engine + settings
packages/fliqlo_ui/         FlipDigit, ClockFace, SettingsSheet
platforms/windows_scr/      .scr host (.NET)
packaging/linux/            .desktop + idle-launch script
docs/                       Behavior + screensaver guides
```

## Prerequisites

- Flutter stable (3.24+)
- Linux desktop: GTK packages (see [docs/linux-gnome.md](docs/linux-gnome.md))
- Windows `.scr` build: .NET 8 SDK (on Windows)

## Setup

```bash
dart pub global activate melos
melos bootstrap
```

## Run

```bash
# Interactive app
melos run run:linux
melos run run:windows

# Screensaver mode (Linux)
melos run run:screensaver:linux
# or: cd apps/open_fliqlo && flutter run -d linux -a --screensaver

# Mobile
cd apps/open_fliqlo && flutter run -d <device>
```

## Build Windows screen saver

On a Windows machine:

```powershell
.\platforms\windows_scr\build.ps1
```

## Test / analyze

```bash
melos run test
melos run analyze
```

## CI (iOS IPA)

Unsigned IPA via GitHub Actions — see [docs/ios-ci.md](docs/ios-ci.md).

```bash
# Local (macOS only)
melos run build:ios-ipa
```

## CI (all platforms)

See [docs/ci.md](docs/ci.md) for workflows and artifacts.

```bash
# Cut a release (tests + all builds + GitHub Release assets)
git tag v1.0.0
git push origin v1.0.0
```

## Fonts

Digit glyphs use [`gluqlo.ttf`](packages/fliqlo_ui/fonts/gluqlo.ttf) from [Gluqlo](https://github.com/alexanderk23/gluqlo) (ISC; © Kuźniarski Jacek, Alexander Kovalenko) — see [packages/fliqlo_ui/fonts/LICENSE-gluqlo.txt](packages/fliqlo_ui/fonts/LICENSE-gluqlo.txt).

## License

MIT — see [LICENSE](LICENSE).
