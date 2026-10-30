#!/usr/bin/env bash
# Deploy Flutter web build to Cloudflare Pages (wrangler).
# Requires: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, CF_PAGES_PROJECT
# Does not print secrets.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
: "${CF_PAGES_PROJECT:?set CF_PAGES_PROJECT}"
: "${CLOUDFLARE_ACCOUNT_ID:?set CLOUDFLARE_ACCOUNT_ID}"
: "${CLOUDFLARE_API_TOKEN:?set CLOUDFLARE_API_TOKEN}"
flutter build web --release --base-href=/
npx --yes wrangler pages deploy build/web --project-name="$CF_PAGES_PROJECT" --commit-dirty=true
echo "Cloudflare Pages deploy requested for $CF_PAGES_PROJECT"
