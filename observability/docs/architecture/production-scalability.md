# Production scalability – observability stack

Scaling options for the **Kubernetes** chart: Prometheus HA, OTel gateway replicas, and optional **Victoria Logs / Victoria Metrics cluster** modes. Merge **`values-production.yaml`** with `values.yaml` and your `values.local.yaml`.

The Helm chart stores OTLP logs in **Victoria Logs** (not Loki). For Loki on a single VM, use `vm-docker/central-stack/`.

---

## 1. Victoria Logs – single vs cluster

| Mode | Values | When |
|------|--------|------|
| **Single** | `victoria-logs-single.enabled: true` (default) | Lab / moderate volume |
| **Cluster** | `victoria-logs-cluster.enabled: true`, disable single | Higher ingest/query load, HA |

Cluster mode also needs overlays documented in `values.yaml`:

- OTel `logs_endpoint` → `vlinsert`
- Grafana Victoria Logs datasource → `vlselect`
- Optional `vlBackupCluster` CronJobs to S3 (`s3-credentials` Secret)

---

## 2. Prometheus – HA

**Reference:** [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

- Lab: 1 replica
- Production: `values-production.yaml` sets `prometheusSpec.replicas: 2`

OTLP metrics from agents live in **Victoria Metrics**, separate from Prometheus scrapes.

---

## 3. OTel Collector gateway

- Lab: `values.local.lab.yaml` → `otel-deploy.replicaCount: 1`
- Production: `values-production.yaml` → `replicaCount: 2` (add HPA in your overlay if needed)

---

## 4. Victoria Metrics cluster (optional)

`values.yaml` may enable **victoria-metrics-cluster** for migration/tiered use. Lab disables it. Wire OTel exporters / Grafana `temporaryURI` to `vmselect` when cluster is primary.

---

## 5. Deploy

```bash
cd observability/kubernetes/charts/observability-central
helm dependency update
helm upgrade --install observability-central . -n observability --create-namespace \
  -f values.yaml -f values.local.yaml -f values-production.yaml
```

Ensure enough CPU/memory and StorageClass capacity for all PVCs.
