# observability-central

Helm chart bundling **kube-prometheus-stack**, **Loki**, **Victoria Metrics Single**, and an **OpenTelemetry Collector** gateway.

## Flow

- Remote agents send **OTLP** (metrics/logs) to the gateway.
- Gateway writes metrics to **Victoria Metrics** and logs to **Loki**.
- **Prometheus** scrapes targets independently (SNMP, k8s, static).
- **Grafana** uses datasources: Prometheus, Victoria Metrics, Loki.

## Requirements

- Helm 3
- Namespace `observability`
- Ingress controller (e.g. APISIX, NGINX) matching `ingressClassName` in `values.yaml`
- For Cumulus SNMP jobs: **snmp-exporter** in-cluster (not included)

## Install

**Easiest (lab, no DNS):** from repo root

```bash
./observability/scripts/create-grafana-secret.sh
./observability/scripts/helm-install-central.sh lab
./observability/scripts/port-forward-ui.sh   # Grafana → http://localhost:3000
```

**Manual:**

```bash
cd observability/kubernetes/charts/observability-central
helm dependency update
helm upgrade --install observability-central . -n observability --create-namespace \
  -f values.yaml -f values.local.lab.yaml
```

**Production:** see [GETTING_STARTED.md](../../../GETTING_STARTED.md) Path B and `values.local.production.example.yaml`.

Override Grafana/OTel hostnames, SNMP targets, and scrape configs in `values.yaml` or a private `-f` values file (gitignored).

## Production

Use `values-production.yaml` for distributed Loki, Prometheus HA, and higher OTel replica limits. Tune for your SLOs and storage class.

## TLS

Certificate manifests live under `observability/kubernetes/gitops/`. Apply with `kubectl` from your GitOps or bootstrap process; they are intentionally outside Helm to avoid drift.

## Grafana admin

Create Secret `grafana-admin` with keys `admin-user` and `admin-password` before or after install — see [RUNBOOK.md](../../../RUNBOOK.md).
