# Kubernetes observability charts

Production-style central stack and per-cluster edge collectors. **Start here:** [GETTING_STARTED.md](../../GETTING_STARTED.md) (Path A lab install).

## Charts

| Chart | Role |
|-------|------|
| **observability-central** | Prometheus, Grafana, Victoria Metrics (single + optional cluster), Victoria Logs (single + optional cluster), OTel gateway & DaemonSet, blackbox, vmbackup, Gateway API HTTPRoutes |
| **observability-edge** | OTel DaemonSet on **remote** clusters → central OTLP HTTPS URL |
| **project-kpi** | Optional Victoria Metrics KPI archive CronJobs (S3)—same credential pattern as `vmBackup` |

## Log and metric backends (Kubernetes)

| Signal | Primary store in this chart | Notes |
|--------|----------------------------|--------|
| Scraped metrics | Prometheus | ServiceMonitors, `additionalScrapeConfigs`, SNMP jobs |
| OTLP metrics | Victoria Metrics (single by default) | OTel `prometheusremotewrite` / OTLP HTTP |
| OTLP logs | Victoria Logs (single by default) | OTel → VL; Grafana **Victoria Logs** datasource |
| Legacy Docker path | See `vm-docker/` | Uses **Loki**, not Victoria Logs |

## Deployment order

1. Install **observability-central** in namespace `observability` (`helm-install-central.sh lab` or production values).
2. **Production:** Gateway API routes + TLS on your shared Gateway; Secrets `grafana-admin`, `grafana-secret`, optional `s3-credentials`.
3. Point agents at `https://otel.<domain>` (Ansible `inventory` or **observability-edge**).
4. Optional: **project-kpi** if you use long-term KPI archives to S3.

Replace all placeholders: [PLACEHOLDERS.md](../../PLACEHOLDERS.md).

## Values files

| File | Use |
|------|-----|
| `values.yaml` | Production template (as deployed in our environment, sanitized) |
| `values.local.lab.yaml` | Lab overlay (no Gateway API / OAuth / S3 backup; default StorageClass) |
| `values.local.production.example.yaml` | Copy to `values.local.yaml` and edit |
| `values-production.yaml` | Optional HA (Prometheus replicas, OTel replicas) |

Legacy dashboard JSON under `config/grafana/provisioning/dashboards/json/` is kept for compatibility; new dashboards live under `access/`, `cloud/`, `k8s/`, etc.
