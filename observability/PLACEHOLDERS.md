# Placeholder reference

**Step-by-step setup:** [GETTING_STARTED.md](./GETTING_STARTED.md) (includes scripts so you do not have to hunt for commands).

Replace these tokens across the repository before deployment. Keep a private overlay (e.g. `values.local.yaml`, `inventory.local.ini`) outside Git if preferred.

| Placeholder | Meaning |
|-------------|---------|
| `yourdomain.tld` | DNS zone for public ingress (Grafana, OTel) |
| `grafana.yourdomain.tld` | Grafana URL host |
| `otel.yourdomain.tld` | OTLP gateway host (HTTPS) |
| `YOUR_ORG` | Organization / tenant label on telemetry |
| `YOUR_ENV` | Environment (e.g. prod, staging) |
| `YOUR_COUNTRY` | Optional country code attribute |
| `YOUR_OTEL_MASTER_IP` | VM running Docker central stack (Proxmox) |
| `YOUR_K8S_NODE_IP` | Node IP when using NodePort for OTLP |
| `MASTER_SERVER_IP` | Same as central collector host (agent `.env`) |
| `192.0.2.10`–`192.0.2.13` | RFC 5737 **example** SNMP targets — replace with real switch management IPs |
| `YOUR_ORG/YOUR_OBSERVABILITY_REPO` | GitHub (or GitLab) clone URL for Argo CD |
| `YOUR_GITHUB_ORG` | GitHub organization for Grafana OAuth team mapping (`@YOUR_GITHUB_ORG/team`) |
| `YOUR_SSH_JUMP_HOST` | SSH `ProxyJump` bastion in `~/.ssh/config` examples |
| `YOUR_VM_BACKUP_BUCKET`, `YOUR_OBSERVABILITY_BACKUP_BUCKET` | S3-compatible bucket names for VictoriaMetrics / restore runbooks |
| `YOUR_STORAGE_CLASS` | Kubernetes `StorageClass` for Prometheus/Loki PVCs |
| `kubernetes/gitops/` | Argo CD Application + optional TLS samples (Gateway API or legacy ingress) |
| `docs/` | Runbooks, architecture, multi-cluster guides (sanitized from production) |

## Maintainer sync (private → public)

If you mirror changes from an internal repo, run `scripts/sanitize-for-public.py` on `observability/` before commit. Never copy live `inventory.ini`, kubeconfigs, or TLS keys.


Cumulus switch jobs in `values.yaml` use documentation IPs. Until you set real targets, scrapes will fail harmlessly or time out.

## Security

Never commit: Grafana admin passwords, SMTP passwords, API tokens, kubeconfigs, or TLS private keys.
