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
| Frequency | Every **5 minutes** (GitHub minimum) |
| Days | **Monday–Friday** |
| Cron (UTC) | `*/5 3-10 * * 1-5` (~08:30–16:25 IST) |
| Effective window | **09:00–15:59 IST** (enforced in `scripts/ping.sh`) |

Workflow uses a **plain UTC cron** (no `timezone:` field). The shell script is the source of truth for the IST market window.

```yaml
on:
  schedule:
    - cron: "*/5 3-10 * * 1-5"
  workflow_dispatch:
```

GitHub may run schedules a few minutes late under load. Schedules only run from the **default branch** (`master`).

## GitHub Actions

Workflow: [`.github/workflows/tip-keepalive.yml`](.github/workflows/tip-keepalive.yml)

- `schedule`: Mon–Fri, every 5 min, UTC hours 3–10
- `workflow_dispatch`: manual run (`force: true` outside the window)

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
- Free GitHub Actions schedules are best-effort (can delay).
- Repo inactivity can pause schedules; a recent commit reactivates them.
