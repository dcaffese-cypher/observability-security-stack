#!/usr/bin/env bash
# Copy inventory template to a local file you can edit safely (gitignored).
set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../ansible/otel-agent" && pwd)"
SRC="$AGENT_DIR/inventory.ini"
DST="$AGENT_DIR/inventory.local.ini"

if [[ -f "$DST" ]]; then
  echo "Already exists: $DST"
  echo "Edit it and run:"
  echo "  ansible-playbook -i inventory.local.ini deploy_otel_agent.yml"
  exit 0
fi

cp "$SRC" "$DST"
echo "Created $DST"
echo "Edit that file: add your hosts under [agents], set master_otlp_http / master_otlp_grpc."
echo "Then:"
echo "  cd $AGENT_DIR"
echo "  ansible-playbook -i inventory.local.ini deploy_otel_agent.yml"
