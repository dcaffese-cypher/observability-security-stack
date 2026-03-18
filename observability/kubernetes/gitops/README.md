# GitOps examples (TLS + Argo CD)

**Not applied by Helm.** Use these as templates for your cluster.

| File | Purpose |
|------|---------|
| `applications/observability-central-app.yaml` | Example Argo CD Application — set `repoURL` and domain in chart values |
| `grafana-ingress-tls-apisix.yaml` | cert-manager Certificate + APISIX TLS for Grafana hostname |
| `otel-collector-ingress-tls-apisix.yaml` | Same for OTel gateway hostname |

Replace `grafana.yourdomain.tld` / `otel.yourdomain.tld` and issuer names to match your DNS and cert-manager `ClusterIssuer`.

If you use NGINX Ingress or another controller, adapt the TLS / Ingress resources accordingly.
