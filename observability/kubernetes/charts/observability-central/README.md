# observability-central

Central observability on Kubernetes: **kube-prometheus-stack** + **Victoria Metrics** + **Victoria Logs** + **OpenTelemetry Collector** (gateway Deployment + node DaemonSet). Production installs attach Grafana and OTel via **Gateway API** HTTPRoutes.

**Quick start (lab):** [GETTING_STARTED.md](../../../GETTING_STARTED.md) Path A — `../../../scripts/helm-install-central.sh lab`

## Architecture (this chart)

| Component | Role |
|-----------|------|
| **Prometheus** | Scrapes (K8s, blackbox, SNMP targets you configure) |
| **Victoria Metrics (single)** | Stores OTLP metrics from the OTel gateway |
| **Victoria Logs (single)** | Stores OTLP logs from the OTel gateway |
| **OTel `otel-deploy`** | OTLP ingress; exports to VM / VL |
| **OTel `otel-daemonset`** | Node logs & host/kubelet metrics on the central cluster |
| **Grafana** | Dashboards, alerting, Explore (Victoria Logs plugin) |
| **vmBackup / vlBackupCluster** | Optional S3 snapshot CronJobs (disabled in lab overlay) |

Cloud and remote clusters send **OTLP only** to `https://otel.<domain>`.

**Not in this chart:** Loki (use `vm-docker/central-stack` for a Loki-based lab on Docker).

## Requirements

- Helm 3, kubectl
- **Lab:** any cluster with default StorageClass, ~8 GB RAM recommended
- **Production:** Gateway API, TLS on Gateway listeners, Secrets (below), StorageClass name in values

Optional: `snmp-exporter` if you enable Cumulus SNMP scrape jobs.

## Install

### Lab (port-forward, admin login)

```bash
# From repo root
./observability/scripts/create-grafana-secret.sh
./observability/scripts/helm-install-central.sh lab
./observability/scripts/port-forward-ui.sh
# http://localhost:3000  user: admin
```

### Production template (`values.yaml` + your overlay)

```bash
cd observability/kubernetes/charts/observability-central
helm dependency update
cp values.local.production.example.yaml values.local.yaml
# Edit YOUR_DOMAIN, YOUR_STORAGE_CLASS, YOUR_GITHUB_ORG, S3, gateway parentRef
# Create grafana-secret from manifests/grafana-secret.example.yaml
helm upgrade --install observability-central . -n observability --create-namespace \
  -f values.yaml -f values.local.yaml
```

Optional HA: add `-f values-production.yaml`.

## Grafana (production)

- **URL:** `https://grafana.<domain>` via `gatewayAPI.grafana` HTTPRoute
- **Admin:** Secret `grafana-admin` — `../../../scripts/create-grafana-secret.sh`
- **GitHub OAuth:** `auth.github` in `values.yaml`; credentials in Secret `grafana-secret`
- **Mission orgs:** post-install Job `grafana-org-bootstrap` (Assembly, Cloud, Access, …)

## Values layout

| File | Purpose |
|------|---------|
| `values.yaml` | Full production template (dashboards, alerting, blackbox, backups, OAuth mapping) |
| `values.local.lab.yaml` | Disables Gateway API, OAuth, vm/vl backup, cluster backends; default StorageClass |
| `values.local.production.example.yaml` | Starting point for `values.local.yaml` |
| `values-production.yaml` | Prometheus + OTel replica bumps |

## What to replace before production

See [PLACEHOLDERS.md](../../../PLACEHOLDERS.md): domains, StorageClass, GitHub org, S3 endpoint/bucket, SNMP example IPs (`192.0.2.10`–`.13`), blackbox probe URLs.

## Dashboards and alerting

Provisioned under `config/grafana/provisioning/` (mission folders: `access/`, `cloud/`, `k8s/`, `tenant/`, …). After upgrade: `kubectl rollout restart deployment/grafana -n observability`.

## More documentation

- [docs/architecture/production-scalability.md](../../docs/architecture/production-scalability.md)
- [docs/operations/runbooks/runbook-observability.md](../../docs/operations/runbooks/runbook-observability.md)
- [PLACEHOLDERS.md](../../../PLACEHOLDERS.md)
