# Runbook: post-deploy checks

Validation steps after any `helm upgrade` or GitOps deploy of `observability-central`.

---

## 1. Pods

```bash
microk8s kubectl get pods -n observability -o wide
```

Expected: all pods `Running` (or `Completed` for jobs). No `CrashLoopBackOff` or `Pending`.

---

## 2. Gateway API routing

```bash
# HTTPRoutes accepted and refs resolved
microk8s kubectl get httproute -n observability

# Expected per route: ACCEPTED=True, RESOLVEDREFS=True
microk8s kubectl get httproute grafana-route -n observability \
  -o jsonpath='{.status.parents[0].conditions}' | python3 -m json.tool

microk8s kubectl get httproute otel-route -n observability \
  -o jsonpath='{.status.parents[0].conditions}' | python3 -m json.tool
```

---

## 3. TLS certificates

```bash
# All certs Ready in envoy-gateway-system
microk8s kubectl get certificate -n envoy-gateway-system

# Check days to expiry
microk8s kubectl get certificate -n envoy-gateway-system \
  -o jsonpath='{range .items[*]}{.metadata.name}{" expires: "}{.status.notAfter}{"\n"}{end}'
```

---

## 4. Endpoint availability

```bash
# From outside the cluster
curl -sv https://grafana.yourdomain.tld 2>&1 | grep -E "SSL|HTTP|Connected"
curl -sv https://otel.yourdomain.tld 2>&1 | grep -E "SSL|HTTP|Connected"
```

Expected: HTTP 200 (Grafana) or 200/400 (OTel — 400 is OK, means it reached the backend).

---

## 5. Blackbox exporter probes

```bash
# Check probe_success from inside cluster
microk8s kubectl exec -n observability deployment/grafana -- \
  wget -qO- 'http://blackbox-exporter:9115/probe?target=https://grafana.yourdomain.tld&module=https_grafana' \
  | grep probe_success
```

Expected: `probe_success 1`

---

## 6. OTel ingestion

```bash
# Send a test metric via OTLP HTTP
curl -X POST https://otel.yourdomain.tld/v1/metrics \
  -H "Content-Type: application/json" \
  -d '{"resourceMetrics":[]}'
```

Expected: HTTP 200 (empty payload accepted).

---

## 7. Grafana datasources

In Grafana → Connections → Data sources:
- **Prometheus**: Save & Test → OK
- **Victoria Metrics**: Save & Test → OK
- **Loki**: Save & Test → OK

---

## 8. VM Backup status (when enabled)

```bash
# Check last backup job
microk8s kubectl get jobs -n observability | grep vm-backup

# Check CronJob last schedule
microk8s kubectl get cronjob -n observability vm-backup-hourly \
  -o jsonpath='{.status.lastScheduleTime}'
```
