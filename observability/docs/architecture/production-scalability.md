# Production scalability – observability stack

This document describes **production-oriented scaling** for the central Kubernetes chart: Prometheus HA, OTel gateway replicas, and optional **Victoria Logs cluster** mode. Merge **`values-production.yaml`** with `values.yaml` and your `values.local.yaml`.

The **Helm chart uses Victoria Logs** for OTLP logs (not Loki). For a **Loki**-based stack on a single VM, use `vm-docker/central-stack/`.

---

## 1. Victoria Logs – single vs cluster

**Reference:** [VictoriaLogs Helm charts](https://docs.victoriametrics.com/victorialogs/)

| Mode | Values | When |
|------|--------|------|
| **Single** | `victoria-logs-single.enabled: true` (default in `values.yaml`) | Dev, lab, moderate log volume |
| **Cluster** | `victoria-logs-cluster.enabled: true`, disable single | Higher ingest/query load, HA |

Enabling the cluster requires overlays documented in `values.yaml` (`victoria-logs-cluster` section):

- OTel `logs_endpoint` → `vlinsert` service URL  
- Grafana Victoria Logs datasource → `vlselect` URL  

Plan capacity (CPU, disk, `vlstorage` PVCs) per VictoriaMetrics sizing guides.

---

## 2. Prometheus – HA and scaling

**Reference:** [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

- **Single replica** (`values.yaml`): fine for lab.
- **Production:** **2 replicas** for scrape continuity during upgrades/failures.

**`values-production.yaml`:** `prometheusSpec.replicas: 2`

OTLP metrics from agents are stored in **Victoria Metrics** (separate from Prometheus scrapes).

---

## 3. OTel Collector gateway – scaling

**Reference:** [OpenTelemetry Collector Helm chart](https://github.com/open-telemetry/opentelemetry-helm-charts)

- Gateway Deployment (`otel-deploy`): increase `replicaCount`; use HPA if your overlay enables it.
- **Lab:** `values.local.lab.yaml` sets `replicaCount: 1`.

**`values-production.yaml`:** `otel-deploy.replicaCount: 2`

---

## 4. Victoria Metrics cluster (optional)

`values.yaml` can enable **victoria-metrics-cluster** alongside single for migration or tiered use. **Lab** disables cluster via `values.local.lab.yaml`. For production cluster mode, size `vmstorage` PVCs and wire OTel exporters to the cluster insert endpoint per your overlay.

---

## 5. Deploying with production scalability

```bash
cd observability/kubernetes/charts/observability-central
helm dependency update
helm upgrade --install observability-central . -n observability --create-namespace \
  -f values.yaml -f values.local.yaml -f values-production.yaml
```

- **Lab:** `helm-install-central.sh lab` (`values.yaml` + `values.local.lab.yaml` only).
- **Production:** `values.local.yaml` (domain, StorageClass, OAuth, S3) + optional `values-production.yaml`.

Ensure the cluster has enough CPU/memory and StorageClass capacity for all PVCs (Prometheus, Grafana, Victoria Metrics, Victoria Logs).
