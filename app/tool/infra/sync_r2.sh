#!/usr/bin/env bash
# Sync large media (voices / paintings) to Cloudflare R2.
# Requires: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, R2_BUCKET, AWS-compatible endpoint via wrangler/rclone.
# Does not print secrets.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${R2_BUCKET:?set R2_BUCKET}"
SRC="${1:-$ROOT/build/web/assets}"
echo "Would sync $SRC → r2://$R2_BUCKET/ (configure wrangler r2 object put / rclone)"
echo "Example: npx wrangler r2 object put $R2_BUCKET/path --file ./file"
