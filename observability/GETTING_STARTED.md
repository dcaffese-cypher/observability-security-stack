# Getting started (step by step)

Follow this file if you are new to Helm/Kubernetes or Docker. **Experienced users** can skim and use [RUNBOOK.md](./RUNBOOK.md) only.

---

## 0. Clone and check your tools

```bash
git clone <your-fork-or-url> && cd <repo>
chmod +x observability/scripts/*.sh
./observability/scripts/check-prerequisites.sh
```

If something is missing, install it using the links printed by the script, then run the check again.

---

## Choose your path

| Path | Best when |
|------|-----------|
| **A — Kubernetes (lab)** | You have any Kubernetes cluster and want to try the central stack **without** DNS or TLS. |
| **B — Kubernetes (production)** | You have DNS, TLS (e.g. cert-manager), and an ingress controller. |
| **C — VM + Docker** | Single VM (e.g. Proxmox), Docker only, no Kubernetes. |
| **D — Agents** | Central stack already running; you want metrics/logs from more Linux VMs. |

---

## Path A — Kubernetes lab (no public URLs)

**Goal:** Grafana + Prometheus + Loki + OTel running in namespace `observability`, access Grafana from your laptop via port-forward.

### Step A1 — Grafana admin password (Secret)

```bash
./observability/scripts/create-grafana-secret.sh
```

Enter a password when prompted (remember it for login).

### Step A2 — Install the chart (lab values)

```bash
./observability/scripts/helm-install-central.sh lab
```

This runs `helm dependency update` and installs with **ingress disabled** and a single OTel replica (lighter for small clusters).

**First run can take several minutes** (image pulls).

### Step A3 — Open Grafana

In a **second terminal**:

```bash
./observability/scripts/port-forward-ui.sh
```

Browser: **http://localhost:3000** — user `admin`, password = what you set in A1.

### Step A4 — Sanity checks

```bash
kubectl get pods -n observability
kubectl get svc -n observability
```

If a pod is `CrashLoopBackOff`, run:

```bash
kubectl logs -n observability deploy/grafana -c grafana --tail=50
kubectl describe pod -n observability <pod-name>
```

### Common lab issues

| Problem | What to do |
|---------|------------|
| `grafana-admin` Secret missing | Run `create-grafana-secret.sh` again. |
| Helm dependency errors | Check internet access to Helm chart repos; re-run `helm dependency update` inside `observability/kubernetes/charts/observability-central`. |
| Pending PVCs | Your cluster needs a default `StorageClass` or set `storageClassName` in a custom values file. |
| Not enough CPU/memory | Use a bigger node or reduce replicas in a custom `values.local.yaml` (advanced). |

---

## Path B — Kubernetes production (real hostnames)

**Goal:** HTTPS URLs like `https://grafana.example.com` and OTLP at `https://otel.example.com`.

### Step B1 — DNS

Create **A or CNAME** records:

- `grafana.example.com` → your ingress external IP / LB  
- `otel.example.com` → same (or separate LB per your design)

### Step B2 — TLS secrets

Adapt manifests under `observability/kubernetes/gitops/` (cert-manager + your ingress). **APISIX** examples are templates; if you use **NGINX Ingress**, change `ingressClassName` and annotations to match your cluster.

### Step B3 — Helm values

```bash
cd observability/kubernetes/charts/observability-central
cp values.local.production.example.yaml values.local.yaml
# Edit values.local.yaml: replace YOUR_DOMAIN, YOUR_INGRESS_CLASS
```

### Step B4 — Install

```bash
cd ../../../..   # back to repo root
./observability/scripts/create-grafana-secret.sh   # if not done yet
./observability/scripts/helm-install-central.sh production
```

### Step B5 — Point agents at OTLP

Set the same OTLP URL in:

- `observability/ansible/otel-agent/inventory.ini` (or `inventory.local.ini`), **or**
- `observability/kubernetes/charts/observability-edge` when installing edge collectors.

See [PLACEHOLDERS.md](./PLACEHOLDERS.md).

---

## Path C — VM + Docker central stack

**Goal:** Prometheus, Loki, Grafana, OTel on one Linux host with Docker.

```bash
chmod +x observability/scripts/vm-docker-central-bootstrap.sh
./observability/scripts/vm-docker-central-bootstrap.sh
```

Before or after: edit `observability/vm-docker/central-stack/docker-compose.yml` (Grafana `GF_SERVER_ROOT_URL`, SMTP or disable SMTP).

**Agent on another VM:** copy `observability/vm-docker/agent-edge/.env.example` to `.env`, set `MASTER_OTLP_*` to your central host, then `docker compose up -d`.

**SNMP:** optional — see `central-stack/snmp/README.md` and `docker compose --profile snmp up -d`.

---

## Path D — Ansible agents (many Linux servers)

```bash
./observability/scripts/ansible-copy-inventory.sh
```

Edit `inventory.local.ini`, then:

```bash
cd observability/ansible/otel-agent
ansible-playbook -i inventory.local.ini deploy_otel_agent.yml
```

Requires SSH + Docker on target hosts. For Kubernetes DaemonSets on other clusters, see `deploy_otel_k8s.yml` in the same directory.

---

## What you still must configure yourself

Nothing can be fully automated without your environment:

1. **Domains, DNS, TLS** (production K8s).  
2. **Real SNMP targets** in `values.yaml` if you use Cumulus jobs (replace documentation IPs).  
3. **Strong passwords** and **network firewalls**.  
4. **Ingress class** if not APISIX/NGINX as assumed.

---

## Scripts reference

| Script | Purpose |
|--------|---------|
| `scripts/check-prerequisites.sh` | Verify kubectl, helm, docker |
| `scripts/create-grafana-secret.sh` | Grafana admin Secret in K8s |
| `scripts/helm-install-central.sh` | `lab` or `production` install |
| `scripts/port-forward-ui.sh` | Local Grafana in lab mode |
| `scripts/vm-docker-central-bootstrap.sh` | Docker Compose central stack |
| `scripts/ansible-copy-inventory.sh` | Local Ansible inventory template |

---

## Next reading

- [ARCHITECTURE.md](./ARCHITECTURE.md) — how components fit together  
- [RUNBOOK.md](./RUNBOOK.md) — operations and troubleshooting  
- [PLACEHOLDERS.md](./PLACEHOLDERS.md) — naming conventions  
