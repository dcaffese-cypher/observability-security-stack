# Getting started (step by step)

This repository ships the **same central observability stack** we run in production: Prometheus (scrapes), **Victoria Metrics** (OTLP metrics), **Victoria Logs** (OTLP logs), **Grafana 12**, **OpenTelemetry Collector** (gateway + node DaemonSet), optional blackbox probes, vmbackup, and Gateway API routes. It is meant to be **cloned and deployed** with clear prerequisites—not a minimal demo chart.

**New here?** Read [ARCHITECTURE.md](./ARCHITECTURE.md) for the data flow, then pick a path below.

---

## 0. Clone and check your tools

```bash
git clone https://github.com/dcaffese-cypher/observability-security-stack.git
cd observability-security-stack
chmod +x observability/scripts/*.sh
./observability/scripts/check-prerequisites.sh
```

Install anything the script reports as missing, then run it again.

---

## Which deployment am I using?

| Path | Stack | Log backend | Best for |
|------|--------|-------------|----------|
| **A — K8s lab** | Helm `observability-central` | **Victoria Logs** | Try the full chart on any cluster (port-forward, no public DNS) |
| **B — K8s production** | Same chart + `values.local.yaml` | **Victoria Logs** (single or cluster overlay) | HTTPS Grafana/OTel, Gateway API, GitHub OAuth, S3 backup |
| **C — VM Docker** | `vm-docker/central-stack` | **Loki** | One Linux host, no Kubernetes |
| **D — Agents** | Ansible / `observability-edge` | Sends OTLP to central gateway | Extra VMs or remote K8s clusters |

**Important:** The Kubernetes chart does **not** deploy Loki. Loki is only in the **Docker Compose** path (C). On Kubernetes, logs go **OTel → Victoria Logs → Grafana** (Victoria Logs datasource plugin).

---

## Path A — Kubernetes lab (recommended first run)

**Goal:** Same components as production, reachable via port-forward—no domain, no Gateway API, no GitHub OAuth, no S3 backup jobs.

### A0 — Cluster sizing

| Resource | Guidance |
|----------|----------|
| **Nodes** | 1 node with **≥ 8 GB RAM** and **4 CPUs** (more is better; many pods + PVCs). |
| **Storage** | Default `StorageClass` with dynamic provisioning (`kubectl get storageclass`). Lab overlay uses the cluster default (`storageClassName: ""`). |
| **CNI / DNS** | Standard cluster DNS; pods must reach Helm chart repos on the internet for `helm dependency update`. |

### A1 — Grafana admin Secret

```bash
./observability/scripts/create-grafana-secret.sh
```

Use password login at Grafana (`admin` + the password you set). Lab overlay disables GitHub OAuth so you do **not** need `grafana-secret` for Path A.

### A2 — Install

```bash
./observability/scripts/helm-install-central.sh lab
```

This applies `values.yaml` (production template) **plus** `values.local.lab.yaml`, which only turns off: Gateway API HTTPRoutes, vmbackup CronJobs, Victoria Metrics **cluster** mode, GitHub OAuth, and fixes PVCs to the default StorageClass.

**First install often takes 10–20 minutes** (chart downloads + image pulls).

### A3 — Open Grafana

```bash
./observability/scripts/port-forward-ui.sh
```

Browser: **http://localhost:3000** — user `admin`, password from A1.

### A4 — Verify

```bash
kubectl get pods -n observability
kubectl get pvc -n observability
```

Expect Running: Grafana, Prometheus, node-exporter, kube-state-metrics, Victoria Metrics single, Victoria Logs single, OTel gateway (`otel-collector-central`), OTel DaemonSet pods, optional blackbox-exporter. **Failed Jobs** for vmbackup should **not** appear in lab (backup disabled).

**Inside Grafana**

- **Metrics:** Explore → **Victoria Metrics** or **Prometheus**
- **Logs:** Explore → **Victoria Logs** (plugin `victoriametrics-logs-datasource`)

**Send test OTLP (optional)**

```bash
kubectl port-forward -n observability svc/otel-collector-central 4318:4318
# Use otel-cli or a small app sending to http://localhost:4318/v1/logs and /v1/metrics
```

### A5 — Common lab issues

| Symptom | Fix |
|---------|-----|
| PVC `Pending` | No default StorageClass → install one (e.g. local-path on k3d) or set `storageClassName` in a custom overlay. |
| Grafana `CreateContainerConfigError` / missing secret | Run `create-grafana-secret.sh`; for **production** you also need `grafana-secret` (see chart `manifests/grafana-secret.example.yaml`). |
| `helm dependency update` fails | Corporate proxy/firewall; check access to `prometheus-community.github.io` and `victoriametrics.github.io`. |
| Pods OOMKilled | Bigger node or temporarily scale down: set `otel-deploy.replicaCount: 1` (lab already does). |
| Blackbox targets down | Normal in lab: probes use placeholder `https://*.yourdomain.tld` until you set real URLs in `values.yaml`. |

---

## Path B — Kubernetes production

**Goal:** Match the production template: `values.yaml` + your `values.local.yaml` (Gateway API, real hostnames, StorageClass, OAuth, optional S3 backup).

### B1 — Prerequisites checklist

1. **DNS:** `grafana.<domain>` and `otel.<domain>` (or your chosen hosts in `gatewayAPI` values).
2. **Gateway API:** Shared `Gateway` (e.g. Envoy Gateway) with HTTPS listeners; chart creates **HTTPRoutes** only—see `kubernetes/gitops/`.
3. **TLS:** Certificates on the Gateway listeners (cert-manager or your process)—not committed to this repo.
4. **Secrets:**
   - `grafana-admin` — `create-grafana-secret.sh`
   - `grafana-secret` — from `kubernetes/charts/observability-central/manifests/grafana-secret.example.yaml` (GitHub OAuth client).
   - `s3-credentials` — if `vmBackup.enabled: true` (keys `key` and `secret`).
5. **StorageClass:** Replace `YOUR_STORAGE_CLASS` in values (see `PLACEHOLDERS.md`).
6. **SNMP / blackbox:** Optional; set real switch IPs and deploy `snmp-exporter` if you use Cumulus jobs.

### B2 — Values

```bash
cd observability/kubernetes/charts/observability-central
cp values.local.production.example.yaml values.local.yaml
# Edit: YOUR_DOMAIN, YOUR_STORAGE_CLASS, YOUR_GITHUB_ORG, S3 endpoint/bucket, gateway parentRef if needed
```

Optional HA overlay:

```bash
# After values.local.yaml is ready
helm upgrade --install observability-central . -n observability --create-namespace \
  -f values.yaml -f values.local.yaml -f values-production.yaml
```

Or use the script (expects `values.local.yaml`):

```bash
cd ../../../..
./observability/scripts/create-grafana-secret.sh
./observability/scripts/helm-install-central.sh production
```

### B3 — GitOps

Apply `kubernetes/gitops/applications/observability-central-app.yaml` from your Argo CD repo; point `repoURL` and path `observability/kubernetes/charts/observability-central`. See `docs/operations/deployment/argocd-phase3-phase4-plan.md`.

### B4 — Agents

Set `https://otel.<your-domain>` in `ansible/otel-agent/inventory.local.ini` or deploy `observability-edge` on workload clusters. See `docs/multi-cluster/otel-endpoint-cloud-team.md`.

---

## Path C — VM + Docker (Loki stack)

**Goal:** Prometheus + **Loki** + Grafana + OTel on one host—useful when you do not have Kubernetes.

```bash
chmod +x observability/scripts/vm-docker-central-bootstrap.sh
./observability/scripts/vm-docker-central-bootstrap.sh
```

Edit `observability/vm-docker/central-stack/docker-compose.yml` (Grafana URL, disable SMTP if not needed). Agents: `vm-docker/agent-edge/.env.example` → `.env`, point OTLP at the central host.

This path is **independent** of the Helm chart; logs use **Loki**, not Victoria Logs.

---

## Path D — Ansible agents (Linux VMs / remote K8s)

```bash
./observability/scripts/ansible-copy-inventory.sh
# Edit inventory.local.ini — master_otlp_http=https://otel.yourdomain.tld
cd observability/ansible/otel-agent
ansible-playbook -i inventory.local.ini deploy_otel_agent.yml
```

For DaemonSets on other clusters: `deploy_otel_k8s.yml` and chart `observability-edge`.

---

## What stays in `values.yaml` (production template)

Do not expect a “tiny” default chart. `values.yaml` includes mission Grafana orgs (bootstrap Job), multi-folder dashboards, alerting rules, blackbox jobs, Victoria Metrics single **and** cluster chart dependencies (cluster disabled in lab via overlay), vmbackup hooks, and OTel pipelines to Victoria Metrics / Victoria Logs. **Lab** only adds `values.local.lab.yaml` so external dependencies are not required for a first boot.

Replace placeholders before real production: [PLACEHOLDERS.md](./PLACEHOLDERS.md).

---

## Scripts

| Script | Purpose |
|--------|---------|
| `check-prerequisites.sh` | kubectl, helm, docker |
| `create-grafana-secret.sh` | `grafana-admin` Secret |
| `helm-install-central.sh` | `lab` or `production` |
| `port-forward-ui.sh` | Grafana on localhost:3000 |
| `vm-docker-central-bootstrap.sh` | Docker central stack |
| `ansible-copy-inventory.sh` | Local Ansible inventory |
| `sanitize-for-public.py` | Maintainers: redact before publish |

---

## Next reading

- [ARCHITECTURE.md](./ARCHITECTURE.md) — components and data flow  
- [RUNBOOK.md](./RUNBOOK.md) — day-2 operations  
- [docs/README.md](./docs/README.md) — runbooks, multi-cluster, incidents (reference)  
- [kubernetes/charts/observability-central/README.md](./kubernetes/charts/observability-central/README.md) — chart-specific notes  
