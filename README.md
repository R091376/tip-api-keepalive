# tip-api-keepalive

Lightweight **keep-warm** pinger for the TIP-2 API on Render free tier (and related cold starts).

It does **not** live inside the TIP-2 app repo. GitHub Actions calls the public health endpoint on a schedule so the API process is less likely to idle-sleep during market hours.

## What it hits

```http
GET https://tip2-api.onrender.com/api/health
```

Override with repo variable `HEALTH_URL` if the API host changes.

### Does `/api/health` touch Postgres?

**Yes**, when the API is configured for Postgres (not memory profile):

- Health runs a real **`SELECT 1`** against the DB pool (or a one-shot connect if init fell back).
- So each successful ping lightly exercises **both** the Render web service and Neon/Postgres.

It does **not** load candles, patterns, or the full bootstrap path.

## Schedule

| Setting | Value |
|---------|--------|
| Frequency | Every **3 minutes** |
| Days | **Monday–Friday** |
| Hours | **09:00–16:00 IST** (`Asia/Kolkata`) — NSE-aligned window (9 AM through before 4 PM) |
| Timezone logic | Cron runs Mon–Fri every 3 min in **UTC**; the job **skips** outside 09:00–16:00 IST |

GitHub Actions schedules are UTC-only and can lag several minutes under load. That is expected for free-tier keepalives.

## GitHub Actions

Workflow: [`.github/workflows/keepalive.yml`](.github/workflows/keepalive.yml)

- `schedule`: `*/3 * * * 1-5` (Mon–Fri, every 3 minutes UTC)
- `workflow_dispatch`: manual run anytime (still respects IST window unless you force)

### Optional repo variable

| Name | Default |
|------|---------|
| `HEALTH_URL` | `https://tip2-api.onrender.com/api/health` |

Set under **Settings → Secrets and variables → Actions → Variables**.

## Local smoke

```bash
# bash / Git Bash
export HEALTH_URL=https://tip2-api.onrender.com/api/health
bash scripts/ping.sh
```

```powershell
# Windows PowerShell
$env:HEALTH_URL = "https://tip2-api.onrender.com/api/health"
bash scripts/ping.sh
```

## Limits

- Does not replace a paid “always on” plan.
- Neon and Render can still sleep; this only **reduces** idle downtime during the window.
- Outside Mon–Fri 09:00–16:00 IST the workflow exits 0 without calling the API (saves Actions minutes).
