# Kubernetes charts

| Chart | Role |
|-------|------|
| **observability-central** | Central stack: Prometheus, Grafana, Victoria Metrics, Victoria Logs, OTel |
| **observability-edge** | DaemonSet OTel for remote clusters → central OTLP URL |
| **project-kpi** | Optional VM KPI archive CronJobs (S3) |

Start here: [../GETTING_STARTED.md](../GETTING_STARTED.md).

## Deploy order

1. Install **observability-central** (`./scripts/helm-install-central.sh lab` or production values).
2. Production: Gateway API + TLS; Secrets `grafana-admin` / `grafana-secret` / optional `s3-credentials`.
3. Point agents at `https://otel.<domain>` (`playbooks/otel-agent` or **observability-edge**).

Placeholders: [../PLACEHOLDERS.md](../PLACEHOLDERS.md).
