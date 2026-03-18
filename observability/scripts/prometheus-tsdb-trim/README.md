# Prometheus TSDB trim (Docker)

Shell script to remove Prometheus TSDB blocks whose **duration** exceeds a threshold (default 20h). Intended for Docker deployments where Prometheus data lives in a named volume or bind mount.

## Usage

```bash
# On the host running the Prometheus container
DRY_RUN=1 ./prometheus-tsdb-trim.sh   # preview
./prometheus-tsdb-trim.sh             # execute
```

Optional: `PROM_CONTAINER`, `DURATION_HOURS_THRESHOLD`, `LOG_FILE`. See script header.

## Cron

Use `setup-prometheus-trim-cron.sh` or add a root crontab entry after reviewing retention policy.

## Related

- Central Docker stack: [vm-docker/central-stack](../../vm-docker/central-stack/)
- Operations: [RUNBOOK.md](../../RUNBOOK.md)
