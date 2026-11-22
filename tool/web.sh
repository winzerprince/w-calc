#!/usr/bin/env bash
# Local web testing (web is never built in CI).
#   tool/web.sh          -> dev server with hot reload, reachable from your phone on the same Wi-Fi
#   tool/web.sh release  -> release build served from build/web (closest to production behaviour)
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${PORT:-8080}"
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "Open on phone: http://${IP:-localhost}:$PORT"
if [[ "${1:-}" == "release" ]]; then
  flutter build web --release --no-web-resources-cdn
  cd build/web && python3 -m http.server "$PORT" --bind 0.0.0.0
else
  flutter run -d web-server --web-hostname 0.0.0.0 --web-port "$PORT"
fi
