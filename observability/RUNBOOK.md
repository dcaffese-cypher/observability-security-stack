# Operational runbook

## Prerequisites

- **First time?** Follow [GETTING_STARTED.md](./GETTING_STARTED.md) (Path A lab or Path B production).
- Helm 3, `kubectl` configured
- **Kubernetes chart:** Victoria Metrics + Victoria Logs (not Loki)
- **Docker VM path:** Loki — see `vm-docker/central-stack/`

## Configuration order (production Kubernetes)

1. Replace placeholders — [PLACEHOLDERS.md](./PLACEHOLDERS.md).
2. Namespace: `kubectl create namespace observability`
3. Secret `grafana-admin` — `./scripts/create-grafana-secret.sh`
4. Secret `grafana-secret` — from `kubernetes/charts/observability-central/manifests/grafana-secret.example.yaml` (GitHub OAuth).
5. Optional Secret `s3-credentials` if `vmBackup.enabled: true`.
6. `helm upgrade --install` with `values.yaml` + `values.local.yaml` (and optional `values-production.yaml`).
7. Gateway API + TLS on your shared Gateway (not managed by this chart alone).
8. Deploy agents (`ansible/otel-agent` or `observability-edge`).

## Validate

| Check | Command / action |
|-------|------------------|
| Pods | `kubectl get pods -n observability` |
| PVCs | `kubectl get pvc -n observability` |
| Grafana (prod) | `https://grafana.<domain>` |
| Grafana (lab) | `./scripts/port-forward-ui.sh` → http://localhost:3000 |
| Prometheus | Explore → Prometheus, or port-forward `prometheus:9090` |
| Victoria Metrics | Explore → Victoria Metrics (PromQL) |
| Victoria Logs | Explore → Victoria Logs |
| OTel self-metrics | In-cluster `otel-collector-central:8888/metrics` |
| OTLP ingress (prod) | `curl -sI https://otel.<domain>/v1/logs` (405/400 OK) |

## Ports (typical)

| Service | Port |
|---------|------|
| OTLP gRPC | 4317 |
| OTLP HTTP | 4318 |
| Grafana | 3000 |
| Prometheus | 9090 |
| Victoria Logs | 9428 |
| Victoria Metrics | 8428 |

## Troubleshooting

| Symptom | Action |
|---------|--------|
| Grafana CrashLoop, missing secret | Create `grafana-admin`; for OAuth create `grafana-secret` or disable `auth.github` in a values overlay |
| PVC Pending | Fix `storageClassName` in values; lab overlay uses cluster default |
| HTTPRoute not routing | Gateway API controller running; `gatewayAPI.parentRef` matches your Gateway |
| No OTLP data | Agent URL, TLS, firewall; gateway pods Ready; VL/VM pods Ready |
| vmbackup Job failures | Expected if S3 secret missing—disable `vmBackup` or configure S3 |
| Blackbox probe failures | Placeholder hosts in values until you set real HTTPS targets |
| Victoria Logs empty | Confirm OTel pipeline `logs` exporter `otlphttp/victorialogs`; send test OTLP log |

## Maintenance

- **Retention:** Prometheus `retention` in values; Victoria Metrics / Logs retention per subchart values.
- **Docker hosts:** `scripts/prometheus-tsdb-trim/` for TSDB trim on Compose Prometheus.
- **Upgrades:** `helm dependency update` then `helm upgrade` with reviewed diff.

## Backup / restore

- PVCs: Prometheus, Grafana, Victoria Metrics, Victoria Logs — snapshot or use `vmBackup` to S3 (see `docs/operations/runbooks/runbook-vm-restore.md`).
- Dashboards in Git under `config/grafana/provisioning/`.

## Demo cleanup

`scripts/demo-cleanup/` is destructive—lab only.

## Health checks

- Grafana: `GET /api/health`
- Prometheus: `/-/ready`
- OTel: `:13133/ready` on gateway pods

Detailed procedures: `docs/operations/runbooks/`.
