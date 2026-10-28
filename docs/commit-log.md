# Commit log

Reverse chronological. Newest at top. Every commit updates this file
(plus any relevant docs) in the same commit, per the Upstream repo
policy.

---

## 2026-10-27 — chore: add all-rights-reserved LICENSE

**Type:** license. Adds `LICENSE` ahead of making the repo public: copyright
Upstream Vision, Inc., all rights reserved. The source is visible for
reference only; no rights to use, copy, modify, or distribute it are
granted. Third-party components keep their own licenses.

- `LICENSE` (new).
- `docs/commit-log.md` — this entry.

---

## 2026-06-11 — IngestAuthSuccessLow fires on all-denied; README umask/644 consistency

**Type:** config + docs. Rule 5's success ratio was empty — and
therefore silent — whenever the `decision="allow"` series had never
been created, i.e. exactly the all-denied worst case (`sum()` over a
no-match selector returns empty, and arithmetic with an empty operand
is empty). The numerator is now `(sum(rate(...{decision="allow"}[15m]))
or vector(0))`, so all-denied evaluates to 0/total = 0 < 0.95 and
fires; no-traffic stays silent because the *denominator* is then empty
and `vector(0) / <empty>` is empty — which also made the old
`and sum(...) > 0` guard redundant (removed). Audited the other 7
rules for the same empty-vector class: none affected (rules 1–2 use
`up`, synthesized for every configured target even on failed scrapes;
rules 3/4/6 alert on `> N` of series their producers emit continuously
once shipped, so the bad value cannot exist without the series; rules
7–8 are ratios whose operands ship together from the same exporter).
Audit reasoning recorded in the `alerts.yml` header; still exactly
8 rules. README: the Prometheus-token instructions opened with
`umask 077` (producing 600 files) while the SMTP-password section
requires 644 because the containers run as `nobody`; the token block
now uses an explicit `chmod 644` after create, drops the umask line,
and explains why a restrictive umask must not be used. Validated:
`promtool check rules` (SUCCESS, 8 rules), `promtool check config`,
`amtool check-config` (v0.32.2), plus a `promtool test rules` unit
test of the new expression (all-denied fires; no-traffic and
100%-allow stay silent).

---

## 2026-06-11 — Deployed to the status box; secrets files must be 644

**Type:** docs + deploy record. Stack is live on status.upstreamcv.com
(prometheus + alertmanager + existing kuma/caddy; api-server target
`up`, mediamtx pending a router port-forward for 19998 + the ingest-box
firewall run, node pending node_exporter). README corrected: secrets
files need `chmod 644`, not 600 — the prometheus/alertmanager
containers run as `nobody` and cannot read 600 files owned by `ubuntu`
(observed live as "unable to read authorization credentials").

---

## 2026-06-11 — SMTP relay: Resend (matches the upstream-web waitlist)

**Type:** config. `smtp_smarthost: smtp.resend.com:587`,
`smtp_auth_username: resend`; the password file now expects a dedicated
Resend API key (the upstream-web waitlist already sends from
`hello@upstreamcv.com` via Resend, so domain verification/DKIM/SPF are
in place — no Google Workspace relay setup needed). README rewritten
accordingly. `amtool check-config` green.

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
