# GitOps examples

Templates for Argo CD and optional TLS. **Not applied by the Helm chart itself.**

| File | Purpose |
|------|---------|
| `applications/observability-central-app.yaml` | Argo CD Application → path `charts/observability-central` |
| `grafana-ingress-tls-apisix.yaml` | Example cert-manager + APISIX TLS (legacy ingress style) |
| `otel-collector-ingress-tls-apisix.yaml` | Same for OTel |

Production in this stack prefers **Gateway API** HTTPRoutes from the chart (`gatewayAPI` in `values.yaml`). Use the APISIX samples only if your cluster still uses that ingress.

Set `repoURL`, domains, and issuers to match your environment ([PLACEHOLDERS.md](../PLACEHOLDERS.md)).
