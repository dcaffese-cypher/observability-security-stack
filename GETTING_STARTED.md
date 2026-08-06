# Getting started

This repo matches a **production Kubernetes observability stack**: Prometheus (scrapes), **Victoria Metrics** (OTLP metrics), **Victoria Logs** (OTLP logs), Grafana 12, and OpenTelemetry Collectors.

---

## 0. Clone and check tools

```bash
git clone https://github.com/dcaffese-cypher/observability-security-stack.git
cd observability-security-stack
chmod +x scripts/*.sh
./scripts/check-prerequisites.sh
```

---

## Choose your path

| Path | When |
|------|------|
| **A — K8s lab** | Try the full chart with port-forward (no DNS/TLS) |
| **B — K8s production** | Real hostnames, Gateway API, OAuth, optional S3 backup |
| **C — Agents** | Central stack already up; ship telemetry from VMs / other clusters |

---

## Path A — Kubernetes lab

**Needs:** ~8 GB RAM node, default StorageClass.

```bash
./scripts/create-grafana-secret.sh
./scripts/helm-install-central.sh lab
./scripts/port-forward-ui.sh
```

Browser: **http://localhost:3000** — user `admin`.

Lab overlay (`charts/observability-central/values.local.lab.yaml`) turns off Gateway API, GitHub OAuth, S3 backups, and Victoria *cluster* backends so a plain cluster can boot.

```bash
kubectl get pods -n observability
kubectl get pvc -n observability
```

In Grafana: Explore → **Victoria Metrics** / **Prometheus** / **Victoria Logs**.

### Common lab issues

| Symptom | Fix |
|---------|-----|
| PVC Pending | Install a default StorageClass (e.g. local-path) |
| Grafana missing secret | Re-run `create-grafana-secret.sh` |
| `helm dependency update` fails | Network access to Helm chart repos |
| Blackbox targets down | Normal — placeholders until you set real URLs in `values.yaml` |

---

## Path B — Kubernetes production

1. DNS for `grafana.<domain>` and `otel.<domain>`
2. Gateway API + TLS on your shared Gateway
3. Secrets: `grafana-admin`, `grafana-secret` (OAuth), optional `s3-credentials`
4. Copy and edit values:

```bash
cd charts/observability-central
cp values.local.production.example.yaml values.local.yaml
# edit YOUR_DOMAIN, YOUR_STORAGE_CLASS, YOUR_GITHUB_ORG, S3, gateway parentRef
helm dependency update
helm upgrade --install observability-central . -n observability --create-namespace \
  -f values.yaml -f values.local.yaml
```

Or from repo root: `./scripts/helm-install-central.sh production` (expects `values.local.yaml` in the chart dir).

Argo CD sample: `gitops/applications/observability-central-app.yaml` (path `charts/observability-central`).

---

## Path C — Agents

```bash
./scripts/ansible-copy-inventory.sh
# edit playbooks/otel-agent/inventory.local.ini
cd playbooks/otel-agent
ansible-playbook -i inventory.local.ini deploy_otel_agent.yml
```

Remote K8s clusters: `deploy_otel_k8s.yml` + chart `charts/observability-edge`.

OTLP contract for cloud teams: [docs/multi-cluster/otel-endpoint-cloud-team.md](docs/multi-cluster/otel-endpoint-cloud-team.md).

---

## What you must configure

1. Domains / DNS / TLS (production)
2. Placeholders — [PLACEHOLDERS.md](PLACEHOLDERS.md)
3. StorageClass, OAuth client, S3 (if backups enabled)
4. SNMP / blackbox targets (optional)

---

## Next reading

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [RUNBOOK.md](RUNBOOK.md)
- [charts/observability-central/README.md](charts/observability-central/README.md)
- [docs/README.md](docs/README.md)
