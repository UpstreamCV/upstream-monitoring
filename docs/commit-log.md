# Commit log

Reverse chronological. Newest at top. Every commit updates this file
(plus any relevant docs) in the same commit, per the Upstream repo
policy.

---

## 2026-06-11 — smtp_from: hello@upstreamcv.com

**Type:** config. `alerts@upstreamcv.com` does not exist as an address;
`hello@upstreamcv.com` is real, so bounces/replies land somewhere and
only one already-owned address needs relay verification. README table
updated. `amtool check-config` green.

---

## 2026-06-11 — SMTP password moved to a secrets file

**Type:** config. `smtp_auth_password` replaced with
`smtp_auth_password_file: /etc/alertmanager/secrets/smtp_password`
(mounted from `alertmanager/secrets/`, gitignored, `.example`
committed — same pattern as the Prometheus token). README SMTP table
updated. Validated with `amtool check-config` against the real mount
path.

---

## 2026-06-11 — Alert recipient set to elkan@upstreamcv.com

**Type:** config. `alertmanager/alertmanager.yml` receiver `to:` and
`smtp_from` set to real addresses; SMTP relay values remain `.invalid`
placeholders (no mail can send until a real relay is configured per
README). Validated with `amtool check-config` (v0.32.2).

---

## 2026-06-11 — Initial import: Kuma/Caddy stack + Prometheus/Alertmanager (FU-14 / M9.2)

**Type:** initial repo import. The directory previously lived
un-versioned on the monitoring box (status.upstreamcv.com, AWS
us-east-2; bootstrapped via `bootstrap.sh` on Lightsail Ubuntu 22.04).

**What's in the import:**

- `docker-compose.yml` — the pre-existing Uptime Kuma (black-box
  checks, public status page) + Caddy (TLS for status.upstreamcv.com)
  services, unchanged; plus the new white-box pair added for FU-14 /
  M9.2 (designed in
  `upstream-streaming-server/docs/design/01-observability.md`):
  `prom/prometheus:v3.12.0` (127.0.0.1:9090, 30d retention) and
  `prom/alertmanager:v0.32.2` (127.0.0.1:9093, named data volume for
  silences). Image pins match the versions promtool/amtool validation
  ran against.
- `prometheus/prometheus.yml` — 30s scrapes: api-server `/metrics`
  (bearer token via `secrets/api_metrics_token`, gitignored; commit the
  `.example` only), MediaMTX `ingest.upstreamcv.com:19998` (target up
  once the ingest box exposes/firewalls the metrics port), node
  exporter (pending install), self-scrape.
- `prometheus/alerts.yml` — the 8 alert rules from design doc 01 §6;
  rules referencing future metrics (`sweeper_stuck_sessions`,
  `reconciler_path_drift`, `hookd_dead_letters`,
  `session_starts_total{camera_id}`) are commented with the milestone
  that ships each name — the names are contractual (pinned in doc 01
  §3).
- `alertmanager/alertmanager.yml` — single email receiver with
  deliberately-invalid placeholder SMTP values; fill per README before
  expecting mail.
- `Caddyfile`, `bootstrap.sh` — unchanged from the original box setup.
- `README.md` — deploy runbook (compose up, secrets file, SSH-tunnel
  access pattern for the localhost-bound Prometheus/Alertmanager UIs).

**Verification:** `docker compose config -q`, `promtool check
config`/`check rules`, and `amtool check-config` all pass (run via the
pinned images). Kuma/Caddy behavior unchanged.
