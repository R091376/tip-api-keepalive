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
| Hours | **≈ 09:30–15:30 IST** (`Asia/Kolkata`) |
| Single cron (UTC) | `*/3 4-9 * * 1-5` → **04:00–09:59 UTC** |

### Why not exact 09:00 IST with one cron?

GitHub Actions cron is **UTC-only**. IST is **UTC+5:30**, so 09:00 IST = **03:30 UTC**.  
A single hour-range cron can only use whole UTC hours, so:

| Cron | IST coverage |
|------|----------------|
| `*/3 4-9 * * 1-5` (**used**) | **09:30–15:29** — one job, ~9:30 AM–3:30 PM |
| `*/3 3-9 * * 1-5` | 08:30–15:29 — one job, starts 30 min early |
| Exact 09:00–16:00 | Needs **2–3** crons (half-hour offset) |

`scripts/ping.sh` still double-checks Asia/Kolkata as a safety net.

GitHub may delay scheduled runs under load — expected for free-tier keepalives.

## GitHub Actions

Workflow: [`.github/workflows/keepalive.yml`](.github/workflows/keepalive.yml)

- `schedule`: **one** cron — Mon–Fri every 3 min, 04–09 UTC (≈ 9:30–3:30 IST)
- `workflow_dispatch`: manual run (set `force: true` to ping outside the window)

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
