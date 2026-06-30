# Runbook: VictoriaMetrics restore from S3 backup

Step-by-step restore procedure for `observability-central-victoria-metrics-single`.

**RTO estimate:** 15–30 minutes (depending on backup size and S3 throughput).  
**RPO:** up to 1 hour (last hourly backup).

---

## 1. Prerequisites

- Access to `inf-1` via SSH.
- S3 credentials available (same Secret used by backup CronJobs).
- `vmrestore` binary (same image as `vmbackup`).

---

## 2. Identify the backup to restore

```bash
# List available daily backups
aws s3 ls s3://YOUR_OBSERVABILITY_BACKUP_BUCKET/central/daily/ --endpoint-url <S3_ENDPOINT>

# List available hourly backups
aws s3 ls s3://YOUR_OBSERVABILITY_BACKUP_BUCKET/central/hourly/ --endpoint-url <S3_ENDPOINT>
```

Choose the most recent daily backup, or the latest hourly if more recent data is needed.

---

## 3. Scale down VictoriaMetrics

```bash
microk8s kubectl scale statefulset observability-central-victoria-metrics-single \
  -n observability --replicas=0

# Wait until pod is terminated
microk8s kubectl get pods -n observability -w | grep victoria
```

---

## 4. Run vmrestore

```bash
microk8s kubectl run vmrestore --rm -it \
  --image=victoriametrics/vmbackup:v1.101.0 \
  --restart=Never \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "vmrestore",
        "image": "victoriametrics/vmbackup:v1.101.0",
        "command": ["/vmrestore"],
        "args": [
          "-src=s3://YOUR_OBSERVABILITY_BACKUP_BUCKET/central/daily/YYYY-MM-DD",
          "-storageDataPath=/victoria-metrics-data",
          "-s3.endpoint=<S3_ENDPOINT>",
          "-s3.region=eu-west-1"
        ],
        "env": [
          {"name": "AWS_ACCESS_KEY_ID", "valueFrom": {"secretKeyRef": {"name": "vm-backup-s3-credentials", "key": "access-key-id"}}},
          {"name": "AWS_SECRET_ACCESS_KEY", "valueFrom": {"secretKeyRef": {"name": "vm-backup-s3-credentials", "key": "secret-access-key"}}}
        ],
        "volumeMounts": [{"name": "vm-data", "mountPath": "/victoria-metrics-data"}]
      }],
      "volumes": [{"name": "vm-data", "persistentVolumeClaim": {"claimName": "observability-central-victoria-metrics-single"}}]
    }
  }' \
  -n observability
```

Wait for the restore to complete (`vmrestore` exits 0).

---

## 5. Scale VictoriaMetrics back up

```bash
microk8s kubectl scale statefulset observability-central-victoria-metrics-single \
  -n observability --replicas=1

# Verify pod is Running
microk8s kubectl get pods -n observability | grep victoria
```

---

## 6. Validate restore

```bash
# Check VM is responding
microk8s kubectl exec -n observability \
  statefulset/observability-central-victoria-metrics-single -- \
  wget -qO- http://localhost:8428/health

# Query a known metric to verify data
microk8s kubectl exec -n observability \
  statefulset/observability-central-victoria-metrics-single -- \
  wget -qO- 'http://localhost:8428/api/v1/query?query=up' | python3 -m json.tool | head -30
```

In Grafana → Victoria Metrics datasource → Save & Test → OK.

---

## 7. Post-restore checklist

- [ ] VM pod `Running` and `/health` returns OK.
- [ ] Grafana datasource `Victoria Metrics` Save & Test → OK.
- [ ] Metrics visible in Grafana dashboards.
- [ ] Backup CronJobs resume normally on next schedule.
- [ ] Document incident: date, backup used, data loss window, RCA.
