# Documentation

## Operations

| Document | Purpose |
|----------|---------|
| **operations/runbooks/runbook-observability.md** | Operations: cluster access, Grafana, routing/TLS, common issues, restarts. |
| **operations/runbooks/runbook-post-deploy-checks.md** | Post-deploy validation for routes, certs, endpoints, and datasources. |
| **operations/runbooks/runbook-vm-restore.md** | Victoria Metrics restore from S3 backups. |

## Deployment

| Document | Purpose |
|----------|---------|
| **operations/deployment/deploy-observability-master.md** | Deploy from repo: Helm, values, verification. |
| **operations/deployment/argocd-phase3-phase4-plan.md** | ArgoCD: repo registration and single-application strategy. |

## Architecture

| Document | Purpose |
|----------|---------|
| **architecture/architecture-and-status-observability.md** | Architecture, risks, improvements, current status. |
| **architecture/production-scalability.md** | Production scaling: Loki Distributed, Prometheus HA, OTel. |
| **architecture/security-observability-blueprint.md** | Security architecture (Falco, Trivy, Kyverno, roadmap). |

## Multi-Cluster

| Document | Purpose |
|----------|---------|
| **multi-cluster/multi-cluster-observability-status.md** | Multi-cluster telemetry status and next steps. |
| **multi-cluster/multi-cluster-labels-schema.md** | Label schema and aggregation examples for metrics/logs. |
| **multi-cluster/otel-endpoint-cloud-team.md** | OTel endpoint and attributes for Cloud team. |

## Incidents and Troubleshooting

| Document | Purpose |
|----------|---------|
| **incidents/observability-errors-investigation-plan.md** | Error triage and remediation plan. |
| **incidents/observability-502-and-recovery.md** | 502 incident notes and recovery actions. |
| **incidents/loki-error-logs-evaluation.md** | Loki error log analysis and impact. |
| **incidents/loki-chunks-cache-memory.md** | Loki cache memory behavior and tuning notes. |
