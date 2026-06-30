# Multi-cluster observability: labels schema and aggregation examples

Standard resource attributes for all telemetry (metrics and logs) sent from remote clusters to the central OTel gateway (`https://otel.yourdomain.tld`).

---

## 1. Required resource attributes

| Attribute | Type | Example values | Description |
|-----------|------|----------------|-------------|
| `cluster` | string | `assembly`, `prod-cluster`, `dev-cluster` | Kubernetes cluster name |
| `environment` | string | `production`, `development`, `staging` | Deployment environment |
| `team` | string | `observability`, `platform`, `data` | Owning team |
| `service.name` | string | `grafana`, `otel-collector`, `alloy` | Service/component name (OTel semantic convention) |
| `service.namespace` | string | `observability`, `monitoring` | Kubernetes namespace |
| `k8s.node.name` | string | `inf-1`, `inf-3` | Node name (auto-populated by OTel collector) |

---

## 2. OTel Collector config snippet (edge cluster — otel-daemonset)

The `resource/cluster-identity` processor in the edge daemonset must be overridden per cluster in the ArgoCD overlay:

```yaml
processors:
  resource/cluster-identity:
    attributes:
      - key: cluster
        value: "prod-cluster"          # override per cluster in ArgoCD overlay
        action: upsert
      - key: environment
        value: "production"            # override per environment
        action: upsert
      - key: team
        value: "platform"
        action: upsert

exporters:
  otlphttp/central-otel:
    endpoint: https://otel.yourdomain.tld
    tls:
      insecure: false

service:
  pipelines:
    metrics:
      processors: [resource/cluster-identity, batch]
      exporters: [otlphttp/central-otel]
    logs:
      processors: [resource/cluster-identity, batch]
      exporters: [otlphttp/central-otel]
```

---

## 3. Grafana query examples

### Metrics — filter by cluster (Victoria Metrics / PromQL)

```promql
# All metrics from prod-cluster
{cluster="prod-cluster"}

# CPU usage per cluster
rate(container_cpu_usage_seconds_total{cluster=~"$cluster"}[5m])

# Compare clusters side by side
sum by (cluster) (rate(container_cpu_usage_seconds_total[5m]))
```

### Logs — filter by cluster (Victoria Logs / LogsQL)

```logsql
# All logs from prod-cluster
{cluster="prod-cluster"}

# Logs from a specific service in a cluster
{cluster="prod-cluster", service_name="otel-daemonset"}

# Error logs across all clusters
{cluster=~".+"} |= "error"

# Compare log volume per cluster
sum by (cluster) (count_over_time({cluster=~".+"}[5m]))
```

> **Note:** Victoria Logs uses LogsQL (similar to LogQL but with differences). Stream selectors use `{label="value"}` syntax. See [VictoriaLogs LogsQL docs](https://docs.victoriametrics.com/victorialogs/logsql/).

---

## 4. Grafana variable setup (for dashboards)

Add these template variables to any multi-cluster dashboard:

| Variable | Type | Query |
|----------|------|-------|
| `$cluster` | Query | `label_values(up, cluster)` |
| `$environment` | Query | `label_values(up, environment)` |
| `$service` | Query | `label_values(up{cluster="$cluster"}, service_name)` |

---

## 5. Validation checklist (post-deploy)

After deploying an agent in a remote cluster:

```bash
# Verify metrics arrive in Victoria Metrics (from central node)
curl -sg 'http://observability-central-victoria-metrics-single-server:8428/api/v1/query?query=up{cluster="prod-cluster"}' | jq .

# Verify logs arrive in Victoria Logs
curl -sg 'http://observability-central-victoria-logs-single-server:9428/select/logsql/query?query=\{cluster="prod-cluster"\}&start=1h' | jq .
```

In Grafana:
- Victoria Metrics datasource: query `up{cluster="prod-cluster"}` → should return results.
- Victoria Logs datasource: query `{cluster="prod-cluster"}` → should return log streams.
- Filter by `cluster`, `environment` in any dashboard variable.
