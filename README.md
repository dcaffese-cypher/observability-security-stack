# Observability platform (reference implementation)

Production-oriented **Prometheus**, **Grafana**, **Loki**, **OpenTelemetry**, and **Victoria Metrics** layouts for:

- **Kubernetes** (central hub + per-cluster collectors)
- **Linux VMs** (Proxmox, bare metal) via Docker Compose and Ansible

## Repository layout

```
observability/
  GETTING_STARTED.md   # Beginners: steps + scripts
  ARCHITECTURE.md      # System design
  RUNBOOK.md           # Deploy and operate
  PLACEHOLDERS.md      # Tokens to replace
  kubernetes/charts/   # Helm: observability-central, observability-edge
  kubernetes/gitops/   # TLS + Argo CD examples
  ansible/otel-agent/  # VM + K8s agent deployment
  vm-docker/           # Docker Compose central stack + agent examples
  examples/            # Sample Grafana dashboard JSON
  scripts/             # setup scripts + loki-maintenance, prometheus-tsdb-trim, demo-cleanup
integrations/
  zabbix/              # Optional Zabbix agent automation
  wazuh/               # Optional Wazuh playbooks
```

## Quick start (beginners)

1. **Start here:** [observability/GETTING_STARTED.md](observability/GETTING_STARTED.md) — step-by-step paths, copy-paste commands, helper scripts.
2. Run checks: `chmod +x observability/scripts/*.sh && ./observability/scripts/check-prerequisites.sh`
3. Then: Kubernetes lab → `./observability/scripts/create-grafana-secret.sh` → `./observability/scripts/helm-install-central.sh lab` → `./observability/scripts/port-forward-ui.sh`

## Reference docs

- [observability/ARCHITECTURE.md](observability/ARCHITECTURE.md) — design
- [observability/RUNBOOK.md](observability/RUNBOOK.md) — operations
- [observability/PLACEHOLDERS.md](observability/PLACEHOLDERS.md) — what to replace

## License

Configure as appropriate for your organization when publishing.
