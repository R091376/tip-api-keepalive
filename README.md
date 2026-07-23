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
| Frequency | Every **5 minutes** (GitHub minimum; `*/3` is **not** allowed) |
| Days | **Monday–Friday** |
| Hours | **08:00–15:59 IST** |
| Timezone | **`Asia/Kolkata`** (explicit on the schedule) |

```yaml
on:
  schedule:
    - cron: "*/5 8-15 * * 1-5"
      timezone: Asia/Kolkata
```

### Timezone (official)

Per [GitHub workflow syntax → `on.schedule`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onschedule):

- Default is **UTC** if you omit `timezone`
- You may set an **IANA timezone** (e.g. `Asia/Kolkata`)
- **Shortest interval is every 5 minutes** — not every 3 minutes

### Why schedule runs were missing

1. We used `*/3` (every 3 min) → **below GitHub’s minimum of 5 minutes**, so the schedule may never fire reliably.
2. Without `timezone:`, cron was interpreted as **UTC**, not IST (easy to misread).
3. GitHub can still **delay** schedule events under load even when configured correctly.

`scripts/ping.sh` still double-checks Asia/Kolkata as a safety net.

## GitHub Actions

Workflow: [`.github/workflows/keepalive.yml`](.github/workflows/keepalive.yml)

- `schedule`: Mon–Fri every **5** min, hours **8–15**, **`timezone: Asia/Kolkata`**
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
