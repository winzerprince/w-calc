#!/usr/bin/env bash
# Builds the website and deploys it to Cloudflare Pages (project "w-calc",
# served at https://w-calc.0xwinzer.com).
#
#   tool/deploy_web.sh            build + deploy
#   tool/deploy_web.sh --dry-run  build only (build/web), nothing uploaded
# Requires: `npx wrangler@3 login` once.
set -euo pipefail
cd "$(dirname "$0")/.."
DRY=false
[[ "${1:-}" == "--dry-run" ]] && DRY=true

flutter build web --release --no-web-resources-cdn --pwa-strategy=none
OUT=build/web

# Cache: the page and bootstrap always fresh; versioned assets may be cached briefly.
cat > "$OUT/_headers" <<'H'
/
  Cache-Control: no-cache
/index.html
  Cache-Control: no-cache
/flutter_bootstrap.js
  Cache-Control: no-cache
/main.dart.js
  Cache-Control: public, max-age=300
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
H

if $DRY; then echo "dry run: $OUT ready"; exit 0; fi
npx -y wrangler@3 pages deploy "$OUT" --project-name w-calc --branch main --commit-dirty=true
