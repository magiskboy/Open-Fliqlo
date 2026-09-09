# CI builds

GitHub Actions workflows under [`.github/workflows/`](../.github/workflows/).

| Workflow | Runner | Artifact | Trigger |
|---|---|---|---|
| [ci.yml](../.github/workflows/ci.yml) | Ubuntu | — (analyze + test) | `main`, PR, manual |
| [linux.yml](../.github/workflows/linux.yml) | Ubuntu | `OpenFliqlo-linux-x64-*.tar.gz` | manual, tag `v*` |
| [windows.yml](../.github/workflows/windows.yml) | Windows | `OpenFliqlo-windows-x64-*.zip` (+ `.scr`) | manual, tag `v*` |
| [android.yml](../.github/workflows/android.yml) | Ubuntu | `OpenFliqlo-android-*.apk` | manual, tag `v*` |
| [ios-ipa.yml](../.github/workflows/ios-ipa.yml) | macOS | `OpenFliqlo-ios-unsigned-*.ipa` | manual, tag `v*` |

## How to run

1. Push the repo to GitHub.
2. **Actions** → pick a workflow → **Run workflow**, or push a tag `v0.1.0`.
3. Download artifacts from the completed run.

## Notes

- **Android APK** is release-built but currently signed with the **debug** keystore (see `android/app/build.gradle.kts`) until a release keystore is configured.
- **iOS IPA** is **unsigned** — see [ios-ci.md](ios-ci.md).
- **Windows zip** includes `open_fliqlo.exe`, Flutter `data/`, and `OpenFliqlo.scr` — keep them in the same folder. See [screensaver-windows.md](screensaver-windows.md).
- **Linux tar.gz** includes the Flutter bundle plus screensaver `.desktop` / idle script helpers. See [screensaver-gnome.md](screensaver-gnome.md).
