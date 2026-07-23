#!/usr/bin/env bash
# Ping TIP API /api/health if within Mon–Fri ~09:30–15:30 Asia/Kolkata.
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

# Optional: FORCE=1 bypasses window (for workflow_dispatch debugging)
if [[ "${FORCE:-0}" != "1" ]]; then
  if [[ "$dow" -gt 5 ]]; then
    echo "Outside Mon–Fri IST — skip ping"
    exit 0
  fi
  # Match single cron */3 4-9 * * 1-5 UTC → ~09:30–15:29 IST
  # Allow 09:30 inclusive through 15:30 exclusive (last hour 15:xx)
  if [[ "$hour" -lt 9 ]]; then
    echo "Before 09:30 IST window — skip ping"
    exit 0
  fi
  if [[ "$hour" -eq 9 && "$minute" -lt 30 ]]; then
    echo "Before 09:30 IST — skip ping"
    exit 0
  fi
  if [[ "$hour" -ge 16 ]]; then
    echo "After 15:30 IST window — skip ping"
    exit 0
  fi
  # hour 15 is OK (15:00–15:29 cron); hour 16+ already skipped
  if [[ "$hour" -gt 15 ]]; then
    echo "After 15:30 IST window — skip ping"
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
