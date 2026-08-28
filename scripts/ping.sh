#!/usr/bin/env bash
# Ping TIP API /api/health if within Mon–Fri 08:30–10:30 Asia/Kolkata.
set -euo pipefail

HEALTH_URL="${HEALTH_URL:-https://tip2-api.onrender.com/api/health}"
TZ_NAME="Asia/Kolkata"

ist_now="$(TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %Z')"
dow="$(TZ="$TZ_NAME" date '+%u')"   # 1=Mon … 7=Sun
hour="$(TZ="$TZ_NAME" date '+%H')"
minute="$(TZ="$TZ_NAME" date '+%M')"
hour=$((10#$hour))
minute=$((10#$minute))

echo "Now: $ist_now (dow=$dow hour=$hour minute=$minute)"
echo "Target: $HEALTH_URL"

if [[ "${FORCE:-0}" != "1" ]]; then
  if [[ "$dow" -gt 5 ]]; then
    echo "Outside Mon–Fri IST — skip ping"
    exit 0
  fi
  # 08:30–10:30 IST (cron is UTC; script is the IST source of truth).
  # End is 30 min past the last 10:00 IST slot so a delayed GitHub run still pings.
  minutes_now=$((hour * 60 + minute))
  window_start=$((8 * 60 + 30))
  window_end=$((10 * 60 + 30))
  if [[ "$minutes_now" -lt "$window_start" || "$minutes_now" -ge "$window_end" ]]; then
    echo "Outside 08:30–10:30 IST — skip ping"
    exit 0
  fi
fi

echo "Pinging…"
body="$(curl -fsS --max-time 90 -H 'Accept: application/json' "$HEALTH_URL")"
echo "$body" | head -c 800
echo

if ! echo "$body" | grep -q '"status"'; then
  echo "Unexpected response (no status field)" >&2
  exit 1
fi

echo "OK"
