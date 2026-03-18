#!/usr/bin/env bash
# Install or upgrade observability-central on the current kubectl context.
# Usage:
#   ./helm-install-central.sh lab          # first try: no ingress, 1 OTel replica
#   ./helm-install-central.sh production  # uses values.local.yaml (you must create it)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/../kubernetes/charts/observability-central" && pwd)"
RELEASE="${HELM_RELEASE:-observability-central}"
NAMESPACE="${NAMESPACE:-observability}"
MODE="${1:-lab}"

cd "$CHART_DIR"

if ! kubectl cluster-info &>/dev/null; then
  echo "Error: kubectl cannot reach a cluster."
  exit 1
fi

if ! kubectl get secret grafana-admin -n "$NAMESPACE" &>/dev/null; then
  echo "Missing Secret grafana-admin in namespace $NAMESPACE"
  echo "Run first:"
  echo "  $SCRIPT_DIR/create-grafana-secret.sh"
  exit 1
fi

echo "Updating Helm dependencies (may download charts)..."
helm dependency update

EXTRA=()
case "$MODE" in
  lab)
    EXTRA=(-f values.local.lab.yaml)
    echo "Mode: LAB (ingress off — use port-forward for Grafana)"
    ;;
  production|prod)
    if [[ ! -f values.local.yaml ]]; then
      echo "Missing values.local.yaml"
      echo "Copy and edit:"
      echo "  cp values.local.production.example.yaml values.local.yaml"
      echo "Replace YOUR_DOMAIN and YOUR_INGRESS_CLASS, then re-run."
      exit 1
    fi
    EXTRA=(-f values.local.yaml)
    echo "Mode: PRODUCTION (values.local.yaml)"
    ;;
  *)
    echo "Usage: $0 [lab|production]"
    exit 1
    ;;
esac

helm upgrade --install "$RELEASE" . -n "$NAMESPACE" --create-namespace \
  -f values.yaml "${EXTRA[@]}"

echo
echo "Done. Next:"
if [[ "$MODE" == "lab" ]]; then
  echo "  $SCRIPT_DIR/port-forward-ui.sh"
  echo "  Open http://localhost:3000  (user: admin, password: the one you set in create-grafana-secret.sh)"
else
  echo "  https://grafana.YOUR_DOMAIN  (after DNS + TLS are working)"
fi
echo "  kubectl get pods -n $NAMESPACE"
