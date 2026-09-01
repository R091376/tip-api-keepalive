#!/usr/bin/env bash
# Ping TIP API /api/health whenever this script runs.
set -euo pipefail

HEALTH_URL="${HEALTH_URL:-https://tip2-api.onrender.com/api/health}"
TZ_NAME="Asia/Kolkata"

ist_now="$(TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %Z')"
utc_now="$(TZ=UTC date '+%Y-%m-%d %H:%M:%S %Z')"

echo "IST: $ist_now"
echo "UTC: $utc_now"
echo "Target: $HEALTH_URL"
echo "Pinging…"

body="$(curl -fsS --max-time 90 -H 'Accept: application/json' "$HEALTH_URL")"
echo "$body" | head -c 800
echo

if ! echo "$body" | grep -q '"status"'; then
  echo "Unexpected response (no status field)" >&2
  exit 1
fi

echo "OK"
