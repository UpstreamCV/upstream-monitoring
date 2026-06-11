# upstream-monitoring

The Upstream monitoring box. One small Lightsail/EC2 instance, deliberately
separate from the things it monitors so it stays up when they do not.

Four compose services:

| Service | Role | Exposure |
|---|---|---|
| **Uptime Kuma** | Black-box checks + public status page | via Caddy at https://status.upstreamcv.com |
| **Caddy** | TLS-terminating reverse proxy for Kuma | :80 / :443 |
| **Prometheus** | White-box metrics: pulls from the media nodes and the api-server; evaluates the 8 alert rules; 30-day retention | `127.0.0.1:9090` only — SSH tunnel |
| **Alertmanager** | Routes firing alerts to a single operator email | `127.0.0.1:9093` only — SSH tunnel |

This implements **FU-14 / milestone M9.2** (monitoring-box half). Design and
rationale live in the streaming-server repo:

- `upstream-streaming-server/docs/design/01-observability.md` — §2 scrape
  topology (Prometheus pulls; Kuma keeps the black-box role), §5 SLI/SLO
  table, §6 the 8 alert rules.
- `upstream-streaming-server/docs/follow-ups.md` — FU-14 (scrape targets,
  firewall holes, verification).

## Deploy

```bash
bash bootstrap.sh                 # first run only: installs Docker
# create the api-server scrape token (see "Secrets" below) BEFORE first up
docker compose up -d
```

Kuma's first-run wizard is at https://status.upstreamcv.com.

## Secrets

**`prometheus/secrets/api_metrics_token`** — the bearer token Prometheus
sends when scraping `https://api.upstreamcv.com/metrics`. It must equal the
api-server's `UPSTREAM_PROMETHEUS_AUTH_TOKEN`. The real token file is
gitignored and is **not** in the repo; what ships is
`prometheus/secrets/api_metrics_token.example` (a committed placeholder).
On the box, copy the example and fill in the real token:

```bash
umask 077
cp prometheus/secrets/api_metrics_token.example prometheus/secrets/api_metrics_token
printf '%s' '<the real token>' > prometheus/secrets/api_metrics_token
docker compose restart prometheus   # only needed if already running
```

Never commit the real token, paste it into a compose file, or echo it into
logs. Everything under `prometheus/secrets/` except the `.example` file is
gitignored.

## Operator access (SSH tunnel — no Caddy route, on purpose)

Prometheus and Alertmanager bind `127.0.0.1` on the box and are **not**
proxied by Caddy: they are operator tools, not public surfaces, and
Prometheus has no auth of its own. Access them through an SSH tunnel:

```bash
ssh -N -L 9090:127.0.0.1:9090 -L 9093:127.0.0.1:9093 <user>@<monitoring-box>
```

then open http://localhost:9090 (Prometheus — check **Status → Targets**)
and http://localhost:9093 (Alertmanager — silences).

## Scrape targets (prometheus/prometheus.yml)

| Job | Target | Status |
|---|---|---|
| `api-server` | `https://api.upstreamcv.com/metrics` (bearer token) | live once M9.3 ships `/metrics` |
| `mediamtx` | `ingest.upstreamcv.com:19998` | live once M9.1 ships the metrics port + the monitoring-IP firewall hole |
| `node` | `ingest.upstreamcv.com:9100` | live once node_exporter is installed on the node |
| `prometheus` | self-scrape | live |

Node-side ports are firewalled to this box's IP only (the
`firewall-restrict-readports.sh` pattern; port table in
`upstream-streaming-server/docs/design/05-security-hardening.md` §3).

## Alert rules (prometheus/alerts.yml)

Exactly the 8 rules from design doc 01 §6 — node down, api down, lifecycle
truth lost (stuck sessions / hookd dead-letters), path drift, ingest auth
success, reconnect storm, node headroom, disk/cert housekeeping. Rules whose
metrics ship in later milestones (sweeper M10.1, reconciler M10.2, hookd
M11.1, api metrics M9.3, node_exporter/blackbox probes) are written against
the designed metric names and stay silent until those land. Keep the count
at 8: add one, remove one.

### Metric-name contract

Rules 3, 4 and 6 reference metrics that do not exist yet:
`sweeper_stuck_sessions` (ships in M10.1), `reconciler_path_drift` (M10.2),
`hookd_dead_letters` (M11.1) and `session_starts_total{camera_id}`
(api-server follow-up). These names are pinned in
`upstream-streaming-server/docs/design/01-observability.md` §3 (being
updated in parallel); the producing milestones must emit exactly these
names, otherwise the rules stay silent forever instead of firing.

## Alertmanager: filling in SMTP

`alertmanager/alertmanager.yml` ships with placeholder values on the
RFC 2606-reserved `.invalid` TLD, so it **cannot send anything** until you
edit it. Replace:

| Field | Replace with |
|---|---|
| `smtp_smarthost` | your SMTP relay, e.g. `email-smtp.us-west-2.amazonaws.com:587` (SES) |
| `smtp_from` | a verified sender, e.g. `alerts@upstreamcv.com` |
| `smtp_auth_username` / `smtp_auth_password` | the relay's SMTP credentials |
| `receivers[0].email_configs[0].to` | the operator's email address |

Then `docker compose restart alertmanager` and send a test alert:

```bash
docker exec alertmanager amtool alert add test_alert severity=info --alertmanager.url=http://127.0.0.1:9093
```

## Validating config changes

Run from the repo root; all three must pass before deploying:

```bash
docker compose config -q
docker run --rm -v "$PWD/prometheus:/cfg:ro" --entrypoint promtool prom/prometheus:v3.12.0 check config /cfg/prometheus.yml
docker run --rm -v "$PWD/prometheus:/cfg:ro" --entrypoint promtool prom/prometheus:v3.12.0 check rules /cfg/alerts.yml
docker run --rm -v "$PWD/alertmanager:/cfg:ro" --entrypoint amtool prom/alertmanager:v0.32.2 check-config /cfg/alertmanager.yml
```

The image tags match the pins in `docker-compose.yml`; validate with the
same versions you deploy (config formats drift between releases).

Note: `promtool check config` verifies the token file exists, so
`prometheus/secrets/api_metrics_token` must be present — the committed
`.example` alone does not satisfy it. Run the `cp` from "Secrets" first
(the relative `credentials_file` path resolves against the config's own
directory both here and in the container).

## Verification once the node half ships (FU-14)

- `http://localhost:9090/targets` (via tunnel) shows all targets `up`.
- Stop MediaMTX on a staging node → the "MediaNodeDown" email arrives
  within 4 minutes → start it again → the alert resolves.
