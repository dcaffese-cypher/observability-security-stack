# observability-edge

DaemonSet: OpenTelemetry Collector on each node, forwarding metrics and logs to the **central OTLP endpoint**.

## Values

| Key | Description |
|-----|-------------|
| `masterOtlpHttp` | Central gateway URL, e.g. `https://otel.yourdomain.tld` |
| `customer`, `environment`, `country`, `serviceName` | Resource attributes on telemetry |

## Install (Helm)

```bash
helm upgrade --install otel-edge . -n otel --create-namespace \
  --set masterOtlpHttp=https://otel.yourdomain.tld \
  --set customer=YOUR_ORG --set environment=YOUR_ENV --set country=YOUR_COUNTRY
```

## Argo CD example

Set `repoURL` to **your** Git repo and `path` to `observability/kubernetes/charts/observability-edge`. Pass `masterOtlpHttp` via Application `spec.source.helm.parameters` or values file.
