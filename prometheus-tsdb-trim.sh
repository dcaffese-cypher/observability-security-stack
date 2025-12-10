#!/usr/bin/env bash
# prometheus-tsdb-trim.sh — Trim Prometheus TSDB blocks by DURATION (>20h)
# - Auto-detects Prometheus container and data mount
# - Deletes TSDB blocks whose DURATION is strictly > 20h
# - Prints diagnostics (df, Docker sizes, Prom volume size)
# - Optional DRY RUN: set DRY_RUN=1 (no deletions)
# - Optional LOG_FILE: set LOG_FILE=/path/to/log for file logging
# Requires: Docker, prom/prometheus image to supply promtool

set -euo pipefail

# --- Tunables ---
DURATION_HOURS_THRESHOLD="${DURATION_HOURS_THRESHOLD:-20}"   # delete blocks with DURATION > this (hours)
PROM_IMAGE="${PROM_IMAGE:-prom/prometheus:v3.5.0}"           # image to pull promtool from
DRY_RUN="${DRY_RUN:-0}"                                      # 1 = don't delete, just show
LOG_FILE="${LOG_FILE:-}"                                     # optional: log file path
LOG_PREFIX="[prom-tsdb-trim]"
PROM_CONTAINER="${PROM_CONTAINER:-}"                         # optional: force a container name (e.g., master_prometheus)

# --- Logging function ---
log() {
  local msg="$1"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $LOG_PREFIX $msg" | tee -a "${LOG_FILE:-/dev/null}"
}

# --- Convert duration string (e.g., "53h59m59.975s") to total hours (float) ---
duration_to_hours() {
  local dur="$1"
  
  # Use awk for more robust parsing (handles all formats)
  # Extract hours, minutes, and seconds, then convert to total hours
  awk -v dur="$dur" '
    BEGIN {
      hours = 0
      minutes = 0
      seconds = 0
      
      # Extract hours: match pattern like "53h" or "5h"
      if (match(dur, /([0-9]+)h/, arr)) {
        hours = arr[1]
      }
      
      # Extract minutes: match pattern like "59m" or "5m"
      if (match(dur, /([0-9]+)m/, arr)) {
        minutes = arr[1]
      }
      
      # Extract seconds: match pattern like "59.975s" or "5s"
      if (match(dur, /([0-9]+\.?[0-9]*)s/, arr)) {
        seconds = arr[1]
      }
      
      # Convert to total hours: hours + minutes/60 + seconds/3600
      printf "%.6f", hours + minutes/60 + seconds/3600
    }'
}

log "Starting trim. Threshold: > ${DURATION_HOURS_THRESHOLD}h  Dry-run: ${DRY_RUN}"

# --- Diagnostics (system + docker) ---
log "Disk usage (df -h):"
df -h | sed 's/^/  /'

log "Docker container sizes:"
docker ps -s --format 'table {{.Names}}\t{{.Size}}' | sed 's/^/  /'

log "Overlay UpperDir sizes per container:"
while read -r cid; do
  [[ -z "$cid" ]] && continue
  name="$(docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's#^/##' || echo "unknown")"
  upper="$(docker inspect -f '{{.GraphDriver.Data.UpperDir}}' "$cid" 2>/dev/null || echo "")"
  [[ -z "${upper:-}" ]] && upper="(none)"
  if [[ "$upper" != "(none)" ]] && [[ -d "$upper" ]]; then
    sz="$(sudo du -sh "$upper" 2>/dev/null | awk '{print $1}' || echo "N/A")"
    echo "  $name -> $upper    $sz"
  fi
done < <(docker ps -q 2>/dev/null || true)

# --- Find the Prometheus container if not provided ---
if [[ -z "${PROM_CONTAINER}" ]]; then
  # try by image
  if cid=$(docker ps --filter "ancestor=${PROM_IMAGE}" -q 2>/dev/null | head -n1) && [[ -n "$cid" ]]; then
    PROM_CONTAINER="$(docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's#^/##' || echo "")"
  fi
  
  # fallback: first container with 'prometheus' in name
  if [[ -z "${PROM_CONTAINER}" ]]; then
    PROM_CONTAINER="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -m1 -i prometheus || true)"
  fi
fi

if [[ -z "${PROM_CONTAINER}" ]]; then
  log "ERROR: Could not detect Prometheus container (set PROM_CONTAINER env)."
  exit 1
fi

log "Using Prometheus container: ${PROM_CONTAINER}"

# --- Find the Prometheus TSDB directory (host path) ---
# Prefer the mount with destination '/prometheus'; fallback to the largest mount containing 'prom'
PROM_DIR=""
if docker inspect "$PROM_CONTAINER" >/dev/null 2>&1; then
  # check mounts
  mapfile -t mounts < <(docker inspect -f '{{range .Mounts}}{{println .Source .Destination}}{{end}}' "$PROM_CONTAINER" 2>/dev/null || true)
  best_src=""
  for line in "${mounts[@]}"; do
    [[ -z "$line" ]] && continue
    src="$(awk '{print $1}' <<<"$line")"
    dst="$(awk '{print $2}' <<<"$line")"
    if [[ "$dst" == "/prometheus" ]]; then
      best_src="$src"
      break
    fi
    # fallback heuristic
    if [[ -z "$best_src" && "$dst" == *prom* ]]; then
      best_src="$src"
    fi
  done
  PROM_DIR="$best_src"
fi

# If still empty, try the known volume name on your host (common default)
if [[ -z "${PROM_DIR}" ]]; then
  # Try volume named like '<something>_prometheus-data'
  cand_vol="$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -m1 -E 'prometheus.*data|master_prometheus-data' || true)"
  if [[ -n "$cand_vol" ]]; then
    PROM_DIR="$(docker volume inspect "$cand_vol" -f '{{.Mountpoint}}' 2>/dev/null || echo "")"
  fi
fi

if [[ -z "${PROM_DIR}" || ! -d "${PROM_DIR}" ]]; then
  log "ERROR: Could not locate Prometheus TSDB mount on host."
  exit 1
fi

log "Prometheus TSDB dir: ${PROM_DIR}"
log "Prometheus TSDB size now:"
sudo du -sh "${PROM_DIR}" 2>/dev/null | sed 's/^/  /'
sudo du -sh "${PROM_DIR}"/* 2>/dev/null | sort -hr | head | sed 's/^/  /'

# --- List blocks with promtool (ULID, DURATION) ---
log "Listing TSDB blocks via promtool..."
PROMTOOL_OUT="$(docker run --rm -v "${PROM_DIR}":/prom --entrypoint /bin/promtool "${PROM_IMAGE}" tsdb list /prom 2>/dev/null || true)"

if [[ -z "${PROMTOOL_OUT}" ]]; then
  log "WARNING: promtool returned no output. Aborting cleanup."
  exit 0
fi

# Print header
echo "$PROMTOOL_OUT" | head -n1 | sed 's/^/  /'

# Parse candidate ULIDs where duration > threshold hours
# promtool columns: ULID  MIN  MAX  DURATION  ...
# Convert full duration (e.g., "53h59m59.975s") to total hours for accurate comparison
DELETE_ULIDS=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  # Skip header line
  [[ "$line" =~ ^BLOCK ]] && continue
  
  # Extract ULID (first column) and DURATION (4th column)
  ulid=$(echo "$line" | awk '{print $1}')
  duration=$(echo "$line" | awk '{print $4}')
  
  # Skip if ULID doesn't look valid (should start with 01)
  [[ ! "$ulid" =~ ^01 ]] && continue
  
  # Convert duration to total hours
  total_hours=$(duration_to_hours "$duration")
  
  # Compare with threshold (using awk for floating point comparison)
  if (( $(awk -v th="$total_hours" -v thr="${DURATION_HOURS_THRESHOLD}" 'BEGIN { print (th > thr) }') )); then
    DELETE_ULIDS+=("$ulid")
  fi
done < <(echo "$PROMTOOL_OUT" | tail -n +2)

if (( ${#DELETE_ULIDS[@]} == 0 )); then
  log "No blocks exceed ${DURATION_HOURS_THRESHOLD}h. Nothing to delete."
  exit 0
fi

log "Blocks to delete (> ${DURATION_HOURS_THRESHOLD}h):"
for u in "${DELETE_ULIDS[@]}"; do
  # Show line for each ULID
  echo "$PROMTOOL_OUT" | awk -v id="$u" 'NR==1 || $1==id' | sed 's/^/  /'
done

# --- Stop Prometheus, delete blocks, clean WAL if needed ---
CONTAINER_WAS_RUNNING=false
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${PROM_CONTAINER}$"; then
  CONTAINER_WAS_RUNNING=true
  log "Stopping container: ${PROM_CONTAINER}"
  docker stop "${PROM_CONTAINER}" >/dev/null 2>&1 || {
    log "WARNING: Failed to stop container. Continuing anyway..."
  }
fi

DELETE_COUNT=0
TOTAL_SIZE_FREED=0
for u in "${DELETE_ULIDS[@]}"; do
  blk="${PROM_DIR}/${u}"
  if [[ -d "$blk" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      block_size=$(sudo du -sh "$blk" 2>/dev/null | awk '{print $1}' || echo "unknown")
      log "DRY RUN: Would delete block $blk (size: $block_size)"
    else
      block_size=$(sudo du -sb "$blk" 2>/dev/null | awk '{print $1}' || echo "0")
      log "Deleting block $blk"
      if sudo rm -rf "$blk" 2>/dev/null; then
        ((DELETE_COUNT++))
        TOTAL_SIZE_FREED=$((TOTAL_SIZE_FREED + block_size))
      else
        log "WARNING: Failed to delete block $blk"
      fi
    fi
  else
    log "WARNING: Block directory not found: $blk"
  fi
done

# Clean WAL only if we actually deleted something (and not in DRY RUN)
if (( DELETE_COUNT > 0 )) && [[ "$DRY_RUN" != "1" ]]; then
  if [[ -d "${PROM_DIR}/wal" ]]; then
    log "Cleaning WAL..."
    sudo rm -rf "${PROM_DIR}/wal/"* 2>/dev/null || log "WARNING: Failed to clean WAL"
  fi
fi

# Restart container if it was running
if [[ "$CONTAINER_WAS_RUNNING" == "true" ]]; then
  log "Starting container: ${PROM_CONTAINER}"
  docker start "${PROM_CONTAINER}" >/dev/null 2>&1 || {
    log "ERROR: Failed to start container ${PROM_CONTAINER}"
    exit 1
  }
fi

if (( DELETE_COUNT > 0 )); then
  if [[ "$DRY_RUN" != "1" ]]; then
    # Convert bytes to human-readable format
    if command -v numfmt >/dev/null 2>&1; then
      size_freed_human=$(numfmt --to=iec-i --suffix=B "$TOTAL_SIZE_FREED" 2>/dev/null || echo "${TOTAL_SIZE_FREED} bytes")
    else
      # Fallback: use awk for conversion
      size_freed_human=$(awk -v bytes="$TOTAL_SIZE_FREED" '
        BEGIN {
          if (bytes >= 1099511627776) printf "%.2fTiB", bytes/1099511627776
          else if (bytes >= 1073741824) printf "%.2fGiB", bytes/1073741824
          else if (bytes >= 1048576) printf "%.2fMiB", bytes/1048576
          else if (bytes >= 1024) printf "%.2fKiB", bytes/1024
          else printf "%d bytes", bytes
        }')
    fi
    log "Deleted $DELETE_COUNT block(s), freed approximately $size_freed_human"
  fi
fi

log "Final TSDB size:"
sudo du -sh "${PROM_DIR}" 2>/dev/null | sed 's/^/  /'
sudo du -sh "${PROM_DIR}"/* 2>/dev/null | sort -hr | head | sed 's/^/  /'

log "Done."

