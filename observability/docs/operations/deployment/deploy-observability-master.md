# Deploying the observability system (master)

Guide to clone the repository and bring up the central observability stack in the cluster (namespace `observability`).

**Repository path:** `YOUR_ORG/clusters/k8s-infra/Repository/observability-central`

---

## 1. Prerequisites

- SSH access to the cluster node where Helm will run (e.g. **inf-1**).
- **Helm 3** (on MicroK8s: `microk8s helm3`).
- Cluster with namespace `observability` and Gateway API support (`gateway.networking.k8s.io/v1`).
- Cert-Manager installed (for TLS certificates managed via Gateway listeners in k8s-infra).

---

## 2. Get the code

Clone the repo (or pull if you already have it):

```bash
git clone <repository-url> observability-central
cd observability-central
```

Chart path inside the repo: `kubernetes/charts/observability-central/`.

---

## 3. Chart dependencies

From the chart directory:

```bash
cd kubernetes/charts/observability-central
microk8s helm3 dependency update
```

This fetches subcharts (kube-prometheus-stack, loki, victoria-metrics-single). With a standalone Helm install: `helm dependency update`.

---

## 4. Configuration (values)

- **Main file:** `kubernetes/charts/observability-central/values.yaml`
- Typical adjustments:
  - **Grafana route:** `gatewayAPI.grafana.hostname` and `gatewayAPI.grafana.sectionName`.
  - **OTel route:** `gatewayAPI.otelCollector.hostname` and `gatewayAPI.otelCollector.sectionName`.
- **Grafana admin:** The subchart creates the admin secret automatically; do not store credentials in values. Retrieve after install from the created Secret (see runbook).
- **Scheduling:** No nodeSelector/nodeAffinity; Kubernetes schedules workloads.

No edits are required for a first deploy if FQDNs are correct.

---

## 5. Deploy with Helm

On the node with cluster access (e.g. inf-1), with KUBECONFIG or context set:

```bash
cd kubernetes/charts/observability-central
microk8s helm3 dependency update
microk8s helm3 upgrade --install observability-central . -n observability --create-namespace -f values.yaml
```

With standard Helm:

```bash
helm dependency update
helm upgrade --install observability-central . -n observability --create-namespace -f values.yaml
```

---

## 6. Routing and TLS (GitOps ownership)

Routing/TLS ownership is split by design:

1. **k8s-infra (`cluster/crds`) owns** Gateway listeners and certificates.
2. **observability chart owns** app `HTTPRoute` resources.
3. **No direct manual changes** on cluster; use MR + pipeline.

Checks:
```bash
microk8s kubectl get gateway -n envoy-gateway-system
microk8s kubectl get httproute -n observability
microk8s kubectl get certificate -n envoy-gateway-system
```

---

## 7. Verification

```bash
# Pods
microk8s kubectl get pods -n observability -o wide

# Services
microk8s kubectl get svc -n observability

# PVCs
microk8s kubectl get pvc -n observability
```

- **Grafana:** https://grafana.yourdomain.tld (user/password from Secret; see runbook).
- **OTel (Cloud):** OTLP endpoint: **https://otel.yourdomain.tld** (external HTTPS 443, backend OTLP HTTP 4318).
- **Victoria Metrics (internal):** `http://observability-central-victoria-metrics-single:8428` (Grafana datasource already configured).

---

## 8. Agents (Ansible)

For OTel agents to send to the master:

- **inventory.ini:** point `master_otlp_http` / `master_otlp_grpc` to the gateway endpoint. Use the public URL `https://otel.yourdomain.tld` (port 443).
- Run the agent deploy playbook according to the Ansible repo documentation.

---

## 9. References

- **Day-to-day operations:** `../runbooks/runbook-observability.md`
- **Architecture and status:** `../../architecture/architecture-and-status-observability.md`
- **Chart:** `kubernetes/charts/observability-central/README.md`
