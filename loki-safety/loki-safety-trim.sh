#!/usr/bin/env bash
# loki-safety-trim.sh — Emergency Loki reset when root filesystem is >= 95% used
# Trigger: root filesystem (/dev/sda4 mounted on /) usage >= THRESHOLD_PERCENT
#
# This script intentionally performs ONLY:
# - df -h (for visibility)
# - docker stop master_loki
# - rm -rf loki-data directories/files (as provided)
# - docker start master_loki
#
# Default threshold: 95%
# Override with: THRESHOLD_PERCENT=97 /usr/local/sbin/loki-safety-trim.sh

set -euo pipefail

THRESHOLD_PERCENT="${THRESHOLD_PERCENT:-95}"
DEVICE="${DEVICE:-/dev/sda4}"
MOUNTPOINT="${MOUNTPOINT:-/}"
LOKI_CONTAINER="${LOKI_CONTAINER:-master_loki}"
LOKI_DATA_DIR="${LOKI_DATA_DIR:-/opt/observability/master/loki-data}"

ts() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "$(ts) [loki-safety-trim] $*"; }

log "Checking disk usage for ${DEVICE} mounted on ${MOUNTPOINT} (threshold: ${THRESHOLD_PERCENT}%)"

# Current usage percentage for the mountpoint (e.g., "100%")
USED_PCT_RAW="$(df -P "${MOUNTPOINT}" | awk 'NR==2 {print $5}')"
USED_PCT="${USED_PCT_RAW%%%}"  # strip '%'

if [[ -z "${USED_PCT:-}" || ! "${USED_PCT}" =~ ^[0-9]+$ ]]; then
  log "ERROR: Could not parse disk usage from df output. Raw: '${USED_PCT_RAW}'"
  exit 1
fi

log "Current root usage: ${USED_PCT}%"
if (( USED_PCT < THRESHOLD_PERCENT )); then
  log "Below threshold. No action taken."
  exit 0
fi

log "Threshold reached/exceeded. Running emergency Loki cleanup commands."

# 1) Print df -h (as requested)
df -h

# 2) Stop Loki
log "Stopping container: ${LOKI_CONTAINER}"
docker stop "${LOKI_CONTAINER}"

# 3) Delete Loki data (exact commands you provided)
log "Deleting Loki data under: ${LOKI_DATA_DIR}"

sudo rm -rf "${LOKI_DATA_DIR}/chunks"
sudo rm -rf "${LOKI_DATA_DIR}/index"
sudo rm -rf "${LOKI_DATA_DIR}/tsdb-cache"
sudo rm -rf "${LOKI_DATA_DIR}/tsdb-index"
sudo rm -rf "${LOKI_DATA_DIR}/compactor"
sudo rm -rf "${LOKI_DATA_DIR}/tsdb-compactor"*
sudo rm -rf "${LOKI_DATA_DIR}/"*

# 4) Start Loki
log "Starting container: ${LOKI_CONTAINER}"
docker start "${LOKI_CONTAINER}"

log "Emergency cleanup completed."
