# Placeholder reference

**Setup:** [GETTING_STARTED.md](./GETTING_STARTED.md).

Replace these tokens before production. Prefer private overlays (`values.local.yaml`, `inventory.local.ini`) outside Git.

| Placeholder | Meaning |
|-------------|---------|
| `yourdomain.tld` | DNS zone (Grafana, OTel) |
| `grafana.yourdomain.tld` / `otel.yourdomain.tld` | Public hostnames |
| `YOUR_ORG` | Tenant label on telemetry |
| `YOUR_ENV` / `YOUR_COUNTRY` | Environment / country attributes |
| `YOUR_GITHUB_ORG` | GitHub org for Grafana OAuth team mapping |
| `YOUR_STORAGE_CLASS` | PVC StorageClass |
| `YOUR_VM_BACKUP_BUCKET` / `YOUR_VM_CLUSTER_BACKUP_BUCKET` | S3 buckets for vm/vl backup |
| `YOUR_K8S_NODE_IP` | NodePort lab alternative for OTLP |
| `192.0.2.10`–`192.0.2.13` | Example SNMP targets (RFC 5737) — replace with real IPs |
| `YOUR_ORG/YOUR_OBSERVABILITY_REPO` | Git URL for Argo CD Application |

## SNMP / blackbox

Cumulus and blackbox jobs in `values.yaml` use documentation hosts until you set real targets.

## Maintainer sync

```bash
python3 scripts/sanitize-for-public.py .
```

Never commit live `inventory.ini`, kubeconfigs, OAuth secrets, or TLS keys.
