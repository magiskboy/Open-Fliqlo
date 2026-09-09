# Open Fliqlo Windows screen saver (`.scr`)

## How it works

`OpenFliqlo.scr` is a tiny .NET host that launches `open_fliqlo.exe` from the same folder:

| Argument | Flutter launch |
|---|---|
| `/s` | `open_fliqlo.exe --screensaver` |
| `/c` | `open_fliqlo.exe --configure` |
| `/p HWND` | `open_fliqlo.exe --preview` (env `OPEN_FLIQLO_PREVIEW_HWND`) |

Screensaver mode is fullscreen; mouse/keyboard exits. Configure opens settings then exits.

## Build (on Windows)

Requirements: Flutter stable, .NET 8 SDK.

```powershell
.\platforms\windows_scr\build.ps1
```

Output: `dist/windows-screensaver/` containing `open_fliqlo.exe`, Flutter assets, and `OpenFliqlo.scr`.

## Install

1. Copy the entire `dist/windows-screensaver` folder somewhere permanent (e.g. `C:\Program Files\OpenFliqlo\`).
2. Right-click `OpenFliqlo.scr` → **Install**, or open **Settings → Personalization → Lock screen → Screen saver** and browse to the `.scr`.
3. Keep `open_fliqlo.exe` and the `data/` folder **next to** the `.scr` (same directory).

## Preview (`/p`)

Phase-1 preview opens a small always-on-top Flutter window (`--preview`). Parenting into the Control Panel HWND is best-effort via `OPEN_FLIQLO_PREVIEW_HWND` for future native embedding; a floating 320×200 preview is the supported behavior today.

## Troubleshooting

- Screen saver flashes and exits: `open_fliqlo.exe` missing beside the `.scr`.
- Settings do not persist: ensure the process can write under the user profile (`SharedPreferences`).
