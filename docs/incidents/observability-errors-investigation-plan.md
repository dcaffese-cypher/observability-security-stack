# Plan: Investigate and Resolve Error Logs (observability namespace)

This document defines the plan to investigate and resolve error-level logs from our **observability** namespace in Loki. Errors that are **expected** (e.g. OTel/Victoria Metrics “no data yet”) are left as acceptable; the rest are investigated and fixed where possible.

---

## 1. Scope and categories

| Category | Action |
|----------|--------|
| **Acceptable** | OTel endpoint / Victoria Metrics: “no data received”, “no metrics” — expected until upstream sends data. No fix. |
| **Fixable** | Grafana, Loki (sidecar/runtime), Prometheus, other components: investigate root cause and apply config or code fixes. |

---

## 2. Phase 1 – Identify error sources (by pod/component)

**Objective:** Know which pods in `observability` emit error logs and in what volume.

**Steps:**

1. **Loki query – count errors by pod (last 7d)**  
   In Grafana Explore (Loki) or via API:
   ```logql
   sum by (k8s_pod_name) (count_over_time({k8s_namespace_name="observability"} | detected_level="error" [7d]))
   ```
   Record: pod name → approximate count. Typical pods:
   - `grafana-*` (Grafana)
   - `observability-central-loki-0` (Loki + sidecar `loki-sc-rules`)
   - `observability-central-*-otel-collector-*` (OTel Collector)
   - `observability-central-victoria-metrics-single-*` (Victoria Metrics)
   - `prometheus-observability-central-kube-prometheus-*` (Prometheus)

2. **Sample error lines per pod**  
   For each pod with non-negligible count, run (replace `POD_NAME`):
   ```logql
   {k8s_namespace_name="observability", k8s_pod_name=~"POD_NAME.*"} | detected_level="error"
   ```
   Limit 20–50, note recurring messages (e.g. “failed to …”, “connection refused”, “no such host”).

3. **Classify each recurring message**  
   - **OTel / Victoria Metrics:** “no incoming data”, “no metrics”, “empty” → mark **Acceptable**.  
   - **Loki sidecar:** SSL/K8s API (see [loki-error-logs-evaluation.md](loki-error-logs-evaluation.md)) → already mitigated with `loki.sidecar.skipTlsVerify: true`; if still present, verify deployment.  
   - **Grafana / Prometheus / other:** mark **Fixable** and continue to Phase 2.

---

## 2.1 Phase 1 results (executed)

**Error counts by pod (last 7d, observability namespace):**

| Count (7d) | Pod |
|-----------:|-----|
| 121,123 | prometheus-observability-central-kube-prometheus-0 |
| 4,467 | observability-central-loki-0 |
| 266 | grafana-6fcd65bb9-lj26n |
| 88 | grafana-64f7848d64-h5bls |
| 88 | observability-central-kube-operator-678cf97d9b-fq46v |
| 57 | grafana-7887d8f5f-pmv82 |
| 16 | otel-collector-8fc778cbd-ltf9q |
| 5 | grafana-6c8d494bd7-hzj4w |
| 4 | otel-collector-8fc778cbd-hw4h4 |
| 3 | grafana-7b5bd8f9c5-x9f55 |
| 1 | grafana-7497bd6cb7-bq47j |

*Victoria Metrics: no error streams in this namespace for the period (0 errors — acceptable).*

**Sample messages and classification:**

| Component | Sample message | Category | Action |
|-----------|----------------|----------|--------|
| **Prometheus** | `Scrape commit failed` … `open /prometheus/wal/00000267: no such file or directory` | Fixable (historical?) | WAL was damaged during earlier cleanup. Verify Prometheus is healthy now; if errors persist, ensure WAL is recreated (restart/clear). |
| **Loki** | `error notifying scheduler about finished query` err=EOF; `context canceled` | Low / benign | Query cancellation (e.g. user changed time range). Optional: tune timeouts; can accept. |
| **Grafana** | `Notify for alerts failed` … `SMTP not configured, check your grafana.ini [smtp] section` | Fixable | Alerts use default email contact point. Configure SMTP in Grafana or change contact point (e.g. disable email / use noop). |
| **Kube-operator** | Same as Prometheus (logs attributed from Prometheus pod) | Same as Prometheus | No separate fix. |
| **OTel (observability)** | 1) `lookup inf-4 on ... no such host` (kubeletstats) | Acceptable | Node inf-4 down or not in DNS; no action for our stack. |
| **OTel (observability)** | 2) `Exporting failed. Dropping data` … `grpc: received message larger than max (8710332 vs. 4194304)` to Loki OTLP | Fixable | Loki gRPC max message size (4 MiB) exceeded by OTel log batches. Increase Loki `grpc_max_recv_msg_size` or reduce OTel log batch size. |

**Summary for Phase 2:** Resolve (1) Prometheus WAL if still failing, (2) Grafana SMTP/alert contact point, (3) Loki gRPC max message size or OTel batch size for OTLP logs. Accept OTel “no such host” and VM “no data”; treat Loki “context canceled” as benign unless frequent.

---

## 2.2 Phase 2 results (executed)

| Item | Action taken | Status |
|------|----------------|--------|
| **Prometheus WAL** | Checked recent logs: WAL replay and checkpoints OK; no current errors. | Verified healthy; no change. |
| **Grafana alerting** | Added `grafana.ini` → `smtp.enabled: false`. Provisioned contact point `observability-default` (webhook) and switched all alert rules from `grafana-default-email` to `observability-default`. Added `contactpoints.yml` to `grafana-alerting` ConfigMap. | Deployed; Grafana restarted. |
| **OTel→Loki gRPC size** | Loki `server.grpc_max_recv_msg_size` not supported in current Loki server.Config. Mitigated by adding `batch/logs` processor in OTel (`send_batch_size: 100`) so log batches stay under 4 MiB. | Deployed; OTel Collector restarted. |

*If system alerts (e.g. DatasourceNoData) still use the built-in default contact point, set the default contact point in Grafana UI (Alerting → Contact points) to `observability-default`.*

---

## 2.3 Current errors after Phase 2 (24h view)

**Counts by pod (last 24h):** Prometheus ~121k (historical WAL errors), Loki ~4.5k, Grafana ~450 (several pods), OTel ~63. Many of the 24h counts are from before the fixes.

**Recent error types (last 2h):**

| Source | Error | Cause | Action |
|--------|--------|--------|--------|
| **Grafana** | `observability-default/webhook[0]: ... Post "…": dial tcp 127.0.0.1:9999: connect: connection refused` | Contact point webhook pointed to `http://127.0.0.1:9999/noop`; nothing was listening. | **Fixed in chart:** webhook URL set to `https://httpbin.org/post` (returns 200). For production, replace in `contactpoints.yml` with an internal webhook or real channel. |
| **Grafana** | `Failed resource call from loki` … `dial tcp 10.152.184.165:3100: connection refused` | Grafana calling Loki while Loki was restarting (transient). | None if Loki is stable now. |
| **OTel** | (fewer than before) | Batch size reduction for logs. | Monitor; no change unless "message larger than max" reappears. |

**Improvement:** SMTP "not configured" errors are gone. OTel "Exporting failed … message larger than max" should be reduced with smaller log batches. Webhook contact point updated to `https://httpbin.org/post` so notifications do not fail (deployed).

### About the ~370 current errors (breakdown)

Breakdown by pod (last 6h): **Loki ~101**, **Grafana ~135** (several pods), **OTel ~47**, **Prometheus ~10**, plus a few from ephemeral curl pods.

| Source | What’s happening | Action |
|--------|-------------------|--------|
| **Loki** | `context canceled`, `error notifying scheduler ... err=EOF` | Benign (user or UI cancelling queries). No change. |
| **Grafana** | 1) `grafana-default-email ... SMTP not configured` (new pod) | **Default** notification policy still uses built-in email. In Grafana: **Alerting → Contact points** → set default to **observability-default**. |
| **Grafana** | 2) `observability-default/webhook ... connection refused` (127.0.0.1:9999) | From before the webhook URL was changed to httpbin.org. New pods use httpbin; these entries are old. |
| **Grafana** | 3) `plugin table is already registered` | Known Grafana quirk (core plugin loaded twice). Harmless. |
| **Grafana** | 4) `Failed resource call from loki ... connection refused` | Transient when Loki was restarting. None if Loki is stable. |
| **OTel** | kubeletstats / “no such host” or similar | Acceptable (node DNS). |
| **Prometheus** | Scrape/WAL (few in 6h) | Old or rare; Prometheus is healthy. |

So most of the 370 are **benign or legacy**. To reduce Grafana errors: set the **default contact point** in the UI to **observability-default**.

---

### Historical Prometheus WAL errors in Loki (121k+ lines)

Those entries are **log lines already stored in Loki** (Prometheus stderr from when the WAL was damaged). They are not in Prometheus anymore; Prometheus is healthy and not writing new WAL errors.

- **Can we fix them?** There is nothing to fix in Prometheus; it is already fixed. The “errors” you see are old log events in Loki.
- **Can we delete them?** Loki does **not** support deleting logs by query or by content. Data is only removed by **retention** (time-based). With `retention_period: 168h` (7 days), those old error lines will **disappear automatically** once they are older than 7 days. No action needed.
- **Optional (not recommended):** Shortening `retention_period` in Loki would drop *all* logs in that window, not just Prometheus errors, so it is usually not worth it. Letting the 7-day retention clear them is the right approach.

---

## 3. Phase 2 – Investigate fixable errors

For each component with fixable errors, follow the steps below.

### 3.1 Grafana

- **Check:** Loki samples for `k8s_pod_name=~"grafana.*"` and `detected_level="error"`.  
- **Frequent causes:**  
  - Data source connection errors (Loki, Prometheus, Victoria Metrics) → check URLs, network, TLS.  
  - Plugin / provisioning errors → check ConfigMaps (dashboards, datasources, alerting).  
  - Auth / session errors → often benign or env-specific.  
- **Actions:**  
  - Confirm data sources in Grafana UI (Configuration → Data sources) are reachable.  
  - Check `grafana` deployment env and mounted configs; fix any wrong URLs or missing secrets.  
  - If errors reference a specific plugin, disable or update the plugin.

### 3.2 Loki (main process and sidecar)

- **Sidecar (`loki-sc-rules`):**  
  - Already documented in [loki-error-logs-evaluation.md](loki-error-logs-evaluation.md).  
  - Ensure `loki.sidecar.skipTlsVerify: true` is in `values.yaml` and applied (Helm upgrade or patch).  
  - Restart Loki StatefulSet if the option was added after deploy; confirm errors stop.  
- **Loki main (ingestion/querier):**  
  - Sample error lines; typical issues: storage (disk, object store), limits (ingestion rate, query timeout).  
  - Adjust `loki.loki.limits_config` or storage/schema if needed; see [loki-chunks-cache-memory.md](loki-chunks-cache-memory.md) if cache-related.

### 3.3 OTel Collector (observability namespace)

- **Acceptable:** Errors like “no data received”, “no metrics from upstream”, “endpoint has no traffic” — no action until upstream (e.g. Cloud) sends OTLP.  
- **Fixable:**  
  - Exporter errors (e.g. “failed to write to Victoria Metrics”, “connection refused” to VM).  
  - Receiver errors (e.g. bind address, TLS, parsing).  
- **Actions:**  
  - Verify `victoriaMetricsWriteEndpoint` and VM service are reachable from the OTel pod.  
  - Check OTel Collector config (ConfigMap/Helm values) for typos and correct ports/hosts.  
  - If TLS to VM: ensure certs/volumes are correct.

### 3.4 Victoria Metrics

- **Acceptable:** “No data”, “no active writers”, “idle” — expected until OTel or other scrapers send metrics.  
- **Fixable:**  
  - “Permission denied”, “disk full”, “failed to open TSDB”.  
  - “Remote write failed” from OTel → usually fix on OTel/VM config or network.  
- **Actions:**  
  - Check PVC and disk space; fix permissions or storage.  
  - Confirm remote write URL and auth (if any) from OTel Collector.

### 3.5 Prometheus

- **Typical errors:** Scrape failures (target down, timeout, TLS), TSDB/WAL errors.  
- **Actions:**  
  - List targets (Prometheus UI → Status → Targets); fix broken jobs or service discovery.  
  - If WAL/TSDB errors persist after earlier cleanup, consider retention or storage settings; avoid aggressive deletion of live data.

---

## 4. Phase 3 – Apply fixes and verify

1. **Change only one area at a time** (e.g. Grafana datasource, then Loki sidecar, then OTel).  
2. **Apply change:** Helm upgrade, ConfigMap edit + rollout restart, or secret fix.  
3. **Wait 5–15 minutes**, then re-run the Loki query by pod (Phase 1) and sample errors for that component.  
4. **Document:** “Component X: error type Y → fix Z; before/after count.”

---

## 5. Summary checklist

- [x] Run Phase 1 queries; list pods and approximate error counts.  
- [x] Sample and classify errors: Acceptable (OTel/VM “no data”) vs Fixable.  
- [ ] **Prometheus:** Verify current WAL health; if “Scrape commit failed” still occurs, fix WAL (restart/clear as in runbook).  
- [ ] **Grafana:** Fix alerting: configure SMTP in `grafana.ini` or change default contact point so “DatasourceNoData” does not use email.  
- [ ] **OTel→Loki:** Increase Loki gRPC max receive message size (or reduce OTel log batch size) to stop “received message larger than max” and dropped logs.  
- [ ] For Loki sidecar: confirm `skipTlsVerify: true` is applied and restart if needed.  
- [ ] For Grafana: check datasources and provisioning; fix any wrong config.  
- [ ] For OTel Collector: fix only real failures (e.g. VM write); leave “no data” / “no such host” as acceptable.  
- [ ] For Victoria Metrics / Prometheus: fix storage or scrape issues; leave “no data” as acceptable.  
- [ ] Re-check error counts after each fix and update this doc or [loki-error-logs-evaluation.md](loki-error-logs-evaluation.md).

---

## 6. Quick reference – Loki queries (Grafana Explore)

| Goal | Query |
|------|--------|
| Errors by pod (7d) | `sum by (k8s_pod_name) (count_over_time({k8s_namespace_name="observability"} \| detected_level="error" [7d]))` |
| Sample errors for a pod | `{k8s_namespace_name="observability", k8s_pod_name=~"grafana.*"} \| detected_level="error"` |
| Only OTel Collector | `{k8s_namespace_name="observability", k8s_pod_name=~".*otel-collector.*"} \| detected_level="error"` |
| Only Victoria Metrics | `{k8s_namespace_name="observability", k8s_pod_name=~".*victoria-metrics.*"} \| detected_level="error"` |

Use these in Grafana Explore (Loki) with a 7d or 24h range as needed.
