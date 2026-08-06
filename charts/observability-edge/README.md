# observability-edge

OpenTelemetry Collector **DaemonSet** for remote Kubernetes clusters. Collects logs and kubelet/host metrics and exports **OTLP** to the central gateway (`https://otel.<domain>` → Victoria Metrics / Victoria Logs).

## Install

```bash
cd charts/observability-edge
helm dependency update
helm upgrade --install observability-edge . -n otel --create-namespace \
  --set masterOtlpHttp=https://otel.yourdomain.tld \
  --set customer=YOUR_ORG --set environment=PRD --set country=AT \
  --set serviceName=my-cluster
```

Or deploy via Ansible: `playbooks/otel-agent/deploy_otel_k8s.yml`.

## Notes

- Chart ships config via the OpenTelemetry Helm subchart (see `values.yaml` / `Chart.yaml`).
- Replace placeholders per [PLACEHOLDERS.md](../../PLACEHOLDERS.md).
- Central stack must be reachable on OTLP HTTPS (or NodePort in lab).
