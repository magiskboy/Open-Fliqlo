# Open Fliqlo Android screen saver (DreamService)

## How it works

`FlipClockDreamService` hosts a `FlutterView` running the Dart app with `--screensaver`:

- Fullscreen flip clock  
- Tap / swipe / key → Flutter calls platform `finish` → dream ends  
- System screen-saver settings gear opens `ConfigureActivity` (`--configure`)

The normal launcher icon still opens the interactive app (`MainActivity`).

## Enable on device

1. Install / run the app once.  
2. **Settings → Display → Screen saver** (path varies by OEM).  
3. Choose **Open Fliqlo**.  
4. Optionally open the gear → Open Fliqlo settings (12/24h, dim, scale, …).

## OEM notes

Some manufacturers disable or hide Daydream / screen saver (aggressive battery policies). If Open Fliqlo does not appear in the list, check Display / Lock screen / Screen saver menus under the OEM skin (Samsung, Xiaomi, etc.).

## Develop

```bash
cd apps/open_fliqlo
flutter run -d <android-device>
# Exercise dream from: adb shell settings or device UI Screen saver → Start now
```

## Files

- [`FlipClockDreamService.kt`](../apps/open_fliqlo/android/app/src/main/kotlin/com/openfliqlo/open_fliqlo/FlipClockDreamService.kt)  
- [`ConfigureActivity.kt`](../apps/open_fliqlo/android/app/src/main/kotlin/com/openfliqlo/open_fliqlo/ConfigureActivity.kt)  
- [`AndroidManifest.xml`](../apps/open_fliqlo/android/app/src/main/AndroidManifest.xml)  
