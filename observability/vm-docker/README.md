# VM / Docker observability

| Directory | Use case |
|-----------|----------|
| `central-stack/` | Full stack: OTel gateway, Prometheus, Loki, Grafana |
| `agent-edge/` | Single-host agent → central OTLP / Loki |

**First-time setup:** from repo root run  
`./observability/scripts/vm-docker-central-bootstrap.sh`  
or follow [GETTING_STARTED.md](../GETTING_STARTED.md) → Path C.

Kubernetes: use `../kubernetes/charts/` instead.
