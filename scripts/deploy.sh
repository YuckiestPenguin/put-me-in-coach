#!/usr/bin/env bash
# Build the web app for an environment and deploy it to Firebase Hosting.
#   scripts/deploy.sh dev     -> https://put-me-in-coach-dev.web.app
#   scripts/deploy.sh prod    -> https://put-me-in-coach-prod.web.app (asks first)
set -euo pipefail

env="${1:-}"
case "$env" in
  dev|prod) ;;
  *) echo "usage: scripts/deploy.sh dev|prod" >&2; exit 1 ;;
esac

cd "$(dirname "$0")/.."

if [ "$env" = prod ]; then
  read -r -p "Deploy to PRODUCTION? Type 'prod' to continue: " answer
  [ "$answer" = prod ] || { echo "Cancelled."; exit 1; }
fi

flutter build web --release --dart-define=ENV="$env"

# Guard: a stale generated plugin list once left Firestore's web plugin out of
# the release bundle, so every Firestore read failed in production only. If the
# marker is missing, fix it with `flutter clean && flutter pub get`.
for marker in flutter-fire-fst flutter-fire-auth flutter-fire-core; do
  grep -q "$marker" build/web/main.dart.js || {
    echo "ERROR: build/web/main.dart.js is missing '$marker' (a Firebase web plugin)." >&2
    echo "Run: flutter clean && flutter pub get, then deploy again." >&2
    exit 1
  }
done

firebase deploy --only hosting --project "$env"
