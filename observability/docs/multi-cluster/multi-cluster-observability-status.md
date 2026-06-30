# Multi-cluster observability: status and next steps

**Short answer:** Multi-cluster log collection is **operational**. Edge clusters (prod-cluster, dev-cluster) run an OTel daemonset that forwards logs and metrics via OTLP to the central gateway on the assembly cluster, which stores logs in Victoria Logs and metrics in Victoria Metrics.

---

## 1. Current state

| Cluster (Argo destination) | What runs there | Where telemetry goes |
|----------------------------|-----------------|----------------------|
| **in-cluster** (Assembly) | observability-central (Prometheus, Victoria Metrics, Victoria Logs, OTel gateway + daemonset), ArgoCD, Envoy Gateway, etc. | Stays here; this is the central stack. |
| **prod-cluster** | OTel daemonset (observability-edge), kube-prometheus-stack (pending decommission of local node-exporter/kubelet scrapers) | **Central.** OTLP → `https://otel.yourdomain.tld` → Victoria Metrics + Victoria Logs on assembly. |
| **dev-cluster** | Same pattern as prod-cluster. | **Central.** OTLP → same gateway. |

Multi-cluster logging is **complete** (Phase 1 done). Victoria Logs Cluster installation is the next step (see below).

---

## 2. Central endpoint

Our OTel Collector gateway (alias `otel-deploy`) is exposed at:

- **URL:** `https://otel.yourdomain.tld`
- **Metrics (OTLP HTTP):** `https://otel.yourdomain.tld/v1/metrics`
- **Logs (OTLP HTTP):** `https://otel.yourdomain.tld/v1/logs`

The gateway forwards metrics to Victoria Metrics and logs to Victoria Logs in the `observability` namespace.

---

## 3. Pending work

### Phase 2 — Victoria Logs Cluster (production)

Victoria Logs Single is running for dev/staging. For production we need the cluster mode:

1. Add `victoria-logs-cluster` dependency to `observability-central` chart (done in MR 1).
2. Enable it in the `k8s-observability` overlay with `csi-cinder-sc-retain` storage (MR 3).
3. Update OTel `logs_endpoint` → vlinsert, Grafana datasource → vlselect (MR 3).
4. Validate logs in Grafana, then disable `victoria-logs-single`.

### Phase 3 — De-duplicate kube-state-metrics / kubelet collectors

`kube-prometheus-stack` and `otel-daemonset` both collect node/kubelet metrics on edge clusters. Goal: disable the redundant scrapers in `kube-prometheus-stack` on the assembly cluster (`k8s-observability` overlay) after OTel daemonset coverage is confirmed.

### Phase 4 — Alerts framework + dashboards

- Alerting rules in `rules.yml` using Victoria Metrics as datasource.
- Dashboard for Ceph and OpenStack (labels/job to be confirmed with Cloud team).

---

## 4. References

- **k8s-observability (local):** `~/Documents/k8s-observability/resources/applications/templates/`
- **Central OTel endpoint:** `otel-endpoint-cloud-team.md`
- **Central stack:** `../architecture/architecture-and-status-observability.md`
- **Labels schema:** `multi-cluster-labels-schema.md`
