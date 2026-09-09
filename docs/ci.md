# CI builds

GitHub Actions workflows under [`.github/workflows/`](../.github/workflows/).

| Workflow | Runner | Artifact | Trigger |
|---|---|---|---|
| [ci.yml](../.github/workflows/ci.yml) | Ubuntu | — (analyze + test) | `main`, PR, manual |
| [release.yml](../.github/workflows/release.yml) | multi | all platform packages + **GitHub Release** | tag `v*.*.*` (e.g. `v1.0.0`) |
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
2. Build Linux, Windows, Android, iOS in parallel  
3. Create a GitHub Release for that tag and attach all artifacts  

Tag pattern must match `v*.*.*` (e.g. `v1.0.0`, `v0.2.1`). Prerelease tags with a hyphen (e.g. `v1.0.0-rc.1`) are marked as prerelease.

## Manual single-platform builds

**Actions** → pick Linux / Windows / Android / iOS → **Run workflow**.

## Notes

- **Android APK** is release-built but currently signed with the **debug** keystore (see `android/app/build.gradle.kts`) until a release keystore is configured.
- **iOS IPA** is **unsigned** — see [ios-ci.md](ios-ci.md).
- **Windows zip** includes `open_fliqlo.exe`, Flutter `data/`, and `OpenFliqlo.scr` — keep them in the same folder. See [screensaver-windows.md](screensaver-windows.md).
- **Linux tar.gz** includes the Flutter bundle plus screensaver `.desktop` / idle script helpers. See [screensaver-gnome.md](screensaver-gnome.md).
