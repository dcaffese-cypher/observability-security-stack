# observability-central

Central observability stack in the cluster (Assembly): kube-prometheus-stack + Loki + **Victoria Metrics** + OTel Collector Gateway. Aligned with k8s-infra Gateway API (Envoy Gateway).

**Architecture:** Cloud (agents) only send to **OTLP**. The **OTel Collector** acts as gateway: receives OTLP and sends metrics to **Victoria Metrics** and logs to **Loki**. **Prometheus** remains independent (current scrapes). Grafana queries Prometheus, Victoria Metrics and Loki.

Repository path: `YOUR_ORG/clusters/k8s-infra/Repository/observability-central`

## Requirements

- Helm 3
- Cluster with namespace `observability` and Gateway API resources available (`gateway.networking.k8s.io/v1`)
- If you use cumulus-snmp jobs: deploy `snmp-exporter` in the cluster (not included)

## Installation

On **MicroK8s** clusters, Helm is available as `microk8s helm3` (no need to install helm separately on the node):

```bash
cd kubernetes/charts/observability-central
microk8s helm3 dependency update
microk8s helm3 upgrade --install observability-central . -n observability --create-namespace -f values.yaml
```

With Helm installed separately:

```bash
cd kubernetes/charts/observability-central
helm dependency update
helm upgrade --install observability-central . -n observability --create-namespace -f values.yaml
```

### Production scalability (Sean / production)

For **production** (Loki Distributed, Prometheus HA, OTel scaling), use the production overrides and see [docs/architecture/production-scalability.md](../../docs/architecture/production-scalability.md):

```bash
helm dependency update
helm upgrade --install observability-central . -n observability --create-namespace -f values.yaml -f values-production.yaml
```

- **Loki:** `deploymentMode: Distributed` (microservices); MinIO as object storage (replace with S3/Azure/GCS in prod). SimpleScalable is deprecated before Loki 4.0.
- **Prometheus:** 2 replicas for HA.
- **OTel:** HPA maxReplicas 10.

## Grafana access (Gateway API)

Grafana is exposed via **HTTPRoute** (not NodePort), attached to the shared Gateway listeners managed in `k8s-infra/cluster/crds`:

- **Gateway parentRef:** `ingress` in `envoy-gateway-system`
- **Listener sectionName:** `grafana-https`
- **Host:** `grafana.yourdomain.tld` (configurable in `values.yaml`)
- **TLS:** managed centrally in k8s-infra (certificate at Gateway listener level)

**Ownership model (GitOps):** Gateway listeners/certs are centralized in `k8s-infra`. This chart manages only app `HTTPRoute`s and references existing listeners via values (`gatewayAPI.parentRef`, `gatewayAPI.*.sectionName`).

- **Dashboards and alerting:** Provisioned from ConfigMaps (`grafana-dashboards-provider`, `grafana-dashboards-json`, `grafana-alerting`). If they do not appear after upgrade, restart the Grafana pod: `kubectl rollout restart deployment grafana -n observability`.
- **Grafana persistence (5Gi PVC):** UI-imported dashboards and preferences are stored on the PVC and survive `helm upgrade` and pod restarts. To version a dashboard in Git, export JSON into `config/grafana/provisioning/dashboards/json/`.
- **Logs Drilldown (Drilldown > Logs):** Requires Grafana 11.6+ and Loki 3.2+ (this chart uses Grafana 12.1 and Loki 3.6). The plugin is in the chart's `plugins` list. If you see "App not found", use the direct link: **https://grafana.yourdomain.tld/a/grafana-lokiexplore-app/explore?var-ds=loki**.

Then open **https://grafana.yourdomain.tld** (no need for `ssh -L 3000:localhost:30080 inf-1`).

If the host must be different (e.g. `central.grafana.yourdomain.tld`), change `grafana.yourdomain.tld` in `values.yaml` (`gatewayAPI.grafana.hostname`, plus `grafana.ini.server.domain` and `root_url`).

### GitHub OAuth (Assembly → Admin)

- `values.yaml` enables **`auth.github`** (same URLs/scopes/org/team as `k8s-infra` `cluster/applications/templates/prometheus.yaml`) and **`envFromSecret: grafana-secret`**.
- Create the Secret in the cluster from [manifests/grafana-secret.example.yaml](manifests/grafana-secret.example.yaml) (copy, fill `stringData`, apply; never commit real credentials). Bitwarden: Observability / Grafana OIDC Client.
- After `helm upgrade`, use **Sign in with GitHub** at `https://grafana.yourdomain.tld`. Members of `@YOUR_GITHUB_ORG/assembly` get **Admin**; others in the allowed org get **Viewer** (see `role_attribute_path` in `values.yaml`).

**Production (MicroK8s on `inf-1`):** use `microk8s helm3` and `microk8s kubectl`. Prefer `helm get values observability-central -n observability -o yaml`, merge OAuth fields into that file, and `helm upgrade -f` that merged file so WAZUH/extra dashboards and scrapes stay intact. Dashboard JSON ConfigMap is not in the Helm chart (size limit): apply `k8s-infra/cluster/templates/observability-dashboards-configmap.yaml` with `kubectl delete configmap grafana-dashboards-json -n observability --ignore-not-found` then `kubectl create -f …` if `kubectl apply` fails on metadata size. If new Grafana pods fail in `init-chown-data` with `chown: … Permission denied` on an **existing** PVC, set `kube-prometheus-stack.grafana.initChownData.enabled: false` for that cluster. If Helm reports resources “cannot be imported”, add `meta.helm.sh/release-name` / `release-namespace` and `app.kubernetes.io/managed-by: Helm` where the chart expects them (e.g. blackbox-exporter, HTTPRoutes).

## Grafana admin and resilience

- **Grafana password:** The Grafana subchart creates the admin secret automatically (no credentials in `values.yaml`). Retrieve from the created Secret; see runbook. For production, use external-secrets or create the Secret manually.
- **OTel Gateway:** 2 replicas by default, with resources (requests/limits), HPA (min 2, max 5, CPU 70%), PDB (minAvailable 1). Scheduling left to Kubernetes (no nodeSelector/nodeAffinity in chart).
- **Grafana:** PDB minAvailable 1.
- **Alertmanager:** Disabled (cluster service CIDR conflict). When enabled, configure receivers (email, Slack, etc.) when the alert channel is defined.

## What is included

- **kube-prometheus-stack:** Prometheus, Grafana, Alertmanager (when enabled), node-exporter, kube-state-metrics. Scrape configs (kubernetes-pods, kubernetes-endpoints, cumulus-snmp, static). Datasources: Loki, Victoria Metrics.
- **Grafana:** Dashboards and alerting provisioned (ConfigMaps). Exposed by `HTTPRoute` (Gateway API). Admin secret created by subchart (see runbook).
- **Loki:** Default `values.yaml`: SingleBinary, 20Gi, caches disabled. With `values-production.yaml`: Distributed (microservices) + MinIO; receives logs from the OTel gateway.
- **Victoria Metrics Single:** Metrics backend for the new stack. Receives from the OTel gateway (prometheusremotewrite). Port 8428.
- **OTel Collector (gateway):** 2 replicas, resources, HPA and PDB. Receives OTLP from Cloud agents; exports metrics to Victoria Metrics and logs to Loki. Exposed by `HTTPRoute` to `https://otel.yourdomain.tld` (external 443, backend 4318).

### Logs (Loki) and Drilldown

- **Requirements:** [Grafana Logs Drilldown](https://grafana.com/docs/plugins/grafana-lokiexplore-app/latest/) requires Grafana 11.6+ and Loki 3.2+. In this chart: Grafana 12.1, Loki 3.6; Loki with `volume_enabled: true`, `discover_service_name`, `pattern_ingester.enabled: true`.
- **Explore:** menu (☰) → **Explore** → datasource **Loki** (LogQL).
- **App Logs (Drilldown):** menu **Drilldown > Logs** or direct link: [Open Logs Drilldown](https://grafana.yourdomain.tld/a/grafana-lokiexplore-app/explore?var-ds=loki).

### "App not found" (generic)

Use menu (☰) → **Dashboards** or **Explore**. To change the home page: profile → **Preferences** → **Home dashboard**.
