# Production scalability – observability stack

This document describes the **production-oriented scalability** options for the central observability stack (Loki, Prometheus, OTel Collector), based on official documentation. Use **`values-production.yaml`** when deploying for production to enable scalable configurations.

---

## 1. Loki – Distributed (microservices) mode

**Official reference:** [Install the microservice Helm chart | Grafana Loki](https://grafana.com/docs/loki/latest/setup/install/helm/install-microservices/)

- **SingleBinary** (default in `values.yaml`): single process, suitable for small / demo installs.
- **SimpleScalable**: read / write / backend targets; **being deprecated before Loki 4.0** — not recommended for new production.
- **Distributed (microservices)**: separate components (distributor, ingester, querier, query-frontend, query-scheduler, index-gateway, compactor). Recommended for **production** and high availability.

**Requirements for Distributed:**

- **Object storage** (S3-compatible or MinIO). Filesystem storage is **not** recommended for microservices mode.
- At least **3 nodes** for HA; replicas as in the [microservices install guide](https://grafana.com/docs/loki/latest/setup/install/helm/install-microservices/).

**What `values-production.yaml` does for Loki:**

- `deploymentMode: Distributed`
- Component replicas: ingester 3, distributor 3, querier 3, query-frontend 2, query-scheduler 2, index-gateway 2, compactor 1
- **MinIO** enabled as S3-compatible object storage (replace with real S3/Azure/GCS in production if desired)
- Storage and schema use `object_store: s3` and `storage.type: s3`
- Gateway enabled as single entrypoint for write/read

**Migration from SingleBinary:**  
Switching to Distributed implies a new storage layout (object storage). Plan for a **new install or migration** (e.g. dual-write, cutover). See [Loki Helm chart upgrade/migrate](https://grafana.com/docs/loki/latest/setup/install/helm/) and the chart’s migration notes.

---

## 2. Prometheus – HA and scaling

**Official reference:** [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) (Prometheus Operator).

- **Single replica** (default in `values.yaml`): one Prometheus instance; fine for dev/demo.
- **Production:** run **2 replicas** for HA so that one instance can be down (upgrades, failures) without losing scrape capacity.

**What `values-production.yaml` does for Prometheus:**

- `prometheusSpec.replicas: 2`

Optional (not in the override file by default):

- Increase `retention` and storage size if needed.
- For global/federated setups, consider [Thanos](https://thanos.io/) or [VictoriaMetrics](https://victoriametrics.com/) (we already use VM for the OTel path).

---

## 3. OTel Collector – scaling

**Official reference:** [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) and [opentelemetry-helm-charts](https://github.com/open-telemetry/opentelemetry-helm-charts).

- The gateway Deployment can be scaled by **replicas** and **HPA**.
- **Minimum 2 replicas** for HA; scale out under load.

**What `values-production.yaml` does for OTel:**

- `replicas: 2` (or keep as in base values)
- HPA: `minReplicas: 2`, `maxReplicas: 10`, `targetCPUUtilizationPercentage: 70`

Adjust `maxReplicas` and resources based on expected OTLP throughput.

---

## 4. Deploying with production scalability

From the chart directory:

```bash
helm dependency update
helm upgrade --install observability-central . -n observability --create-namespace \
  -f values.yaml -f values-production.yaml
```

- **Default (current behaviour):** use only `-f values.yaml` (Loki SingleBinary, Prometheus 1 replica, OTel as in base).
- **Production:** add `-f values-production.yaml` to enable Loki Distributed (+ MinIO), Prometheus 2 replicas, and OTel production scaling.

Ensure the cluster has enough resources (CPU/memory and, for Loki Distributed, object storage and node count as per [Loki microservices install](https://grafana.com/docs/loki/latest/setup/install/helm/install-microservices/)).
