# OpenTelemetry endpoints for Cloud Mission (and Cloud team)

How to send metrics (and optionally logs) from **Cloud Mission** workloads—Ceph, OpenStack, Proxmox, exporters, etc.—into YOUR_ORG observability.

There are **two public OTLP gateways** today. They are **not interchangeable** for Grafana: each gateway feeds the stack behind its hostname.

---

## Which endpoint should I use?

| Goal | OTLP gateway | Grafana to verify metrics |
|------|----------------|---------------------------|
| **New / target (production central stack)** | `https://otel.yourdomain.tld` | `https://grafana.yourdomain.tld` (org **Cloud**, dashboards with `team="cloud"`) |
| **Legacy / still supported** | `https://otel.yourdomain.tld` | `https://grafana.yourdomain.tld` |

**Policy:** We are migrating senders to **observability**. **`otel.yourdomain.tld` stays online** until production on observability is validated end-to-end (Ceph/OpenStack visible in Grafana, Victoria Metrics cluster healthy, no critical gaps). **Do not decommission infra** based on this doc alone—coordinate with Assembly observability.

**For platform-admin / Cloud Mission ask (Ceph & OpenStack):** point exporters or OTel collectors at **`https://otel.yourdomain.tld/v1/metrics`** with resource attribute **`team=cloud`** (see labels below).

---

## 1. Production gateway — observability (preferred for new traffic)

Runs on the **observability** Kubernetes cluster (`observability-1/2/3`). OTLP is received by `otel-deploy` (central collector) and written to **Victoria Metrics** (cluster `vmselect`) and **Victoria Logs** in namespace `observability`.

| Field | Value |
|-------|--------|
| **Server / host** | `otel.yourdomain.tld` |
| **Port** | `443` |
| **Protocol** | `HTTPS` |
| **Metrics path** | `/v1/metrics` |
| **Logs path** | `/v1/logs` |
| **Verify TLS** | Yes |

**Full URLs:**

- Metrics: `https://otel.yourdomain.tld/v1/metrics`
- Logs: `https://otel.yourdomain.tld/v1/logs`

Authentication: **none** on OTLP HTTP today (no Bearer required). If we enable auth later, we will announce headers separately.

**OTel Collector exporter example (metrics + logs):**

```yaml
exporters:
  otlphttp/central-observability:
    endpoint: https://otel.yourdomain.tld
    tls:
      insecure: false
```

---

## 2. Legacy gateway — infra (keep until cutover is complete)

Runs on the **infra** cluster (`inf-1`). Still used by some Cloud/Proxmox setups and older docs/playbooks. Metrics land in the **infra** observability deployment (separate Grafana).

| Field | Value |
|-------|--------|
| **Server / host** | `otel.yourdomain.tld` |
| **Port** | `443` |
| **Protocol** | `HTTPS` |
| **Metrics path** | `/v1/metrics` |
| **Verify TLS** | Yes |

**Full metrics URL:** `https://otel.yourdomain.tld/v1/metrics`

Same as observability: **no HTTP auth** on OTLP today.

**Proxmox “OpenTelemetry Server” form (infra — legacy):**

| Field | Value |
|-------|--------|
| **Name** | `observability-infra` (or internal name) |
| **Server** | `otel.yourdomain.tld` |
| **Port** | `443` |
| **Protocol** | `HTTPS` |
| **Path** | `/v1/metrics` |
| **Enabled** | Yes |
| **Timeout (s)** | `5` (or default) |
| **Verify SSL** | Yes |
| **Max Body Size (bytes)** | `10000000` (or default) |
| **Compression** | `None` (or `gzip` if supported) |

When migrating Proxmox or exporters from infra → observability, change **only** the host to `otel.yourdomain.tld` and confirm dashboards on **grafana.observability**.

---

## 3. Resource attributes (labels) — required for Cloud dashboards

Send **resource attributes** on every OTLP payload. Observability Grafana dashboards for Ceph/OpenStack filter on **`team="cloud"`** (and related labels). Without `team=cloud`, panels may show **No data** even if ingestion works.

| Attribute (key) | Example value | Notes |
|-----------------|---------------|--------|
| `team` | `cloud` | **Required** for Cloud org dashboards on observability Grafana |
| `environment` | `production`, `staging`, `dev` | Filter by environment |
| `service.name` | `ceph-exporter`, `openstack-exporter`, `proxmox` | OTel semantic convention |
| `datacenter` or `region` | `vienna`, `dc1` | Optional |
| `cluster` | e.g. cloud cluster name | Optional; used in multi-cluster views |

**Example (JSON) for Proxmox Advanced / collector `resource` processor:**

```json
{
  "environment": "production",
  "service.name": "ceph-exporter",
  "datacenter": "vienna",
  "team": "cloud"
}
```

See also [multi-cluster-labels-schema.md](./multi-cluster-labels-schema.md) for edge/K8s clusters using `cluster` and `environment`.

---

## 4. Summary for copy-paste (Teams / tickets)

**Production (ask Cloud Mission to use this for Ceph & OpenStack):**

- Metrics: `https://otel.yourdomain.tld/v1/metrics`
- Logs (if needed): `https://otel.yourdomain.tld/v1/logs`
- Labels: at least `team=cloud`, `environment`, `service.name`
- Verify in: `https://grafana.yourdomain.tld`

**Legacy (still valid; do not turn off yet):**

- Metrics: `https://otel.yourdomain.tld/v1/metrics`
- Verify in: `https://grafana.yourdomain.tld`

After enabling the observability endpoint, contact Assembly if metrics do not appear—we can check gateway routes, TLS, and Victoria Metrics ingestion on the observability cluster.

---

## 5. Related docs

- [multi-cluster-observability-status.md](./multi-cluster-observability-status.md) — central stack and `otel.observability` for K8s edge clusters
- [multi-cluster-labels-schema.md](./multi-cluster-labels-schema.md) — standard attributes for remote clusters
