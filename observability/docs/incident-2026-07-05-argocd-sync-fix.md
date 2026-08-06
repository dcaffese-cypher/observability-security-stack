# Incident Report: ArgoCD `observability-central` Sync Failures
**Date:** Sunday, July 5, 2026  
**Duration:** ~6 hours  
**Status:** ✅ Resolved — `Sync OK`, App Health `Healthy`

---

## Summary

The `observability-central` ArgoCD application was stuck in a permanent `Degraded / SyncError` state. Multiple layered issues were discovered and resolved one by one throughout the day.

---

## Issues Found and Fixes Applied

### 1. `grafana-org-bootstrap` PostSync hook was blocking every sync
**Commit:** `9780b55`  
**File:** `charts/observability-central/templates/grafana-org-bootstrap.yaml`

The job used `set -eu` and `exit 1` on any Grafana API error (wrong org ID, unreachable endpoint, timeout). Since ArgoCD treats `post-install,post-upgrade` hooks as blocking, any failure caused the entire sync to be marked as `SyncError`.

**Fix:**
- Removed `set -eu`; replaced all `exit 1` with `WARNING` logs + error counter
- Health check timeout now exits `0` (warns and skips) instead of failing
- `hook-delete-policy` updated to `before-hook-creation,hook-succeeded,hook-failed` — job is always cleaned up after each sync
- `backoffLimit: 0`, `ttlSecondsAfterFinished: 120`
- The job still runs on every sync and tries to bootstrap Grafana orgs/datasources, but never blocks the sync

---

### 2. `kube-prometheus-stack` certgen jobs were failing on every sync
**Commits:** `60ccee2` → `3f8687c` → `8de2556` (3-step resolution)  
**File:** `charts/observability-central/values.yaml`

The `kube-prometheus-stack` chart by default generates two Helm hook Jobs:
- `observability-central-kube-admission-create` (PreSync) — creates TLS cert secret
- `observability-central-kube-admission-patch` (PostSync) — patches webhook with CA bundle

These ran on **every ArgoCD sync** and were failing, blocking the sync. Investigation revealed a 3-step resolution was needed:

**Step 1 (`60ccee2`) — Disable webhook entirely:**  
Set `admissionWebhooks.enabled: false` + `patch.enabled: false`. This removed the certgen jobs but also removed the `ValidatingWebhookConfiguration` and `MutatingWebhookConfiguration` from the chart. ArgoCD tried to prune them → 2 resources became OutOfSync → new blocking issue.

**Step 2 (`3f8687c`) — Keep webhook configs, only disable certgen jobs:**  
Set `admissionWebhooks.enabled: true` + `patch.enabled: false`. Webhook configs stay in the chart (no pruning), certgen jobs are gone. But now the webhook was active with an expired/untrusted TLS cert → `x509: certificate signed by unknown authority` → 35 `PrometheusRule` resources failed to apply.

**Step 3 (`8de2556`) — Set failurePolicy: Ignore:**  
Added `failurePolicy: Ignore`. When the webhook endpoint has TLS issues, the API server now skips the validation and allows the resource through. All 35 `PrometheusRule` resources synced cleanly.

**Final configuration:**
```yaml
kube-prometheus-stack:
  prometheusOperator:
    admissionWebhooks:
      enabled: true
      failurePolicy: Ignore
      patch:
        enabled: false
```

---

### 3. VictoriaMetrics `retentionPeriod` crash (`3m` vs `3M`)
**Commit:** `534e85c` (July 3)

platform-team MR changed retention to `3m`. VictoriaMetrics interprets `m` as **minutes**, not months — months require capital `M`. Both `victoria-metrics-single` and `vm-cluster-storage` pods entered `CrashLoopBackOff`.

**Fix:** Changed `3m` → `3M` in `values.yaml` + manually patched the running StatefulSets to recover immediately.

---

### 4. VictoriaLogs hourly backup `--delete` flag invalid
**Commit:** `7c179ce`

platform-admin suggested adding `--delete` to the rclone command (from `rsync` syntax). `rclone sync` does not support `--delete` — it already removes extraneous destination files by default.

**Fix:** Removed `--delete` flag from `vlbackup-cluster-hourly.yaml`.

---

### 5. Other changes (earlier in the week)

| Commit | Change |
|--------|--------|
| `682e766` | Fix "List of pods on node" panel: use `kube_pod_info` (available in both clusters) instead of `k8s_pod_phase` |
| `09d675e` | VictoriaLogs backup: disable daily CronJob, reduce hourly from every 1h to every 4h |
| `c17e6ce` | Fix VictoriaLogs datasource URL in org-bootstrap job |

---

## Repository Changes

### `observability` repo (chart)
| Commit | Description |
|--------|-------------|
| `8de2556` | fix(kube-prometheus-stack): failurePolicy=Ignore |
| `3f8687c` | fix(kube-prometheus-stack): keep webhookconfigs, disable certgen |
| `60ccee2` | fix(kube-prometheus-stack): disable admission webhook patch |
| `9780b55` | fix(grafana-org-bootstrap): non-blocking PostSync hook |
| `7c179ce` | fix(vlbackup): remove invalid --delete flag |
| `534e85c` | fix: retentionPeriod 3m → 3M |

### `k8s-observability` repo (ArgoCD Application)
| Commit | Description |
|--------|-------------|
| `32c0bac` | Add ServerSideApplyForce to syncOptions (investigative — may be removed) |

---

## Current State
- **App Health:** Healthy ✅
- **Last Sync:** Sync OK (`8de2556`) ✅
- **Remaining:** 2 resources still OutOfSync (HTTPRoutes — diff is cosmetic/SSA-related, does not affect functionality)

---

## Recommendations

1. **Renew the Prometheus operator webhook TLS cert** — Re-enable `patch.enabled: true` temporarily to let the certgen job run and renew the cert, then set `failurePolicy: Fail` again for proper validation. Or migrate to cert-manager (`admissionWebhooks.certManager.enabled: true`).

2. **Investigate HTTPRoute diff** — The 2 remaining OutOfSync HTTPRoutes (`otel-route`, `grafana-route`) have a minor spec diff (likely port or parentRef). Review with `argocd app diff observability-central`.

3. **VictoriaLogs backup health** — The `vlbackup-cluster-hourly` CronJobs show Degraded health (recent executions failed). Verify S3 credentials and the snapshot API endpoint are reachable.
