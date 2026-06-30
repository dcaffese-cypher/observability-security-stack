# OpenTelemetry endpoint for Cloud team (Proxmox)

Information for the Cloud team to configure the OpenTelemetry Server in Proxmox so metrics are sent to our central observability stack and visible in Grafana.

---

## 1. Endpoint configuration

Use these values in the "Create: OpenTelemetry Server" form:

| Field | Value |
|-------|--------|
| **Name** | `observability-central` (or any internal name you prefer) |
| **Server** | `otel.yourdomain.tld` |
| **Port** | `443` |
| **Protocol** | `HTTPS` |
| **Path** | `/v1/metrics` |
| **Enabled** | Yes (checked) |
| **Timeout (s)** | `5` (or default) |
| **Verify SSL** | Yes (checked) |
| **Max Body Size (bytes)** | `10000000` (or default) |
| **Compression** | `None` (or `gzip` if supported) |

**Full metrics URL:** `https://otel.yourdomain.tld/v1/metrics`

We do not require HTTP authentication today; you can leave **HTTP Headers** empty (no Bearer token). If we enable auth later, we will share the header details.

---

## 2. Resource attributes (labels) — recommended

Yes, you should send **resource attributes** (labels). They are used to filter and group metrics in Grafana (e.g. by environment, datacenter, service). Please configure at least these so we can organize and query your metrics consistently:

| Attribute (key) | Example value | Notes |
|-----------------|---------------|--------|
| `environment` | `production` or `staging` / `dev` | Required for filtering by env |
| `service.name` | e.g. `proxmox` or `proxmox-<hostname>` | Identifies the source service |
| `datacenter` or `region` | e.g. `dc1`, `vienna`, `us-east-1` | Optional but useful for multi-site |
| `team` or `project` | e.g. `cloud` | Optional; helps ownership in dashboards |

**Example Resource Attributes (JSON)** for the Advanced section:

```json
{
  "environment": "production",
  "service.name": "proxmox",
  "datacenter": "vienna",
  "team": "cloud"
}
```

Our pipeline already maps attributes such as `environment`, `service.name` and similar into the metrics store; using these keys keeps your data aligned with our dashboards and alerts. You can add more attributes (e.g. `host.name`, `cluster`) if your Proxmox client supports them.

---

## 3. Summary for copy-paste

- **Endpoint URL (metrics):** `https://otel.yourdomain.tld/v1/metrics`
- **Authentication:** None currently.
- **Labels:** Yes — please send at least `environment` and `service.name`; we recommend adding `datacenter` and `team` as in the JSON example above.

After saving the OpenTelemetry Server in Proxmox and enabling it, metrics should appear in our central stack (Victoria Metrics) and be queryable in Grafana. If something does not show up, we can check connectivity and TLS from your side and our ingress/gateway logs.
