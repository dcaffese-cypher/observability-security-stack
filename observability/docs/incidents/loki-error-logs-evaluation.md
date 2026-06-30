# Evaluation: Loki Error Logs (observability namespace)

This document evaluates the error-level log entries you see in Loki (e.g. when filtering by `detected_level="error"` or `service_name="k8s-inf-1"`) and whether they indicate problems in **our** observability space.

---

## 1. Errors from our namespace (`observability`)

### 1.1 `observability-central-loki-0` – container `loki-sc-rules`

**What you see in Loki:**
- `HTTPSConnectionPool(host='10.152.183.1', port=443): Max retries exceeded`
- `SSLCertVerificationError ... certificate verify failed: CA cert does not include key usage extension`

**Meaning:**
- The **Loki rules sidecar** (`loki-sc-rules`) watches the Kubernetes API (service `kubernetes` = `10.152.183.1:443`) for ConfigMaps/Secrets with label `loki_rule`, to sync alert/recording rules into Loki.
- The cluster’s API server CA certificate does not include the **key usage extension** that strict OpenSSL/Python expects, so the sidecar’s HTTPS client fails verification and the watch never succeeds.

**Impact on our stack:**
- **Loki itself (ingestion, queries, Explore, dashboards)** works normally.
- Only the **dynamic rules** loaded from ConfigMaps/Secrets via this sidecar are affected: the sidecar cannot refresh them from the API. If you don’t use such ConfigMaps for Loki rules, impact is none. If you do, rules would only be loaded at pod start (from any volume-mounted config), not updated on the fly.

**Fix applied:**
- In `values.yaml` we set `loki.sidecar.skipTlsVerify: true`. That makes the rules sidecar skip TLS verification when talking to the Kubernetes API, so it can watch ConfigMaps/Secrets again. After redeploying the chart, those errors should stop.

**Summary:** This is a **cluster certificate / client strictness** issue, not a bug in our application. We’ve mitigated it for our Loki pod with the sidecar option above.

---

## 2. Errors **not** from our namespace (no action for us)

### 2.1 `otel-collector-lfcvb` – namespace `otel`

**What you see in Loki:**
- `Error scraping metrics` … `"Get \"https://inf-2:10250/stats/summary\": dial tcp: lookup inf-2 on 10.152.184.10:53: no such host"`

**Meaning:**
- This log line comes from the **`otel`** namespace (pod `otel-collector-lfcvb`), not from `observability`.
- That deployment’s OTel Collector uses the **kubeletstats** receiver. It’s trying to reach the kubelet on the node **`inf-2`** by hostname; cluster DNS (`10.152.184.10:53`) does not resolve `inf-2` (e.g. node down, or not registered in DNS).

**Impact on our stack:**
- **None.** This is another team’s/stack’s collector (e.g. “observability-edge” or central OTel in `otel`). Our observability namespace and our OTel Collector in `observability` are unaffected.

**Action:**
- No change needed in our observability space. If desired, the owners of the `otel` namespace can fix node DNS or adjust the receiver’s node discovery.

---

## 3. Other Loki log levels (our namespace)

- **`level=warn` “failed mapping AST” / “context canceled”**  
  These usually mean a query was cancelled (e.g. user changed time range or query in Grafana). They are **expected** and not a sign of a broken stack.

- **`level=info`**  
  Normal query/request logs; no action.

---

## 4. Summary table

| Log source                     | Namespace     | Our problem? | Action |
|--------------------------------|---------------|--------------|--------|
| `observability-central-loki-0` (loki-sc-rules) | observability | Yes (sidecar ↔ API TLS) | Set `loki.sidecar.skipTlsVerify: true` and redeploy (done in values). |
| `otel-collector-lfcvb`         | otel          | No           | None for our observability namespace. |

After you deploy the chart with the updated `values.yaml`, only the Loki rules sidecar fix is in place; the rest of the errors you saw are either benign (context cancelled) or outside our observability space (otel namespace).
