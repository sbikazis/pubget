#!/usr/bin/env bash
set -euo pipefail

firebase_defines="$(mktemp)"
trap 'rm -f "$firebase_defines"' EXIT

python3 scripts/fetch_firebase_web_config.py "$firebase_defines"

flutter build web \
  --pwa-strategy=none \
  --dart-define-from-file="$firebase_defines"

rm -f "$firebase_defines"
trap - EXIT

exec python3 -m http.server 5000 --bind 0.0.0.0 --directory build/web