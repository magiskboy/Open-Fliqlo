# iOS CI — unsigned IPA

GitHub Actions workflow [`.github/workflows/ios-ipa.yml`](../.github/workflows/ios-ipa.yml) builds an **unsigned** release IPA on `macos-latest`.

## Run the workflow

1. Push the repo to GitHub.
2. **Actions → iOS IPA (unsigned) → Run workflow**, or push a tag `v*`.
3. Download the artifact `OpenFliqlo-ios-unsigned-…`.

## Local (macOS + Xcode only)

```bash
melos run build:ios-ipa
# or
cd apps/open_fliqlo && flutter build ipa --release --no-codesign
```

## Limits

- `--no-codesign` IPA **cannot** be installed on a physical iPhone via Diawi, Finder, or Xcode Devices until it is **Ad Hoc** (or other) signed.
- Ad Hoc device list (for a later signed/Diawi step): [`apps/open_fliqlo/ios/adhoc_devices.txt`](../apps/open_fliqlo/ios/adhoc_devices.txt).

## Next step (not in this workflow)

1. Apple Developer account + Ad Hoc provisioning profile including UDIDs in `adhoc_devices.txt`.
2. Sign the IPA in CI.
3. Upload to Diawi (API token).
