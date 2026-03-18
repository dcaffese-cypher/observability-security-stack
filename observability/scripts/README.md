# Helper scripts

| Script | When to use |
|--------|-------------|
| `check-prerequisites.sh` | After clone; verifies kubectl, helm, docker |
| `create-grafana-secret.sh` | Before first Helm install (Kubernetes) |
| `helm-install-central.sh lab` | First install without DNS/TLS |
| `helm-install-central.sh production` | After editing `values.local.yaml` |
| `port-forward-ui.sh` | Lab access to Grafana on :3000 |
| `vm-docker-central-bootstrap.sh` | Docker Compose stack on a VM |
| `ansible-copy-inventory.sh` | Creates `inventory.local.ini` for agents |

Maintenance (advanced): `demo-cleanup/`, `loki-maintenance/`, `prometheus-tsdb-trim/`.

Full walkthrough: [../GETTING_STARTED.md](../GETTING_STARTED.md).
