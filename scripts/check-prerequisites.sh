#!/usr/bin/env bash
# Check tools needed for Kubernetes central stack and optional Ansible agents.
set -euo pipefail

echo "=== Observability — prerequisite check ==="
echo

echo "-- Kubernetes central stack --"
if command -v kubectl >/dev/null 2>&1; then
  echo "  [OK]   kubectl installed"
  if kubectl cluster-info &>/dev/null; then
    echo "  [OK]   kubectl can reach a cluster"
  else
    echo "  [MISS] kubectl cannot reach a cluster"
    echo "         → Run: kubectl cluster-info — fix KUBECONFIG or login"
  fi
else
  echo "  [MISS] kubectl not found"
  echo "         → https://kubernetes.org/docs/tasks/tools/"
fi

if command -v helm >/dev/null 2>&1; then
  echo "  [OK]   helm $(helm version --short 2>/dev/null || echo installed)"
else
  echo "  [MISS] helm not found"
  echo "         → https://helm.sh/docs/intro/install/"
fi

echo
echo "-- Optional: Ansible agents (Linux VMs / remote K8s) --"
if command -v ansible-playbook >/dev/null 2>&1; then
  echo "  [OK]   $(ansible-playbook --version | head -1)"
else
  echo "  [SKIP] ansible-playbook (only for playbooks/otel-agent)"
fi

echo
echo "Next: GETTING_STARTED.md"
