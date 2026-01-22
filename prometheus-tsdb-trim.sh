#!/usr/bin/env bash
# prometheus-tsdb-guard.sh
#
# Safe diagnostics + guardrails for Prometheus TSDB (Docker).
# Designed for root's cron. Never fails silently.
#
# Default mode (DELETE_BLOCKS=0): diagnostics + WAL mitigation only.
#
# Tunables via env:
#   LOG_FILE=/var/log/prometheus-tsdb-guard.log
#   PROM_CONTAINER=master_prometheus
#   PROM_IMAGE=prom/prometheus:v3.5.0
#   KEEP_DAYS=7            (used only when DELETE_BLOCKS=1)
#   DELETE_BLOCKS=0        (0=diagnose only, 1=delete blocks older than KEEP_DAYS)
#   WAL_MAX_GB=10          (truncate WAL if >= this)
#   EMERGENCY_RESET=0      (0 disabled, 1 wipes TSDB if disk critical AND promtool fails)
#   DISK_CRIT_PERCENT=95
#   MOUNTPOINT=/

set -euo pipefail

LOG_FILE="${LOG_FILE:-/var/log/prometheus-tsdb-guard.log}"
PROM_CONTAINER="${PROM_CONTAINER:-master_prometheus}"
PROM_IMAGE="${PROM_IMAGE:-prom/prometheus:v3.5.0}"

KEEP_DAYS="${KEEP_DAYS:-7}"
DELETE_BLOCKS="${DELETE_BLOCKS:-0}"

WAL_MAX_GB="${WAL_MAX_GB:-10}"

EMERGENCY_RESET="${EMERGENCY_RESET:-0}"
DISK_CRIT_PERCENT="${DISK_CRIT_PERCENT:-95}"
MOUNTPOINT="${MOUNTPOINT:-/}"

ts() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] [prom-tsdb-guard] $*" | tee -a "$LOG_FILE"; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || { log "ERROR: missing command: $1"; exit 1; }; }

bytes_to_gib() { awk -v b="$1" 'BEGIN { printf "%.0f", b/1024/1024/1024 }'; }

get_used_pct() {
  local raw
  raw="$(df -P "${MOUNTPOINT}" | awk 'NR==2 {print $5}')"
  echo "${raw%%%}"
}

require_cmd df
require_cmd docker
require_cmd awk
require_cmd du
require_cmd sort
require_cmd head

log "===== START ====="
log "Disk usage:"
df -h | sed 's/^/  /' | tee -a "$LOG_FILE"

if docker system df >/dev/null 2>&1; then
  log "Docker system df:"
  docker system df | sed 's/^/  /' | tee -a "$LOG_FILE"
fi

if ! docker inspect "$PROM_CONTAINER" >/dev/null 2>&1; then
  log "ERROR: Prometheus container not found: $PROM_CONTAINER"
  docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' | sed 's/^/  /' | tee -a "$LOG_FILE"
  log "===== END ====="
  exit 1
fi

PROM_DIR="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/prometheus"}}{{.Source}}{{end}}{{end}}' "$PROM_CONTAINER" 2>/dev/null || true)"
if [[ -z "${PROM_DIR:-}" || ! -d "$PROM_DIR" ]]; then
  log "ERROR: Could not locate host mount for /prometheus. Found: '${PROM_DIR:-<empty>}'"
  log "Mounts:"
  docker inspect -f '{{range .Mounts}}{{println .Type .Source "->" .Destination}}{{end}}' "$PROM_CONTAINER" | sed 's/^/  /' | tee -a "$LOG_FILE"
  log "===== END ====="
  exit 1
fi

log "Prometheus TSDB host dir: $PROM_DIR"
log "Prometheus TSDB size:"
du -sh "$PROM_DIR" 2>/dev/null | sed 's/^/  /' | tee -a "$LOG_FILE"
du -sh "$PROM_DIR"/* 2>/dev/null | sort -hr | head -n 15 | sed 's/^/  /' | tee -a "$LOG_FILE" || true

# WAL mitigation
WAL_DIR="$PROM_DIR/wal"
if [[ -d "$WAL_DIR" ]]; then
  WAL_BYTES="$(du -sb "$WAL_DIR" 2>/dev/null | awk '{print $1}' || echo 0)"
  WAL_GIB="$(bytes_to_gib "$WAL_BYTES")"
  log "WAL size: ~${WAL_GIB} GiB (threshold: ${WAL_MAX_GB} GiB)"
  if (( WAL_GIB >= WAL_MAX_GB )); then
    log "WAL exceeds threshold. Stopping Prometheus and truncating WAL."
    docker stop "$PROM_CONTAINER" >/dev/null 2>&1 || true
    rm -rf "$WAL_DIR"/* 2>/dev/null || true
    docker start "$PROM_CONTAINER" >/dev/null 2>&1 || true
    log "WAL truncated."
  fi
fi

log "Listing TSDB blocks via promtool..."
set +e
PROMTOOL_OUT="$(docker run --rm -v "$PROM_DIR":/prom --entrypoint /bin/promtool "$PROM_IMAGE" tsdb list /prom 2>&1)"
rc=$?
set -e

if (( rc != 0 )) || [[ -z "${PROMTOOL_OUT:-}" ]]; then
  log "ERROR: promtool failed or returned no output (rc=$rc). Output follows:"
  echo "$PROMTOOL_OUT" | sed 's/^/  /' | tee -a "$LOG_FILE"
  USED_NOW="$(get_used_pct || echo 0)"
  log "Root usage now: ${USED_NOW}%"
  if [[ "$EMERGENCY_RESET" == "1" ]] && [[ "$USED_NOW" =~ ^[0-9]+$ ]] && (( USED_NOW >= DISK_CRIT_PERCENT )); then
    log "EMERGENCY_RESET enabled and disk critical. WIPING TSDB contents in $PROM_DIR"
    docker stop "$PROM_CONTAINER" >/dev/null 2>&1 || true
    rm -rf "$PROM_DIR"/* 2>/dev/null || true
    docker start "$PROM_CONTAINER" >/dev/null 2>&1 || true
    log "Emergency TSDB wipe done."
  else
    log "No destructive action taken (EMERGENCY_RESET=0 by default)."
  fi
  log "===== END (promtool failed) ====="
  exit 0
fi

# Log header + a sample
echo "$PROMTOOL_OUT" | head -n 1 | sed 's/^/  /' | tee -a "$LOG_FILE"
echo "$PROMTOOL_OUT" | tail -n +2 | head -n 10 | sed 's/^/  /' | tee -a "$LOG_FILE"

if [[ "$DELETE_BLOCKS" != "1" ]]; then
  log "DELETE_BLOCKS=0. Diagnostics + WAL mitigation only."
  log "===== END ====="
  exit 0
fi

# Compute cutoff epoch millis
CUTOFF_MS="$(awk -v days="$KEEP_DAYS" 'BEGIN { print int((systime() - (days*86400)) * 1000) }')"
log "Deleting blocks with MAX TIME < cutoff (KEEP_DAYS=${KEEP_DAYS}, cutoff_ms=${CUTOFF_MS})."

DELETE_ULIDS=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^BLOCK ]] && continue
  ulid="$(echo "$line" | awk '{print $1}')"
  max_ms="$(echo "$line" | awk '{print $3}')"
  [[ ! "$ulid" =~ ^01 ]] && continue
  [[ ! "$max_ms" =~ ^[0-9]+$ ]] && continue
  if (( max_ms < CUTOFF_MS )); then
    DELETE_ULIDS+=("$ulid")
  fi
done < <(echo "$PROMTOOL_OUT" | tail -n +2)

if (( ${#DELETE_ULIDS[@]} == 0 )); then
  log "No blocks older than ${KEEP_DAYS} days found. Nothing to delete."
  log "===== END ====="
  exit 0
fi

log "Blocks to delete (count=${#DELETE_ULIDS[@]}): ${DELETE_ULIDS[*]}"
log "Stopping Prometheus: $PROM_CONTAINER"
docker stop "$PROM_CONTAINER" >/dev/null 2>&1 || true

for u in "${DELETE_ULIDS[@]}"; do
  blk="$PROM_DIR/$u"
  if [[ -d "$blk" ]]; then
    sz="$(du -sh "$blk" 2>/dev/null | awk '{print $1}' || echo "N/A")"
    log "Deleting block $u (size=$sz)"
    rm -rf "$blk" 2>/dev/null || log "WARNING: Failed to delete $blk"
  fi
done

log "Starting Prometheus: $PROM_CONTAINER"
docker start "$PROM_CONTAINER" >/dev/null 2>&1 || true

log "Final TSDB size:"
du -sh "$PROM_DIR" 2>/dev/null | sed 's/^/  /' | tee -a "$LOG_FILE"

log "===== END ====="
