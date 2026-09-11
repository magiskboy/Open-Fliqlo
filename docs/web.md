# Web (Wasm) + browser extensions + Cloudflare Pages

Flutter Web compiled with `--wasm` (dart2wasm + JS fallback), then packaged for three targets from one build.

| Target | Artifact | Docs |
|---|---|---|
| **Cloudflare Pages** | `dist/web/cloudflare-pages/` (+ `_headers` COOP/COEP) | this page |
| **Chrome extension** | `OpenFliqlo-chrome-extension-*.zip` (New Tab) | [browser_extension/README](../platforms/browser_extension/README.md) |
| **Firefox extension** | `OpenFliqlo-firefox-extension-*.zip` (New Tab) | same |

## Local

```bash
./scripts/build_web_wasm.sh
./scripts/pack_web_targets.sh dist/web 0.1.0

# or
melos run build:web-wasm
melos run pack:web-targets
```

Preview host folder:

```bash
cd dist/web/cloudflare-pages
# Prefer a server that can send COOP/COEP; without them skwasm stays single-threaded.
python3 -m http.server 8080
```

## CI workflow

[`.github/workflows/web.yml`](../.github/workflows/web.yml)

| Trigger | Build + zip artifacts | Deploy Cloudflare Pages |
|---|---|---|
| `pull_request` | yes | no |
| `push` to `main` | yes | yes (needs secrets) |
| `workflow_dispatch` | yes | yes |
| Called from Release | optional | optional |

### Required GitHub configuration

| Name | Type | Purpose |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | secret | Pages deploy token (Account → Cloudflare Pages → Edit) |
| `CLOUDFLARE_ACCOUNT_ID` | secret | Cloudflare account id |
| `CLOUDFLARE_PAGES_PROJECT` | variable (optional) | Pages project name; default `open-fliqlo` |

Create the Pages project once in the Cloudflare dashboard (or let the first `wrangler pages deploy` create it), then add the secrets under **Settings → Secrets and variables → Actions**.

### Build flags

```text
flutter build web --release --wasm --csp --no-web-resources-cdn --pwa-strategy=none
```

- `--wasm` — WasmGC build + JS fallback  
- `--csp` — no inline scripts (extension CSP)  
- `--no-web-resources-cdn` — bundle canvaskit/skwasm locally  
- `--pwa-strategy=none` — no Flutter service worker (`chrome-extension://` cannot use it)

### Headers (Cloudflare only)

[`packaging/web/_headers`](../packaging/web/_headers) sets:

- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: credentialless`

so Chromium can run **multi-threaded** skwasm on the hosted site. Extensions remain single-threaded (Flutter auto-detects `chrome.runtime.id`).

## Release integration

Tag releases can call the Web workflow and attach extension zips — see [ci.md](ci.md).
