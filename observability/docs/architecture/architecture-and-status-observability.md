# Architecture and status: central observability

Unified document: stack architecture, risks, implemented improvements, and current cluster status (namespace `observability`).

Repository: `YOUR_ORG/assembly/observability` (structure: `kubernetes/charts/observability-central`, `kubernetes/gitops/`, `docs/`).

---

## 1. Current architecture

```
                    ┌──────────────────────────────────────────────────────────────────┐
                    │                    CLUSTER (observability namespace)               │
                    │                                                                    │
  Edge agents ──────►  Envoy Gateway (Gateway API)                                      │
  (OTLP HTTPS)      │  otel.yourdomain.tld:443 ──► OTel Collector (deploy) ─┬──► Victoria Metrics Single (8428)
                    │                                       OTel Collector (daemonset)│
                    │                                                                └──► Victoria Logs Single/Cluster (9428)
                    │                                                                              ▲
  Users             │  grafana.yourdomain.tld:443 ──► Grafana (1 pod) ───────┬────────────┤
                    │                                                                │             │
                    │  Prometheus (1 pod, 20Gi) ◄── scrapes k8s + SNMP + OTel      ▼             ▼
                    │                                                         Victoria Metrics  Victoria Logs
                    │                                                           (9090 / 8428)     (9428)
                    └──────────────────────────────────────────────────────────────────┘

  k8s_cluster metrics ──► OTel Collector ──► filter/archive-1 (argocd ns) ──► kpi-archive-1
```

**Data flows:**
- **Metrics (scrape):** Prometheus scrapes cluster targets + SNMP (Cumulus) → Prometheus only (pending migration to vmagent).
- **Metrics (OTel):** Agents/Edge clusters → OTel Collector → Victoria Metrics. Grafana queries VM (and Prometheus).
- **Metrics (archive):** k8s_cluster receiver → filter argocd namespace → kpi-archive-1 (Sean's MR#10 pattern).
- **Logs:** Edge clusters (OTel daemonset) → OTel gateway → Victoria Logs. Grafana queries Victoria Logs.

**OTel Collector:** deployed via official `opentelemetry-collector` Helm chart (v0.147.1, app v0.131.0).
- `clusterMetrics` preset: k8s_cluster receiver + RBAC managed by the chart.
- 1 replica (required by clusterMetrics preset to avoid duplicate cluster metrics).
- Service name: `otel-collector-chart` (ports 4317 gRPC, 4318 HTTP, 8888 metrics).

**Ownership model (Option B):**
- `k8s-infra`: Gateway, listeners, certificates.
- `observability` chart: HTTPRoutes, all application resources.

---

## 2. Risks and limitations

| Aspect | Situation |
|--------|-----------|
| **SPOF** | Prometheus, Victoria Metrics, Victoria Logs and Grafana at 1 replica (single mode); node/pod failure implies temporary loss of service or data. |
| **OTel single replica** | clusterMetrics preset requires replicaCount=1; OTLP ingestion HA relies on Envoy Gateway load balancing. |
| **Concentration on assembly cluster** | Prometheus, Victoria Metrics, Victoria Logs and part of the platform (ArgoCD, Envoy Gateway, Vault) on the assembly cluster. |
| **Storage** | One PV per component; no replication across nodes. VM and VL backup strategy via CronJobs (requires S3 credentials secret). |
| **Alertmanager** | Disabled due to cluster service CIDR conflict; Prometheus rules still evaluate. |

---

## 3. Implemented improvements

| Priority | Recommendation | Implementation |
|----------|----------------|-----------------|
| High | OTel official chart | Migrated from custom Deployment to `opentelemetry-collector` subchart v0.147.1. |
| High | k8s_cluster receiver | Enabled via `clusterMetrics` preset; RBAC managed by chart. |
| High | archive-1 pipeline | `metrics/archive-1`: k8s_cluster + filter argocd → kpi-archive-1. |
| High | Grafana admin secret | Created by Grafana subchart; no credentials in repo. |
| Medium | Grafana PDB | PDB minAvailable 1. |
| Medium | Alertmanager | Disabled until CIDR is resolved; documented. |
| Medium | Edge health monitoring | Blackbox exporter probing grafana.yourdomain.tld and otel.yourdomain.tld (TLS + availability). |
| Low | VM backup | CronJobs prepared (disabled); aligned with Sean's kpi-archive-1 pattern. |
| Other | Routing / TLS ownership | Gateway listeners + certs in `k8s-infra`; chart owns only HTTPRoute resources (Option B). |
| Other | Dashboard size | Grafana dashboard JSONs applied via kubectl (outside Helm release) to stay under 1MB secret limit. |

---

## 4. Current status of namespace `observability`

### 4.1 Pods

| Component | Expected | Status | Notes |
|-----------|----------|--------|-------|
| Grafana | 1 | Running | 3/3 containers |
| Prometheus | 1 | Running | 2/2 containers |
| Loki | 1 | Running | 2/2; caches disabled |
| OTel Collector | 1 | Running | official chart; k8s_cluster + archive-1 |
| Victoria Metrics | 1 | Running | 20Gi PVC |
| Blackbox Exporter | 1 | Running | probing grafana + otel endpoints |
| Kube state metrics | 1 | Running | |
| Node exporter | DaemonSet | Running | |
| Kube operator | 1 | Running | |

### 4.2 Resilience

- **PDB:** grafana (minAvailable 1).
- **TLS:** cert-manager via Gateway API listeners for Grafana and OTel; certificates Ready.
- **OTel:** 1 replica (clusterMetrics constraint); Envoy Gateway provides external HA.

### 4.3 Helm releases in namespace

| Release | Chart | Purpose |
|---------|-------|---------|
| `observability-central` | local chart | Grafana, Prometheus, Loki, VM, Blackbox, HTTPRoutes |
| `otel-collector-chart` | opentelemetry-collector v0.147.1 | OTel Collector (official chart) |

### 4.4 Status summary

| Aspect | Status |
|--------|--------|
| Metrics (scrape) | OK |
| Logs (Loki) | OK |
| Visualization (Grafana) | OK |
| OTel gateway | OK (official chart, k8s_cluster receiver active) |
| Archive pipeline | OK (filter/archive-1 → kpi-archive-1) |
| Edge health probes | OK (blackbox-exporter) |
| TLS | OK |
| Victoria Metrics | OK |

Pending: enable Alertmanager when the cluster service IP range is fixed.
