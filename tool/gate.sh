#!/usr/bin/env bash
# Local quality gate — mandatory before every PR into dev (CI only runs a
# placeholder there). Fails on the first problem.
set -euo pipefail
cd "$(dirname "$0")/.."
dart format --output=none --set-exit-if-changed lib test packages tool >/dev/null
flutter analyze --suppress-analytics >/dev/null
(cd packages/wcalc_engine && dart analyze --fatal-infos >/dev/null && dart test --reporter=silent)
flutter test --suppress-analytics --reporter=silent
echo "gate: OK"
