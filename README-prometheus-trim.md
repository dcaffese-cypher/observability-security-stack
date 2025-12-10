# Prometheus TSDB Trim - Automated Block Management

Automated script to trim Prometheus TSDB blocks by duration, helping manage disk space by removing old data blocks. This tool intelligently identifies and removes TSDB blocks that exceed a specified duration threshold, preventing Prometheus from consuming excessive disk space.

## Overview

This script automatically detects and removes Prometheus TSDB blocks that exceed a specified duration threshold (default: 20 hours). It intelligently:

- Auto-detects the Prometheus container and data volume
- Lists all TSDB blocks with their durations
- Removes blocks exceeding the threshold
- Cleans the WAL (Write Ahead Log) after deletion
- Provides detailed diagnostics and logging

## Features

- **Intelligent Detection**: Automatically finds Prometheus container and data mount
- **Precise Duration Parsing**: Accurately parses duration strings (e.g., "53h59m59.975s") and converts to total hours
- **Safe Operation**: Only stops/restarts container if blocks need deletion
- **Dry Run Mode**: Test the script without making changes
- **Comprehensive Logging**: Optional file logging with timestamps
- **Disk Space Reporting**: Shows space freed after cleanup

## Requirements

- Docker
- `prom/prometheus:v3.5.0` image (or compatible version with promtool)
- Sudo access for file operations
- Bash 4.0+

## Usage

### Basic Usage

```bash
./prometheus-tsdb-trim.sh
```

### Dry Run (Test Mode)

Test what would be deleted without actually deleting:

```bash
DRY_RUN=1 ./prometheus-tsdb-trim.sh
```

### Custom Threshold

Change the duration threshold (in hours):

```bash
DURATION_HOURS_THRESHOLD=24 ./prometheus-tsdb-trim.sh
```

### With Logging

Enable file logging:

```bash
LOG_FILE=/var/log/prometheus-trim.log ./prometheus-tsdb-trim.sh
```

### Force Container Name

If auto-detection fails, specify the container:

```bash
PROM_CONTAINER=master_prometheus ./prometheus-tsdb-trim.sh
```

## Automated Daily Execution

### Quick Setup

Use the provided setup script:

```bash
./setup-prometheus-trim-cron.sh
```

This will:
- Create a logs directory
- Add a daily cron job (runs at 2:00 AM)
- Configure automatic logging

### Manual Crontab Setup

Add to your crontab:

```bash
0 2 * * * LOG_FILE="/path/to/logs/prometheus-trim.log" /path/to/prometheus-tsdb-trim.sh >> /path/to/logs/prometheus-trim.log 2>&1
```

View your crontab:
```bash
crontab -l
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DURATION_HOURS_THRESHOLD` | `20` | Delete blocks with duration > this (hours) |
| `PROM_IMAGE` | `prom/prometheus:v3.5.0` | Prometheus image for promtool |
| `DRY_RUN` | `0` | Set to `1` for dry run mode |
| `LOG_FILE` | (empty) | Optional log file path |
| `PROM_CONTAINER` | (auto-detect) | Force container name |

## How It Works

1. **Diagnostics**: Shows disk usage and Docker container sizes
2. **Container Detection**: Finds Prometheus container automatically
3. **Volume Detection**: Locates TSDB data directory
4. **Block Listing**: Uses `promtool` to list all TSDB blocks with durations
5. **Filtering**: Identifies blocks exceeding the threshold
6. **Cleanup**: Stops container, deletes blocks, cleans WAL, restarts container
7. **Reporting**: Shows final disk usage and space freed

## Example Output

```
[2024-01-15 02:00:00] [prom-tsdb-trim] Starting trim. Threshold: > 20h  Dry-run: 0
[2024-01-15 02:00:01] [prom-tsdb-trim] Using Prometheus container: master_prometheus
[2024-01-15 02:00:02] [prom-tsdb-trim] Prometheus TSDB dir: /var/lib/docker/volumes/master_prometheus-data/_data
[2024-01-15 02:00:03] [prom-tsdb-trim] Blocks to delete (> 20h):
  01K9752ZD2WQ3X54P20FQPF31R  1761264000195  1761530400000  73h59m59.805s  ...
[2024-01-15 02:00:04] [prom-tsdb-trim] Stopping container: master_prometheus
[2024-01-15 02:00:05] [prom-tsdb-trim] Deleting block /var/lib/docker/volumes/master_prometheus-data/_data/01K9752ZD2WQ3X54P20FQPF31R
[2024-01-15 02:00:10] [prom-tsdb-trim] Cleaning WAL...
[2024-01-15 02:00:11] [prom-tsdb-trim] Starting container: master_prometheus
[2024-01-15 02:00:12] [prom-tsdb-trim] Deleted 3 block(s), freed approximately 8.5GiB
[2024-01-15 02:00:13] [prom-tsdb-trim] Done.
```

## Safety Features

- Only stops container if blocks need deletion
- Verifies container was running before stopping
- Validates block directories before deletion
- Comprehensive error handling
- Dry run mode for testing

## Troubleshooting

### Container Not Found

If the script can't find the Prometheus container:

```bash
PROM_CONTAINER=your_container_name ./prometheus-tsdb-trim.sh
```

### Permission Denied

Ensure you have sudo access for file operations:

```bash
sudo -v  # Verify sudo access
```

### promtool Not Available

The script uses Docker to run promtool. Ensure the Prometheus image is available:

```bash
docker pull prom/prometheus:v3.5.0
```

## Files

- `prometheus-tsdb-trim.sh` - Main trim script
- `setup-prometheus-trim-cron.sh` - Cron setup helper
- `logs/prometheus-trim.log` - Log file (created automatically)

## 🔒 Security & Safety

- **Safe Operation**: Only stops container if blocks need deletion
- **Verification**: Validates block directories before deletion
- **Dry Run Mode**: Test without making changes
- **Comprehensive Logging**: All operations are logged for audit

## 📝 License

This script is provided as-is for operational use.

---

**Note:** This script modifies Prometheus data. Always test in a non-production environment first and ensure you have backups.


