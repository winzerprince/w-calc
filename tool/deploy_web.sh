#!/usr/bin/env bash
# Builds the website and deploys it to Cloudflare Pages (project "w-calc",
# served at https://w-calc.0xwinzer.com).
#
#   tool/deploy_web.sh            build + deploy
#   tool/deploy_web.sh --dry-run  build only (build/web), nothing uploaded
#
# Ads (website only; never in the Android or itch.io builds) are added when
# these are set, e.g. in your shell or a git-ignored tool/.web.env:
#   ADSENSE_CLIENT=ca-pub-1234567890123456   publisher ID
#   ADSENSE_SLOT=1234567890                  display ad unit for the side panel (optional)
#   ADSENSE_SLOT_MOBILE=1234567890           320×50 banner under the app on phones (optional)
# Requires: `npx wrangler@3 login` once.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f tool/.web.env ]] && source tool/.web.env
DRY=false
[[ "${1:-}" == "--dry-run" ]] && DRY=true

flutter build web --release --no-web-resources-cdn --pwa-strategy=none
OUT=build/web

if [[ -n "${ADSENSE_CLIENT:-}" ]]; then
  [[ "$ADSENSE_CLIENT" =~ ^ca-pub-[0-9]{10,20}$ ]] || { echo "ADSENSE_CLIENT must look like ca-pub-123…" >&2; exit 1; }
  head="<script async src=\"https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$ADSENSE_CLIENT\" crossorigin=\"anonymous\"></script>"
  slot=""
  if [[ -n "${ADSENSE_SLOT:-}" ]]; then
    slot="<div class=\"ad\"><ins class=\"adsbygoogle\" style=\"display:block\" data-ad-client=\"$ADSENSE_CLIENT\" data-ad-slot=\"$ADSENSE_SLOT\" data-ad-format=\"auto\" data-full-width-responsive=\"true\"></ins><script>(adsbygoogle = window.adsbygoogle || []).push({});</script></div>"
  fi
  mobile=""
  if [[ -n "${ADSENSE_SLOT_MOBILE:-}" ]]; then
    mobile="<div id=\"mobile-ad\"><ins class=\"adsbygoogle\" style=\"display:inline-block;width:320px;height:50px;margin-top:5px\" data-ad-client=\"$ADSENSE_CLIENT\" data-ad-slot=\"$ADSENSE_SLOT_MOBILE\"></ins><script>if (innerWidth < 900) (adsbygoogle = window.adsbygoogle || []).push({});</script></div>"
  fi
  python3 - "$OUT/index.html" "$head" "$slot" "$mobile" <<'PY'
import sys
p, head, slot, mobile = sys.argv[1:5]
s = open(p).read()
s = s.replace('<!-- ADS:HEAD -->', head).replace('<!-- ADS:SLOT -->', slot).replace('<!-- ADS:MOBILE -->', mobile)
open(p, 'w').write(s)
PY
  echo "google.com, ${ADSENSE_CLIENT#ca-}, DIRECT, f08c47fec0942fa0" > "$OUT/ads.txt"
  echo "ads: on ($ADSENSE_CLIENT)"
else
  echo "ads: off (ADSENSE_CLIENT not set)"
fi

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
