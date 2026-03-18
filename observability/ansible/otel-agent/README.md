# Ansible: OpenTelemetry Collector agents

Deploys the OTel Collector as a **systemd service** on Linux VMs (Proxmox, bare metal, cloud instances) and optionally deploys the **observability-edge** Helm chart on Kubernetes clusters.

## Layout

| Playbook | Target |
|----------|--------|
| `deploy_otel_agent.yml` | Hosts in `[agents]` — VM agents |
| `deploy_otel_k8s.yml` | Hosts in `[k8s_clusters]` — DaemonSet per cluster |
| `deploy_otel_all.yml` | Both (if groups are defined) |

**Run Ansible from** a machine with SSH to agents and (for K8s) Helm + valid kubeconfigs. Not from inside the observability namespace.

## Prerequisites

- Ansible 2.14+
- SSH access to agent hosts
- Docker on agents (collector runs in container via systemd)
- For K8s: `community.kubernetes` or Helm CLI + kubeconfig per cluster

## Configuration

1. Copy `inventory.ini` to a local file (e.g. `inventory.local.ini`) and set hosts — **do not commit real IPs**.
2. Set `master_otlp_http` / `master_otlp_grpc` to your central OTLP endpoint (HTTPS ingress or internal URL). See `../../PLACEHOLDERS.md`.
3. Adjust `group_vars/all.yml` if needed.

## Commands

```bash
cd observability/ansible/otel-agent
ansible-playbook -i inventory.local.ini deploy_otel_agent.yml
ansible-playbook -i inventory.local.ini deploy_otel_k8s.yml
```

Helm chart path for K8s points to `observability/kubernetes/charts/observability-edge` relative to this playbook.

## References

- [RUNBOOK.md](../../RUNBOOK.md)
- [ARCHITECTURE.md](../../ARCHITECTURE.md)
