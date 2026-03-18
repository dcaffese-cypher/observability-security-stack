# Kubernetes observability charts

## Charts

| Chart | Role |
|-------|------|
| **observability-central** | Central stack: Prometheus, Grafana, Loki, Victoria Metrics, OTel gateway |
| **observability-edge** | Per-cluster DaemonSet sending metrics/logs to the central OTLP endpoint |

## Deployment order

1. Install **observability-central** on the central cluster (`observability` namespace).
2. Apply TLS / ingress manifests from `../gitops/` (cert-manager + your ingress controller) so `grafana.yourdomain.tld` and `otel.yourdomain.tld` resolve with valid certs.
3. Set the same OTLP URL in Ansible `inventory` (`master_otlp_http`) for VM agents.
4. Install **observability-edge** on workload clusters (Ansible or Argo CD).

Replace all `yourdomain.tld` and chart values with your environment; see `../../PLACEHOLDERS.md`.
