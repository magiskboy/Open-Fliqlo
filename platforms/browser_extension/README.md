# Browser extensions (Chrome / Firefox)

Manifest V3 **new tab** packages built from the same Flutter Web Wasm output as
the Cloudflare Pages site.

## Surfaces

| Surface | Behavior |
|---|---|
| New Tab | `chrome_url_overrides.newtab` → Flutter `index.html` |
| Toolbar action | Opens the extension’s new-tab clock (default icon) |
| Permissions | `storage` only |

## Local build

```bash
./scripts/build_web_wasm.sh
./scripts/pack_web_targets.sh dist/web 0.1.0
```

Artifacts:

- `dist/web/OpenFliqlo-chrome-extension-*.zip` — load unpacked from `chrome-extension/` or zip for Chrome Web Store
- `dist/web/OpenFliqlo-firefox-extension-*.zip` — Firefox Add-ons / `about:debugging`
- `dist/web/cloudflare-pages/` — deploy folder (includes `_headers` for COOP/COEP)

## Load unpacked (Chrome)

1. `chrome://extensions` → Developer mode
2. **Load unpacked** → `dist/web/chrome-extension`

## Temporary install (Firefox)

1. `about:debugging#/runtime/this-firefox`
2. **Load Temporary Add-on** → pick `dist/web/firefox-extension/manifest.json`

## Notes

- Flutter’s loader detects `chrome.runtime.id` and runs **single-threaded** skwasm inside extensions (MV3 CSP blocks multi-thread workers).
- Hosted web on Cloudflare Pages uses `_headers` so Chromium can enable multi-threaded skwasm.
- Do not reintroduce Flutter’s service worker for extension builds (`--pwa-strategy=none`).
