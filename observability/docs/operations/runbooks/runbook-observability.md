# Runbook: central observability

Operational procedures for the observability stack (namespace `observability`) in the cluster.

Repository: `YOUR_ORG/clusters/k8s-infra/Repository/observability-central`

---

## 1. Cluster access

- **SSH to node (e.g. inf-1):** `ssh inf-1`
- **Kubeconfig:** `export KUBECONFIG=/tmp/kube-obs.config`  
  If missing: `microk8s config > /tmp/kube-obs.config`
- **kubectl:** On MicroK8s use `microk8s kubectl` or `microk8s helm3`.

---

## 2. Quick verification

```bash
# Observability pods
microk8s kubectl get pods -n observability -o wide

# Services and PVCs
microk8s kubectl get svc,pvc -n observability

# Recent events
microk8s kubectl get events -n observability --sort-by=.lastTimestamp | tail -20
```

---

## 3. Grafana access

- **URL:** https://grafana.yourdomain.tld
- **User/password (source of truth):** In this environment, the **effective** Grafana admin credentials are whatever Grafana starts with at runtime. They may come from:
  - a Kubernetes Secret (e.g. `grafana-admin` via `admin.existingSecret`), **or**
  - explicit environment variables in the Deployment/Pod (e.g. `GF_SECURITY_ADMIN_USER`, `GF_SECURITY_ADMIN_PASSWORD`) which **override** values coming from a Secret.

### 3.1 Identify which credentials are actually in effect

```bash
# Inspect where Grafana gets credentials from (Secret refs / env vars)
microk8s kubectl get deployment grafana -n observability -o yaml | sed -n '1,220p'

# CAUTION: this can print sensitive values if they are set directly in env.
# Prefer checking only that variables exist (without printing the password):
microk8s kubectl exec -n observability deployment/grafana -c grafana -- sh -lc 'printenv GF_SECURITY_ADMIN_USER || true'
microk8s kubectl exec -n observability deployment/grafana -c grafana -- sh -lc 'test -n \"${GF_SECURITY_ADMIN_PASSWORD:-}\" && echo \"GF_SECURITY_ADMIN_PASSWORD is set\" || echo \"GF_SECURITY_ADMIN_PASSWORD is NOT set\"'
```

### 3.2 Manage credentials via Secret (recommended)

If the Deployment is configured with `admin.existingSecret: grafana-admin` and there are **no overriding** `GF_SECURITY_ADMIN_*` variables, then `grafana-admin` is the canonical source.

**Create or update the admin credentials** (run once per cluster or when changing user/password):

```bash
# Replace YOUR_USER and YOUR_PASSWORD with the desired Grafana admin user and password.
microk8s kubectl create secret generic grafana-admin -n observability \
  --from-literal=admin-user='YOUR_USER' \
  --from-literal=admin-password='YOUR_PASSWORD' \
  --dry-run=client -o yaml | microk8s kubectl apply -f -

# Restart Grafana so it picks up the secret (if it already existed)
microk8s kubectl rollout restart deployment grafana -n observability
```

**Retrieve stored credentials from the Secret** (only if this Secret is actually used by the Deployment):

```bash
microk8s kubectl get secret grafana-admin -n observability -o jsonpath='{.data.admin-user}' | base64 -d; echo
microk8s kubectl get secret grafana-admin -n observability -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

### 3.3 If you cannot log in

- If `GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD` are set in the Deployment/Pod, they override the Secret. In that case, updating `grafana-admin` alone may **not** change the effective login.
- If credentials are managed by Secret, ensure `grafana-admin` exists with keys `admin-user` and `admin-password`, then restart the Grafana deployment.

---

## 4. Routing and TLS (Gateway API)

The cluster migrated to **Gateway API** (Envoy Gateway). Use GitOps only.

- **Do not apply routing changes manually on the cluster.**
- **Gateway listeners and certificates** are managed centrally in `clusters/k8s-infra/cluster/crds`.
- The observability chart manages only **HTTPRoute** resources (Option B), referencing existing listeners with `parentRef` and `sectionName`.

Required listener references for observability:

- Grafana: `sectionName: grafana-https` (`grafana.yourdomain.tld`)
- OTel: `sectionName: otel-https` (`otel.yourdomain.tld`)

Checks:

```bash
microk8s kubectl get gateway -n envoy-gateway-system
microk8s kubectl get httproute -n observability
microk8s kubectl get certificate -n envoy-gateway-system
```

---

## 5. Common issues

### Victoria Metrics does not start or gets evicted

- **Typical cause:** Pod on a node with DiskPressure or PVC on another node.
- **Fix:** Scheduling is left to Kubernetes (no nodeSelector). If the PVC was created on a problematic node, scale down, delete the PVC and redeploy so a new PVC is created.

### Grafana shows no Loki / VM data

- Ensure Loki and Victoria Metrics pods are Running.
- In Grafana → Connections → Data sources: run Save and test for Loki and Victoria Metrics.

### OTel: agents not sending

- Ensure the OTel Collector pod is Running: `microk8s kubectl get pods -n observability -l app.kubernetes.io/name=opentelemetry-collector`
- Check logs: `microk8s kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector --tail=50`
- Verify Gateway API route and certs are ready (see §4).
- Cloud endpoint: **https://otel.yourdomain.tld** (external HTTPS 443; backend OTLP HTTP 4318).
- Helm release: `otel-collector-chart` (official opentelemetry-collector chart v0.147.1).

### Alertmanager disabled

- Currently `alertmanager.enabled: false` due to cluster service CIDR conflict. Prometheus rules still evaluate; operational alerting is via Grafana Alerting or by enabling Alertmanager once the service IP range is fixed.

---

## 6. Grafana dashboards (provisioned vs imported)

- **Provisioned** (JSON in the chart / ConfigMaps): always applied on deploy; that is how we ship the standard dashboards.
- **Imported in the UI:** stored in Grafana’s database on the **PVC** (when `grafana.persistence.enabled: true`). They **survive `helm upgrade` and pod restarts** because the claim is kept.
- **Helm does not copy** UI-imported dashboards into the chart. To version them in Git, export JSON and add under `kubernetes/charts/observability-central/config/grafana/provisioning/dashboards/json/`.

Check PVC: `microk8s kubectl get pvc -n observability | grep -i grafana`

---

## 7. Restarts and deploy

```bash
# Restart Grafana
microk8s kubectl rollout restart deployment grafana -n observability

# Restart OTel Collector (official chart release)
microk8s kubectl rollout restart deployment otel-collector-chart -n observability

# Update the main stack (from the chart directory)
microk8s helm3 dependency update
microk8s helm3 upgrade --install observability-central . -n observability -f values.yaml

# Update the OTel Collector chart separately
helm upgrade otel-collector-chart open-telemetry/opentelemetry-collector \
  -n observability -f /path/to/otel-values.yaml

# Apply Grafana dashboards (outside Helm release due to 1MB secret limit)
kubectl create configmap grafana-dashboards-json -n observability \
  --from-file=config/grafana/provisioning/dashboards/json/ \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## 8. References

- **Deploy from scratch:** `../deployment/deploy-observability-master.md`
- **Architecture and status:** `../../architecture/architecture-and-status-observability.md`
- **Loki and memory (caches):** `../../incidents/loki-chunks-cache-memory.md`
