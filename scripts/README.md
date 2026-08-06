# Helper scripts

| Script | Purpose |
|--------|---------|
| `check-prerequisites.sh` | Verify kubectl, helm, optional ansible |
| `create-grafana-secret.sh` | Create `grafana-admin` Secret |
| `helm-install-central.sh` | Install chart (`lab` or `production`) |
| `port-forward-ui.sh` | Grafana on http://localhost:3000 |
| `ansible-copy-inventory.sh` | Create `playbooks/otel-agent/inventory.local.ini` |
| `sanitize-for-public.py` | Maintainer: redact hostnames/IPs before publish |

Walkthrough: [../GETTING_STARTED.md](../GETTING_STARTED.md).
