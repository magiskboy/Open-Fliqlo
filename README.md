# Open Fliqlo

Cross-platform fullscreen flip clock for **iOS**, **Android**, **Windows**, **Linux (GNOME / Wayland)**, and **Web** (Cloudflare Pages + Chrome/Firefox New Tab). Inspired by the classic Fliqlo aesthetic — large flipping digits on a black background.

> Not affiliated with Fliqlo®.

## Features

- Flip clock `HH:MM` (+ optional seconds, AM/PM in 12-hour mode)
- Horizontal or vertical digit layout
- Tap to toggle seconds · long-press for settings (interactive app)
- 12/24h, dim, scale, flaps, optional flip sound
- Keep screen awake on mobile; fullscreen on desktop
- OS screen saver integrations (see matrix below)

## Screen saver matrix

| Platform | Integration | Docs |
|---|---|---|
| **Windows** | `OpenFliqlo.scr` → `open_fliqlo.exe --screensaver` | [screensaver-windows.md](docs/screensaver-windows.md) |
| **Android** | `DreamService` (system Screen saver) | [screensaver-android.md](docs/screensaver-android.md) |
| **Linux GNOME** | `--screensaver` + idle script / `.desktop` | [screensaver-gnome.md](docs/screensaver-gnome.md) |
| **Linux GNOME lock** | Shell extension + `--lockscreen` | [lockscreen-gnome.md](docs/lockscreen-gnome.md) |
| **Web** | Hosted Wasm app + Chrome/Firefox **New Tab** | [web.md](docs/web.md) |
| **iOS** | Flip clock **app only** (no system screensaver API) | [ios-ci.md](docs/ios-ci.md) |

Shared modes: `--screensaver`, `--lockscreen`, `--configure`, `--preview` (see S0 in app `LaunchMode`).

## Structure

```
apps/open_fliqlo/           Flutter app (iOS/Android/Windows/Linux/Web)
packages/fliqlo_core/       Clock engine + settings
packages/fliqlo_ui/         FlipDigit, ClockFace, SettingsSheet
platforms/windows_scr/      .scr host (.NET)
platforms/gnome_shell_extension/  GNOME lock-screen extension
platforms/browser_extension/      Chrome + Firefox New Tab manifests
packaging/linux/            .desktop + idle-launch script
packaging/web/              Cloudflare Pages `_headers`
scripts/                    web Wasm build + multi-target pack
docs/                       Behavior + screensaver / lock-screen / web guides
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

# Web (Chrome, Wasm)
cd apps/open_fliqlo && flutter run -d chrome --wasm

# Mobile
cd apps/open_fliqlo && flutter run -d <device>
```

## Build Windows screen saver

On a Windows machine:

```powershell
.\platforms\windows_scr\build.ps1
```

## Build Web + browser extensions

```bash
melos run build:web-wasm
melos run pack:web-targets
# → dist/web/cloudflare-pages/
# → dist/web/OpenFliqlo-chrome-extension-*.zip
# → dist/web/OpenFliqlo-firefox-extension-*.zip
```

Details: [docs/web.md](docs/web.md).

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
