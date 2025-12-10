#!/usr/bin/env bash
# setup-prometheus-trim-cron.sh — Setup daily crontab for prometheus-tsdb-trim.sh
# This script adds a daily cron job to run the Prometheus TSDB trim script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRIM_SCRIPT="${SCRIPT_DIR}/prometheus-tsdb-trim.sh"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/prometheus-trim.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Check if trim script exists
if [[ ! -f "$TRIM_SCRIPT" ]]; then
  echo "ERROR: Trim script not found at $TRIM_SCRIPT"
  exit 1
fi

# Make sure script is executable
chmod +x "$TRIM_SCRIPT"

# Create crontab entry (runs daily at 2:00 AM)
# Format: minute hour day month weekday command
CRON_TIME="0 2 * * *"
CRON_CMD="LOG_FILE=\"${LOG_FILE}\" ${TRIM_SCRIPT} >> \"${LOG_FILE}\" 2>&1"
CRON_ENTRY="${CRON_TIME} ${CRON_CMD}"

echo "Setting up daily cron job for Prometheus TSDB trim..."
echo "Script: $TRIM_SCRIPT"
echo "Log file: $LOG_FILE"
echo "Schedule: Daily at 2:00 AM"
echo ""
echo "Cron entry:"
echo "$CRON_ENTRY"
echo ""

# Check if entry already exists
if crontab -l 2>/dev/null | grep -qF "$TRIM_SCRIPT"; then
  echo "WARNING: A cron entry for this script already exists."
  echo "Current crontab:"
  crontab -l 2>/dev/null | grep -F "$TRIM_SCRIPT" || true
  echo ""
  read -p "Do you want to replace it? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
  # Remove old entry
  crontab -l 2>/dev/null | grep -vF "$TRIM_SCRIPT" | crontab -
fi

# Add new entry
(crontab -l 2>/dev/null || true; echo "$CRON_ENTRY") | crontab -

echo "✓ Cron job added successfully!"
echo ""
echo "To view your crontab: crontab -l"
echo "To remove this cron job: crontab -e (then delete the line)"
echo "To test the script manually: ${TRIM_SCRIPT}"


