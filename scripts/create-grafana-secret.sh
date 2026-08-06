#!/usr/bin/env bash
# Creates or updates the Grafana admin Secret required by observability-central.
set -euo pipefail

NAMESPACE="${NAMESPACE:-observability}"
USER="${GRAFANA_ADMIN_USER:-admin}"

read -r -s -p "Grafana admin password (min 8 chars recommended): " PASS
echo
if [[ ${#PASS} -lt 8 ]]; then
  echo "Warning: short password. Continuing."
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic grafana-admin -n "$NAMESPACE" \
  --from-literal=admin-user="$USER" \
  --from-literal=admin-password="$PASS" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "Secret grafana-admin updated in namespace $NAMESPACE"
