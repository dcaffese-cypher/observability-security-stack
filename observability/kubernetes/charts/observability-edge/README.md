# otel-collector Helm chart

OpenTelemetry Collector DaemonSet: collects container logs and kubelet/cAdvisor metrics in the cluster and exports them via OTLP to a central master (Prometheus + Loki).

#### Pre-requisite

```
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
```

## Install (Helm CLI)

Central gateway is at **https://otel.yourdomain.tld** (OTLP HTTP). Example:

```bash
helm upgrade --install otel-collector . -n otel --create-namespace \
  --set masterOtlpHttp=https://otel.yourdomain.tld \
  --set customer=YOUR_ORG --set environment=PRD --set country=AT \
  --set serviceName=my-cluster
```

Or with a values file:

```bash
helm upgrade --install otel-collector . -n otel --create-namespace -f my-values.yaml
```

## ArgoCD

Use this chart as the `source` of an ArgoCD Application. Example (adjust repo and path to your Git):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: otel-collector
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://git.yourdomain.tld/YOUR_ORG/your-repo.git
    path: kubernetes/charts/observability-edge
    targetRevision: HEAD
    helm:
      releaseName: otel-collector
      values: |
        masterOtlpHttp: "https://otel.yourdomain.tld"
        customer: YOUR_ORG
        environment: PRD
        country: AT
        serviceName: dev-cluster
  destination:
    server: https://kubernetes.default.svc
    namespace: otel
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    automated:
      prune: true
      selfHeal: true
```

Per-cluster: one Application per cluster with different `destination.name` and `source.helm.values` (or a values file per cluster in Git).

## Values

| Key | Description | Default |
|-----|-------------|---------|
| `masterOtlpHttp` | Central OTLP HTTP/HTTPS endpoint (e.g. gateway Ingress URL) | `https://otel.yourdomain.tld` |
| `customer` | Resource attribute (→ CLIENT in master) | `YOUR_ORG` |
| `environment` | Resource attribute (→ ENVIRONMENT) | `PRD` |
| `country` | Resource attribute (→ COUNTRY) | `AT` |
| `serviceName` | Resource attribute (e.g. cluster name) | `k8s-cluster` |
| `image.repository` | Collector image | `otel/opentelemetry-collector-contrib` |
| `image.tag` | Image tag | `0.131.0` |
| `namespace` | Kubernetes namespace | `otel` |
