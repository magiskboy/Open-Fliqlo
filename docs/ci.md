# CI builds

GitHub Actions workflows under [`.github/workflows/`](../.github/workflows/).

| Workflow | Runner | Artifact | Trigger |
|---|---|---|---|
| [ci.yml](../.github/workflows/ci.yml) | Ubuntu | — (analyze + test) + GNOME extension zip | `main`, PR, manual |
| [web.yml](../.github/workflows/web.yml) | Ubuntu | Cloudflare Pages folder + Chrome/Firefox extension zips | `main`, PR, manual; deploy Pages on `main` / manual |
| [release.yml](../.github/workflows/release.yml) | multi | all platform packages + **GitHub Release** (+ web targets) | tag `v*.*.*` (e.g. `v1.0.0`) |
| [linux.yml](../.github/workflows/linux.yml) | Ubuntu | `OpenFliqlo-linux-x64-*.tar.gz` | manual |
| [windows.yml](../.github/workflows/windows.yml) | Windows | `OpenFliqlo-windows-x64-*.zip` (+ `.scr`) | manual |
| [android.yml](../.github/workflows/android.yml) | Ubuntu | `OpenFliqlo-android-*.apk` | manual |
| [ios-ipa.yml](../.github/workflows/ios-ipa.yml) | macOS | `OpenFliqlo-ios-unsigned-*.ipa` | manual |

## Release (`v1.0.0`)

```bash
git tag v1.0.0
git push origin v1.0.0
```

The **Release** workflow will:

1. Run analyze + tests  
2. Build Linux, Windows, Android, iOS, and **Web Wasm** (Chrome + Firefox zips + Pages deploy) in parallel  
3. Create a GitHub Release for that tag and attach all artifacts  

Tag pattern must match `v*.*.*` (e.g. `v1.0.0`, `v0.2.1`). Prerelease tags with a hyphen (e.g. `v1.0.0-rc.1`) are marked as prerelease.

## Web / Cloudflare

See [web.md](web.md) for build flags, extension packaging, and required secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_PAGES_PROJECT` (optional variable; default `open-fliqlo`)

## Manual single-platform builds

**Actions** → pick Linux / Windows / Android / iOS / **Web (Wasm)** → **Run workflow**.

## Notes

- **Android APK** is release-built but currently signed with the **debug** keystore (see `android/app/build.gradle.kts`) until a release keystore is configured.
- **iOS IPA** is **unsigned** — see [ios-ci.md](ios-ci.md).
- **Windows zip** includes `open_fliqlo.exe`, Flutter `data/`, and `OpenFliqlo.scr` — keep them in the same folder. See [screensaver-windows.md](screensaver-windows.md).
- **Linux tar.gz** includes the Flutter bundle plus screensaver `.desktop` / idle script helpers. See [screensaver-gnome.md](screensaver-gnome.md).
- **Web** ships Wasm + JS fallback; Chrome/Firefox New Tab extensions share that build. See [web.md](web.md).
