#!/usr/bin/env bash
# Prepare and start the VM Docker central stack (first time on a Linux host).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../vm-docker/central-stack" && pwd)"
cd "$ROOT"

echo "=== VM Docker central stack ==="
echo "Directory: $ROOT"
echo

if [[ ! -f docker-compose.yml ]]; then
  echo "docker-compose.yml not found."
  exit 1
fi

mkdir -p loki-data/wal
if [[ $(id -u) -eq 0 ]]; then
  chown -R 10001:10001 loki-data
else
  echo "If Loki fails to start, run: sudo chown -R 10001:10001 $ROOT/loki-data"
fi

echo "Review docker-compose.yml:"
echo "  - GF_SERVER_ROOT_URL (Grafana)"
echo "  - SMTP settings (or set GF_SMTP_ENABLED=false)"
echo
read -r -p "Press Enter to run: docker compose up -d (or Ctrl+C to edit first) ..."

docker compose up -d
echo
echo "Services starting. Check: docker compose ps"
echo "Grafana: http://localhost:3000 (default admin password on first login — change immediately)"
echo "Prometheus: http://localhost:9090"
echo "OTel OTLP HTTP: http://localhost:4318"
