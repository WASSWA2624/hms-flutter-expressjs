{{flutter_js}}
{{flutter_build_config}}

// Prefer engine assets served from this origin so the app can boot offline
// (no gstatic CDN fetch for canvaskit.js / canvaskit.wasm).
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
