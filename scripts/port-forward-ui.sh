#!/usr/bin/env bash
# Local access to Grafana (and optionally Prometheus) when ingress is disabled (lab mode).
set -euo pipefail

NAMESPACE="${NAMESPACE:-observability}"

echo "Services in $NAMESPACE:"
kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=grafana 2>/dev/null || kubectl get svc -n "$NAMESPACE" | grep -i grafana || true
echo
echo "Starting Grafana port-forward on http://localhost:3000"
echo "Press Ctrl+C to stop."
echo

# kube-prometheus-stack often names the service "grafana" when fullnameOverride is set
if kubectl get svc grafana -n "$NAMESPACE" &>/dev/null; then
  exec kubectl port-forward -n "$NAMESPACE" svc/grafana 3000:3000
fi

# Fallback: first service matching *grafana*
G=$(kubectl get svc -n "$NAMESPACE" -o name | grep -i grafana | head -1 | cut -d/ -f2)
if [[ -n "$G" ]]; then
  exec kubectl port-forward -n "$NAMESPACE" "svc/$G" 3000:3000
fi

echo "Could not find Grafana service. Run: kubectl get svc -n $NAMESPACE"
exit 1
