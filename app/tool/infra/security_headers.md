# Security headers / CSP

Apply on the static host (Cloudflare Pages `_headers`, GitHub Pages via meta + `web/_headers` if supported, or CDN).

## Suggested `_headers` (Cloudflare Pages / Netlify style)

```
/*
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), geolocation=(), microphone=(self)
  Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' data blob:; media-src 'self' blob:; connect-src 'self' https://*.sentry.io; worker-src 'self' blob:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'
```

Notes:
- Flutter web needs `'unsafe-eval'` / `'wasm-unsafe-eval'` for canvaskit/skwasm in many builds.
- `microphone=(self)` allows the in-page SpeechRecognition path.
- Sentry connect only matters when `SENTRY_DSN` is set.
