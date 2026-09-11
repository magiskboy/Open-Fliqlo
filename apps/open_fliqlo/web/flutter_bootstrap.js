{{flutter_js}}
{{flutter_build_config}}

// Hosted web: enable multi-threaded skwasm when the server sends COOP/COEP
// (Cloudflare Pages `_headers`). Chrome/Firefox extensions are auto-detected
// by the Flutter loader and forced single-threaded.
_flutter.loader.load({
  config: {
    // Keep warning quiet when isolation headers are missing (local preview).
    suppressMultithreadingWarning: true,
  },
});
