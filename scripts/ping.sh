#!/usr/bin/env bash
# Ping TIP API /api/health if within Mon–Fri 09:00–16:00 Asia/Kolkata.
set -euo pipefail

HEALTH_URL="${HEALTH_URL:-https://tip2-api.onrender.com/api/health}"
TZ_NAME="Asia/Kolkata"

# IST wall clock
ist_now="$(TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %Z')"
dow="$(TZ="$TZ_NAME" date '+%u')"   # 1=Mon … 7=Sun
hour="$(TZ="$TZ_NAME" date '+%H')"
hour=$((10#$hour))

echo "Now: $ist_now (dow=$dow hour=$hour)"
echo "Target: $HEALTH_URL"

# Optional: FORCE=1 bypasses window (for workflow_dispatch debugging)
if [[ "${FORCE:-0}" != "1" ]]; then
  if [[ "$dow" -gt 5 ]]; then
    echo "Outside Mon–Fri IST — skip ping"
    exit 0
  fi
  # 09:00 inclusive … 16:00 exclusive → last runs in the 15:xx hour
  if [[ "$hour" -lt 9 || "$hour" -ge 16 ]]; then
    echo "Outside 09:00–16:00 IST — skip ping"
    exit 0
  fi
fi

echo "Pinging…"
# -f fail on HTTP errors; --max-time for cold start; -S show errors
body="$(curl -fsS --max-time 90 -H 'Accept: application/json' "$HEALTH_URL")"
echo "$body" | head -c 800
echo

# Soft check: must look like JSON health
if ! echo "$body" | grep -q '"status"'; then
  echo "Unexpected response (no status field)" >&2
  exit 1
fi

echo "OK"
