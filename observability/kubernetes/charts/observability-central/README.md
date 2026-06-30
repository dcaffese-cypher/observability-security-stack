# observability-central

Central observability on Kubernetes: **kube-prometheus-stack** + **Victoria Metrics** + **Victoria Logs** + **OpenTelemetry Collector** (gateway Deployment + node DaemonSet). Aligned with **Gateway API** (HTTPRoute to Grafana and OTel) in production.

**Quick start (lab):** [GETTING_STARTED.md](../../../GETTING_STARTED.md) Path A — `../../../scripts/helm-install-central.sh lab`

## Architecture (this chart)

| Component | Role |
|-----------|------|
| **Prometheus** | Scrapes (K8s, blackbox, SNMP targets you configure) |
| **Victoria Metrics (single)** | Stores OTLP metrics from the OTel gateway |
| **Victoria Logs (single)** | Stores OTLP logs from the OTel gateway |
| **OTel `otel-deploy`** | OTLP ingress; exports to VM / VL |
| **OTel `otel-daemonset`** | Node logs & host/kubelet metrics on the central cluster |
| **Grafana** | Dashboards, alerting, Explore / Drilldown (Victoria Logs plugin) |

Cloud and remote clusters send **OTLP only** to `https://otel.<domain>`; they do not need direct access to Victoria Metrics or Victoria Logs.

**Not in this chart:** Loki (use `vm-docker/central-stack` for a Loki-based lab on Docker).

## Requirements

- Helm 3, kubectl
- **Lab:** any cluster with default StorageClass, ~8 GB RAM node recommended
- **Production:** Gateway API (`gateway.networking.k8s.io/v1`), TLS on Gateway listeners, Secrets (see below), `StorageClass` name in values

Optional: `snmp-exporter` in-cluster if you enable Cumulus SNMP scrape jobs.

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
kubectl apply -f manifests/grafana-secret.example.yaml   # after filling stringData
helm upgrade --install observability-central . -n observability --create-namespace \
  -f values.yaml -f values.local.yaml
```

Optional HA: add `-f values-production.yaml`.

MicroK8s: use `microk8s helm3` / `microk8s kubectl` instead of `helm` / `kubectl`.

## Grafana (production)

- **URL:** `https://grafana.<domain>` via `gatewayAPI.grafana` HTTPRoute
- **Admin:** Secret `grafana-admin` (`admin-user`, `admin-password`) — see `../../../scripts/create-grafana-secret.sh`
- **GitHub OAuth:** `auth.github` in `values.yaml`; credentials in Secret `grafana-secret` from [manifests/grafana-secret.example.yaml](manifests/grafana-secret.example.yaml)
- **Mission orgs:** post-install Job [templates/grafana-org-bootstrap.yaml](templates/grafana-org-bootstrap.yaml) (Assembly, Cloud, …)—disable in a custom overlay if you do not need multi-org

## OTel gateway (production)

- **URL:** `https://otel.<domain>` → Service port 4318 (HTTP OTLP)
- **Lab:** `kubectl port-forward -n observability svc/otel-collector-central 4318:4318`

## Values layout

| File | Purpose |
|------|---------|
| `values.yaml` | Full production template (dashboards, alerting, blackbox, vmbackup, OAuth mapping) |
| `values.local.lab.yaml` | Disables Gateway API, OAuth, vmbackup, VM-cluster; uses default StorageClass |
| `values.local.production.example.yaml` | Starting point for `values.local.yaml` |
| `values-production.yaml` | Prometheus + OTel replica bumps |

## Dashboards and alerting

Provisioned from `config/grafana/provisioning/` (mission folders + legacy `json/`). After upgrade, if UI is stale: `kubectl rollout restart deployment/grafana -n observability`.

## Backup

`vmBackup` CronJobs need Secret `s3-credentials` and bucket settings in values. Disabled automatically in lab overlay.

## More documentation

- [docs/architecture/production-scalability.md](../../docs/architecture/production-scalability.md)
- [docs/operations/runbooks/runbook-observability.md](../../docs/operations/runbooks/runbook-observability.md)
- [PLACEHOLDERS.md](../../PLACEHOLDERS.md)
