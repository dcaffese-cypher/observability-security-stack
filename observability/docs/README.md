# Documentation

Start with [../GETTING_STARTED.md](../GETTING_STARTED.md) and [../PLACEHOLDERS.md](../PLACEHOLDERS.md) before applying these runbooks.

## Access

| Document | Purpose |
|----------|---------|
| **access/grafana-mission-isolation.md** | Grafana organisations per mission and GitHub team mapping. |

## Operations

| Document | Purpose |
|----------|---------|
| **operations/runbooks/runbook-observability.md** | Day-2 ops: Grafana, routing/TLS, restarts. |
| **operations/runbooks/runbook-post-deploy-checks.md** | Post-deploy validation for routes, certs, endpoints. |
| **operations/runbooks/runbook-vm-restore.md** | Victoria Metrics restore from S3 backups. |

## Deployment

| Document | Purpose |
|----------|---------|
| **operations/deployment/deploy-observability-master.md** | Deploy from repo: Helm, values, verification. |
| **operations/deployment/argocd-phase3-phase4-plan.md** | Argo CD: repo registration and single Application. |

## Architecture

| Document | Purpose |
|----------|---------|
| **architecture/architecture-and-status-observability.md** | Architecture overview and status notes. |
| **architecture/production-scalability.md** | Scaling Victoria Logs / Prometheus / OTel. |
| **architecture/security-observability-blueprint.md** | Security blueprint (Falco, Trivy, Kyverno roadmap). |

## Multi-Cluster

| Document | Purpose |
|----------|---------|
| **multi-cluster/multi-cluster-observability-status.md** | Multi-cluster telemetry status. |
| **multi-cluster/multi-cluster-labels-schema.md** | Label schema for metrics/logs. |
| **multi-cluster/otel-endpoint-cloud-team.md** | OTLP endpoint contract for cloud teams. |

## Incidents (historical reference)

These write-ups come from real incidents. Hostnames and tickets are sanitized; some still mention **Loki** from older deployments — the current Kubernetes chart uses **Victoria Logs**.

| Document | Purpose |
|----------|---------|
| **incident-2026-07-05-argocd-sync-fix.md** | Argo CD sync failure notes. |
| **incidents/observability-errors-investigation-plan.md** | Error triage plan. |
| **incidents/observability-502-and-recovery.md** | 502 recovery. |
| **incidents/loki-error-logs-evaluation.md** | Historical Loki error analysis. |
| **incidents/loki-chunks-cache-memory.md** | Historical Loki cache tuning. |
