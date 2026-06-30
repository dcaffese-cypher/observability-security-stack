# Loki: chunks-cache and memory usage (Sean's feedback)

Sean reported that on inf-1 the pod `observability-central-loki-chunks-cache-0` was using ~61% of the node memory (9830Mi). This document summarizes the options and current state.

---

## What was happening

The Loki chart (Grafana) deploys **memcached** by default for:

- **chunks-cache:** Loki chunks cache (default `allocatedMemory: 8192` MB).
- **results-cache:** Query result cache.

On a node with ~16 GiB, the chunks-cache could reach ~61% of node RAM.

---

## Applied solution (recommended short term)

**Option A – Disable the caches**

- **What it does:** Does not deploy chunks-cache or results-cache. Loki SingleBinary keeps working; queries do not use an external cache.
- **Pros:** Frees memory; no need for a larger node.
- **Cons:** Repeated queries may be slightly slower.

**In the chart:** In `kubernetes/charts/observability-central/values.yaml` (section `loki`):

```yaml
chunksCache:
  enabled: false
resultsCache:
  enabled: false
```

After `helm upgrade`, the chart no longer creates the chunks-cache and results-cache StatefulSets. If those pods **already existed** from a previous install, delete them once:

```bash
microk8s kubectl delete statefulset observability-central-loki-chunks-cache observability-central-loki-results-cache -n observability --ignore-not-found
```

**Current state:** Caches disabled; the pod `observability-central-loki-chunks-cache-*` should not exist. Loki memory usage in the namespace is from the SingleBinary only.

---

## Other options (if you want to keep caches)

### Option B – Reduce cache memory

- In `loki.chunksCache`: lower `allocatedMemory` (e.g. 2048 or 1024) and set `resources.limits.memory`.
- In `loki.resultsCache`: review `maxItemMemory` and limits.
- Keeps some cache with bounded memory use.

### Option C – Increase node size (as Sean suggested)

- More RAM on the node so the same chunks-cache is a smaller share (e.g. 61% → 30%).
- No Loki config change; requires infra change.

---

## How to check usage

- **With Metrics Server:** `microk8s kubectl top pods -n observability` and `microk8s kubectl top nodes`.
- **Without Metrics Server:** In Grafana (Prometheus datasource):  
  `container_memory_working_set_bytes{namespace="observability"}`  
  Or inspect requests/limits:  
  `microk8s kubectl get pods -n observability -o wide` and `microk8s kubectl describe node <node>`.

After applying Option A (and deleting old StatefulSets if they existed), there should be no pods `observability-central-loki-chunks-cache-*` or `observability-central-loki-results-cache-*`; namespace usage is from the Loki SingleBinary pod only.

Repository: `YOUR_ORG/clusters/k8s-infra/Repository/observability-central`
