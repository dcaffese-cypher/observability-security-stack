# Operational runbook

## Prerequisites

- First time? [GETTING_STARTED.md](./GETTING_STARTED.md)
- Helm 3, `kubectl`
- Chart backends: **Victoria Metrics** + **Victoria Logs**

## Configuration order (production)

1. Placeholders — [PLACEHOLDERS.md](./PLACEHOLDERS.md)
2. `kubectl create namespace observability`
3. `./scripts/create-grafana-secret.sh`
4. Secret `grafana-secret` from `charts/observability-central/manifests/grafana-secret.example.yaml`
5. Optional `s3-credentials` if backups enabled
6. `helm upgrade --install` with `values.yaml` + `values.local.yaml`
7. Gateway API + TLS on your shared Gateway
8. Agents: `playbooks/otel-agent` or `charts/observability-edge`

## Validate

| Check | Action |
|-------|--------|
| Pods / PVCs | `kubectl get pods,pvc -n observability` |
| Grafana (lab) | `./scripts/port-forward-ui.sh` → http://localhost:3000 |
| Grafana (prod) | `https://grafana.<domain>` |
| Metrics | Explore → Victoria Metrics / Prometheus |
| Logs | Explore → Victoria Logs |
| OTLP | `curl -sI https://otel.<domain>/v1/logs` (405/400 OK) |

## Ports

| Service | Port |
|---------|------|
| OTLP gRPC / HTTP | 4317 / 4318 |
| Grafana | 3000 |
| Prometheus | 9090 |
| Victoria Logs | 9428 |
| Victoria Metrics | 8428 |

## Troubleshooting

| Symptom | Action |
|---------|--------|
| Grafana missing secret | Create `grafana-admin`; disable OAuth in lab overlay |
| PVC Pending | Fix `storageClassName` or use default (lab overlay) |
| HTTPRoute not routing | Gateway controller + `gatewayAPI.parentRef` |
| No OTLP data | Agent URL/TLS; gateway + VL/VM pods Ready |
| vmbackup / vlbackup Job fails | Expected without S3 — disable or configure `s3-credentials` |
| Blackbox down | Placeholder hosts until you set real URLs |

## Maintenance

- Tune Prometheus retention and VL/VM retention in values.
- Upgrades: `helm dependency update` then `helm upgrade` with reviewed diff.
- Restore: `docs/operations/runbooks/runbook-vm-restore.md`

More: `docs/operations/runbooks/`.
