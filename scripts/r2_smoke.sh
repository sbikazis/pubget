#!/usr/bin/env bash
# Opt-in production-like R2 smoke test. It uses a REAL Worker and a REAL
# Firebase ID token, so it is never run by CI and never runs by accident.
#
# Usage:
#   export R2_WORKER_URL=https://pubget-media.pubget.workers.dev
#   export FIREBASE_ID_TOKEN='<fresh token from a signed-in client>'
#   bash scripts/r2_smoke.sh
#
# Obtain the token from FirebaseAuth.instance.currentUser.getIdToken() (or the
# equivalent REST sign-in) in a trusted local shell. It is a bearer credential:
# keep it out of shell history, logs and source control. This script never
# prints it and never enables verbose curl.

set -euo pipefail

if [[ -z "${R2_WORKER_URL:-}" || -z "${FIREBASE_ID_TOKEN:-}" ]]; then
  echo "R2_WORKER_URL and FIREBASE_ID_TOKEN are required; refusing to run." >&2
  exit 2
fi
if [[ "$R2_WORKER_URL" != https://* ]]; then
  echo "R2_WORKER_URL must be https://; the bucket must stay private." >&2
  exit 2
fi
command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 2; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
BASE="${R2_WORKER_URL%/}"
AUTH_HEADER=(--header "Authorization: Bearer ${FIREBASE_ID_TOKEN}")

# Minimal valid PNG signature (8 bytes). The Worker checks file signatures.
printf '\211PNG\r\n\032\n' > "$WORK/sample.png"

status=$(curl -sS -o "$WORK/presign.json" -w '%{http_code}' \
  "${AUTH_HEADER[@]}" \
  "${BASE}/presign?kind=image&contentType=image/png&ext=png&sizeBytes=8")
[[ "$status" == "200" ]] || { echo "presign failed: HTTP $status" >&2; exit 1; }

upload_url=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["uploadUrl"])' "$WORK/presign.json")
object_key=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["key"])' "$WORK/presign.json")
echo "presign OK: key=$object_key"

status=$(curl -sS -o "$WORK/upload.json" -w '%{http_code}' \
  --request PUT --header 'Content-Type: image/png' \
  --data-binary "@$WORK/sample.png" "$upload_url")
[[ "$status" == "201" ]] || { echo "upload failed: HTTP $status" >&2; exit 1; }
echo "upload OK"

status=$(curl -sS -o "$WORK/resolve.json" -w '%{http_code}' \
  "${AUTH_HEADER[@]}" \
  "${BASE}/resolve?key=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$object_key")")
[[ "$status" == "200" ]] || { echo "resolve failed: HTTP $status" >&2; exit 1; }
media_url=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["url"])' "$WORK/resolve.json")
echo "resolve OK: short-lived signed URL issued"

status=$(curl -sS -o "$WORK/seek.bin" -D "$WORK/seek.headers" -w '%{http_code}' \
  --header 'Range: bytes=0-3' "$media_url")
[[ "$status" == "206" ]] || { echo "byte-range playback failed: HTTP $status" >&2; exit 1; }
grep -qi '^content-range: bytes 0-3/' "$WORK/seek.headers" || {
  echo "byte-range playback returned no valid Content-Range" >&2; exit 1;
}
echo "seek OK: $(od -An -tx1 -N4 "$WORK/seek.bin" | tr -s ' ')"

status=$(curl -sS -o /dev/null -w '%{http_code}' --request DELETE \
  "${AUTH_HEADER[@]}" "${BASE}/media/${object_key}")
[[ "$status" == "204" ]] || { echo "delete failed: HTTP $status" >&2; exit 1; }
status=$(curl -sS -o /dev/null -w '%{http_code}' --request DELETE \
  "${AUTH_HEADER[@]}" "${BASE}/media/${object_key}")
[[ "$status" == "204" ]] || { echo "idempotent delete failed: HTTP $status" >&2; exit 1; }
echo "delete OK (idempotent)"

# Deliberately not covered here: multipart source upload, FFmpeg processing,
# retry, moderation preview. Those need a real Kirari reel and live Functions.
echo "R2 smoke: PASS"
