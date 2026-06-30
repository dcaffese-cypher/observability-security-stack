# manifests/

Resources that live **outside** the Helm release.

## Grafana dashboards

Dashboard JSON files are managed in **k8s-infra** and applied by the GitLab CI pipeline:

```
k8s-infra/cluster/templates/observability-dashboards-configmap.yaml
```

To update dashboards: regenerate the ConfigMap and open an MR in `k8s-infra`:

```bash
kubectl create configmap grafana-dashboards-json \
  -n observability \
  --from-file=kubernetes/charts/observability-central/config/grafana/provisioning/dashboards/json/ \
  --dry-run=client -o yaml > /path/to/k8s-infra/cluster/templates/observability-dashboards-configmap.yaml
```

Grafana picks up changes automatically via the provisioning sidecar.

## OTel RBAC

ServiceAccount, ClusterRole, and ClusterRoleBinding for the OTel Collector
(`k8s_cluster` receiver) are managed in **k8s-infra** and applied by the GitLab CI pipeline:

```
k8s-infra/cluster/templates/observability-rbac.yaml
```

## OTel Logs DaemonSet

Collects container logs from `/var/log/pods/` on each node and ships them to Loki.
Deployed as a separate Helm release to keep it decoupled from the main chart.

```bash
helm install otel-logs-collector open-telemetry/opentelemetry-collector \
  -n observability \
  -f kubernetes/charts/observability-central/manifests/otel-logs-daemonset-values.yaml
```

To upgrade:

```bash
helm upgrade otel-logs-collector open-telemetry/opentelemetry-collector \
  -n observability \
  -f kubernetes/charts/observability-central/manifests/otel-logs-daemonset-values.yaml
```
