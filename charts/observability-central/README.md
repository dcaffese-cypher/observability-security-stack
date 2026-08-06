# observability-central

Central observability on Kubernetes: **kube-prometheus-stack** + **Victoria Metrics** + **Victoria Logs** + **OpenTelemetry Collector** (gateway + node DaemonSet).

**Lab:** [GETTING_STARTED.md](../../GETTING_STARTED.md) → `../../scripts/helm-install-central.sh lab`

## Architecture

| Component | Role |
|-----------|------|
| Prometheus | Scrapes (K8s, blackbox, SNMP you configure) |
| Victoria Metrics | OTLP metrics store |
| Victoria Logs | OTLP logs store |
| OTel `otel-deploy` | Gateway (OTLP in → VM/VL out) |
| OTel `otel-daemonset` | Node logs / host metrics on the central cluster |
| Grafana | Dashboards + Explore |

Agents only need `https://otel.<domain>`.

## Install (lab)

```bash
./scripts/create-grafana-secret.sh
./scripts/helm-install-central.sh lab
./scripts/port-forward-ui.sh
```

## Install (production)

```bash
cd charts/observability-central
cp values.local.production.example.yaml values.local.yaml
# edit placeholders — see PLACEHOLDERS.md
helm dependency update
helm upgrade --install observability-central . -n observability --create-namespace \
  -f values.yaml -f values.local.yaml
```

## Values

| File | Purpose |
|------|---------|
| `values.yaml` | Production template |
| `values.local.lab.yaml` | Lab overlay |
| `values.local.production.example.yaml` | Copy to `values.local.yaml` |
| `values-production.yaml` | Optional HA replicas |

## More

- [docs/architecture/production-scalability.md](../../docs/architecture/production-scalability.md)
- [PLACEHOLDERS.md](../../PLACEHOLDERS.md)
- [RUNBOOK.md](../../RUNBOOK.md)
