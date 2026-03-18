#!/usr/bin/env bash
# Check tools needed for Kubernetes or VM-Docker paths.
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
  echo "         → https://kubernetes.io/docs/tasks/tools/"
fi

if command -v helm >/dev/null 2>&1; then
  echo "  [OK]   helm $(helm version --short 2>/dev/null || echo installed)"
else
  echo "  [MISS] helm not found"
  echo "         → https://helm.sh/docs/intro/install/"
fi

echo
echo "-- VM Docker stack --"
if command -v docker >/dev/null 2>&1; then
  echo "  [OK]   $(docker --version 2>/dev/null)"
  if docker compose version &>/dev/null 2>&1; then
    echo "  [OK]   docker compose plugin"
  else
    echo "  [MISS] docker compose v2 plugin"
    echo "         → Install Docker Compose plugin"
  fi
else
  echo "  [MISS] docker not found"
fi

echo
echo "-- Optional: Ansible agents --"
if command -v ansible-playbook >/dev/null 2>&1; then
  echo "  [OK]   $(ansible-playbook --version | head -1)"
else
  echo "  [SKIP] ansible-playbook (only for VM agent automation)"
fi

echo
echo "Next: observability/GETTING_STARTED.md"
