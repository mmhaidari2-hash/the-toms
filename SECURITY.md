# Security Policy — New Life UK

## Supported versions
The latest `main` (Play / PWA) build only.

## Reporting a vulnerability
Email `[PLACEHOLDER: SECURITY CONTACT EMAIL]` with steps to reproduce. Do not open a public issue for sensitive reports.
We aim to acknowledge within 3 business days.

## Hardening (this build)
- HTTPS only; cleartext disabled on Android (`networkSecurityConfig`)
- `allowBackup=false`; release R8 minify/shrink
- CSP + Permissions-Policy (geolocation off) via meta / `_headers`
- Local progress encrypted at rest on Android/iOS (Hive AES + secure storage)
- No analytics/ads SDKs; no inline secrets in source
- Buddy share codes validated to a strict alphabet/length
- In-app export + delete-all for local data

## Play Integrity
Ready to wire Play Integrity API when the Play app signing + Cloud project are configured by the publisher (`[PLACEHOLDER]`).
