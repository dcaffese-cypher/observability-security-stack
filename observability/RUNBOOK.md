# Operational runbook

## Prerequisites

- **New to this repo?** Use [GETTING_STARTED.md](./GETTING_STARTED.md) first (scripts + lab path).
- Kubernetes cluster (or Docker host for VM-only lab)
- Helm 3, `kubectl` configured
- DNS + TLS only if ingress is enabled (not required for lab + port-forward)
- Ansible + SSH for VM agents (optional)

## Configuration order

1. Replace placeholders — see [PLACEHOLDERS.md](./PLACEHOLDERS.md).
2. Create namespace: `kubectl create namespace observability`
3. Create Grafana admin Secret:

   ```bash
   kubectl create secret generic grafana-admin -n observability \
     --from-literal=admin-user=admin \
     --from-literal=admin-password='YOUR_SECURE_PASSWORD'
   ```

4. Deploy Helm chart `observability-central` (see chart README).
5. Apply TLS manifests from `kubernetes/gitops/` (adjust hosts + issuers).
6. Deploy VM agents or `observability-edge` on remote clusters.
7. Verify OTLP: `curl -k https://otel.yourdomain.tld/v1/metrics` (405/400 is OK — proves HTTP reachability).

## Validate

| Check | Command / action |
|-------|------------------|
| Pods running | `kubectl get pods -n observability` |
| Grafana | Browser → `https://grafana.yourdomain.tld` |
| Prometheus targets | Grafana → Explore → Prometheus, or port-forward `:9090` |
| Loki | Grafana → Explore → Loki |
| OTel gateway metrics | Scrape `otel-collector:8888/metrics` inside cluster |

## Ports (typical)

| Service | Port |
|---------|------|
| OTLP gRPC | 4317 |
| OTLP HTTP | 4318 |
| Grafana | 3000 (in-cluster) |
| Prometheus | 9090 |
| Loki | 3100 |
| Victoria Metrics | 8428 |

## Troubleshooting

| Symptom | Action |
|---------|--------|
| Grafana 502 at ingress | Check ingress backend, APISIX/NGINX routes, pod readiness |
| Loki query errors | Check Loki pod logs, disk full, retention |
| No agent data | Verify firewall to `otel.yourdomain.tld:443`, TLS SNI, and agent `master_otlp_http` |
| Prometheus scrape down | Target networking, SNMP community/auth in exporter config |

## Maintenance

- **Retention:** Tune Prometheus `retention` and Loki `retention_period` in values.
- **TSDB trim (Docker):** Run `scripts/prometheus-tsdb-trim/prometheus-tsdb-trim.sh` on the Prometheus data host (see script README).
- **Upgrades:** `helm dependency update` then `helm upgrade` with reviewed diffs.

## Backup / restore

- Persisted data: Prometheus, Loki, Victoria Metrics, Grafana PVCs — snapshot PVs or use object storage for Loki in production values.
- Export critical Grafana dashboards to Git (JSON in chart `config/grafana/.../json/`).

## Demo cleanup script

`scripts/demo-cleanup/` **wipes** metrics/log data when disk usage exceeds a threshold. **Do not use in production.**

## Health checks

- Grafana: `GET /api/health`
- Prometheus: `/-/ready`
- OTel: receiver on `4317`/`4318`, self-metrics on `:8888`
