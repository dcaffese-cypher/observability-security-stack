# TLS / certificates

Certificate and ApisixTls manifests for Grafana and OTel Collector are **not** part of this chart (they cause permanent out-of-sync in ArgoCD).

They live in **move-to-k8s-inf/** at repo root and are applied from k8s-infra:

- `move-to-k8s-inf/grafana-ingress-tls-apisix.yaml`
- `move-to-k8s-inf/otel-collector-ingress-tls-apisix.yaml`

Apply with `kubectl apply -f` at the point of install.
