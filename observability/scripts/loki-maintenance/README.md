# Loki Safety Trim - Emergency Disk Space Protection

An automated safety mechanism to prevent Loki from filling up disk space and crashing your observability stack. This tool monitors Loki's data directory and automatically deletes old data when disk usage exceeds a configurable threshold.

## 🎯 Overview

Loki Safety Trim is an emergency guardrail that:

- **Monitors** Loki data directory size continuously
- **Deletes** old data when it exceeds a threshold (default: 80 GB)
- **Restarts** Loki automatically to continue operation
- **Prevents** disk space exhaustion that could crash your server
- **Runs** via cron job for automated protection

**⚠️ Important:** This script will **delete Loki log history** when triggered, but it protects your server from going 100% full and breaking everything.

## 🚀 Quick Start

### 1. Install the Script

Copy the script to your system:

```bash
sudo cp loki-safety-trim.sh /usr/local/sbin/loki-safety-trim.sh
sudo chmod +x /usr/local/sbin/loki-safety-trim.sh
```

### 2. Configure Settings

Edit the script to match your environment:

```bash
sudo nano /usr/local/sbin/loki-safety-trim.sh
```

Update these variables:

```bash
THRESHOLD_GB=80                    # Disk usage threshold in GB
LOKI_CONTAINER="YOUR_LOKI_CONTAINER_NAME"       # Replace with your Loki container name
LOKI_DATA_DIR="/path/to/loki-data"  # Replace with your Loki data directory path
LOKI_USER="10001"                  # Replace with your Loki user UID (default: 10001)
LOKI_GROUP="10001"                 # Replace with your Loki group GID (default: 10001)
```

### 3. Configure Daily Cron Job

Set up automatic daily execution:

```bash
sudo tee /etc/cron.d/loki-safety-trim >/dev/null <<'EOF'
# Emergency Loki disk guard — runs daily at 03:10
10 3 * * * root /usr/local/sbin/loki-safety-trim.sh >> /var/log/loki-safety-trim.log 2>&1
EOF

sudo chmod 644 /etc/cron.d/loki-safety-trim
sudo systemctl restart crond 2>/dev/null || sudo systemctl restart cron 2>/dev/null || true
```

### 4. Configure Loki Retention (Recommended)

To prevent this from happening frequently, configure retention in your `loki-config.yml`:

```yaml
compactor:
  working_directory: /loki/compactor
  shared_store: filesystem
  retention_enabled: true

limits_config:
  retention_period: 168h   # 7 days, adjust as needed
```

## 📋 How It Works

### Step-by-Step Process

1. **Size Check**: Script checks the size of Loki's data directory
2. **Threshold Comparison**: Compares current size against threshold (default: 80 GB)
3. **Emergency Action**: If threshold exceeded:
   - Stops Loki container gracefully
   - Deletes all data in the Loki data directory
   - Creates a fresh empty directory with correct permissions
   - Restarts Loki container
4. **Verification**: Confirms final size and logs the operation

### Execution Flow

```
Start → Check Permissions → Get Data Size
                              ↓
                    Size > Threshold?
                    /              \
                  Yes               No
                  ↓                 ↓
          Stop Container    Log Success & Exit
                  ↓
          Delete Data Directory
                  ↓
          Create Fresh Directory
                  ↓
          Start Container
                  ↓
          Verify & Log Results
```

## ⚙️ Configuration

### Environment Variables

You can override default values by editing the script variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `THRESHOLD_GB` | `80` | Disk usage threshold in GB |
| `LOKI_CONTAINER` | `YOUR_LOKI_CONTAINER_NAME` | Docker container name for Loki (replace with your container name) |
| `LOKI_DATA_DIR` | `/path/to/loki-data` | Path to Loki data directory (replace with your actual path) |
| `LOKI_USER` | `10001` | Loki user UID (replace if different) |
| `LOKI_GROUP` | `10001` | Loki group GID (replace if different) |

### Custom Configuration

For different paths or thresholds, edit the script:

```bash
sudo nano /usr/local/sbin/loki-safety-trim.sh
```

Update the configuration section at the top of the file.

## 🔍 Monitoring

### View Logs

```bash
# View recent execution logs
tail -f /var/log/loki-safety-trim.log

# View all logs
cat /var/log/loki-safety-trim.log
```

### Manual Execution

Run the script manually to test:

```bash
# Run with default settings
sudo /usr/local/sbin/loki-safety-trim.sh

# Check current size without taking action
# Replace /path/to/loki-data with your actual Loki data directory path
sudo du -sh /path/to/loki-data
```

### Check Cron Job

Verify the cron job is configured:

```bash
# View cron job
cat /etc/cron.d/loki-safety-trim

# Check cron service status
systemctl status cron
# or
systemctl status crond
```

## 🛠️ Troubleshooting

### Script Not Running

```bash
# Check script exists and is executable
ls -l /usr/local/sbin/loki-safety-trim.sh

# Check cron service
systemctl status cron

# Check cron logs
grep loki-safety /var/log/cron
```

### Permission Issues

```bash
# Ensure script is executable
sudo chmod +x /usr/local/sbin/loki-safety-trim.sh

# Check Docker access
docker ps | grep loki
# or
sudo docker ps | grep loki
```

### Container Not Found

If Loki container name is different:

```bash
# List running containers
docker ps

# Update LOKI_CONTAINER variable in script
sudo nano /usr/local/sbin/loki-safety-trim.sh
```

### Directory Not Found

If Loki data directory is in a different location:

```bash
# Find Loki data directory
# Replace YOUR_LOKI_CONTAINER_NAME with your actual container name
docker inspect YOUR_LOKI_CONTAINER_NAME | grep -A 10 Mounts

# Update LOKI_DATA_DIR variable in script
sudo nano /usr/local/sbin/loki-safety-trim.sh
```

### Container Won't Start After Rotation

```bash
# Check Docker logs
# Replace YOUR_LOKI_CONTAINER_NAME with your actual container name
docker logs YOUR_LOKI_CONTAINER_NAME

# Check container status
docker ps -a | grep loki

# Manually start container
# Replace YOUR_LOKI_CONTAINER_NAME with your actual container name
docker start YOUR_LOKI_CONTAINER_NAME
```

## ⚠️ Important Considerations

### Data Loss

**This script will delete Loki log history when triggered.** This is intentional to prevent disk space issues, but means:

- Historical logs will be permanently lost
- You should configure proper retention in Loki config
- Consider this a last-resort safety mechanism

### Best Practices

1. **Configure Retention**: Set `retention_period` in `loki-config.yml` to prevent data growth
2. **Monitor Disk Usage**: Set up alerts for disk usage before it reaches the threshold
3. **Regular Monitoring**: Check logs regularly to ensure the script is working
4. **Backup Important Logs**: If you need long-term log retention, implement a backup strategy

### Alternative: Proactive Monitoring

Instead of relying solely on this emergency script, consider:

- Setting up Prometheus alerts for disk usage
- Configuring Loki retention policies
- Implementing log rotation at the source
- Using external storage (S3, GCS) for long-term retention

## 📊 Example Output

### Normal Operation (Below Threshold)

```
2024-01-15 03:10:00 [loki-safety-trim] Starting Loki safety trim. Threshold: 80 GB
2024-01-15 03:10:01 [loki-safety-trim] Loki container: YOUR_LOKI_CONTAINER_NAME
2024-01-15 03:10:01 [loki-safety-trim] Loki data dir : /path/to/loki-data
2024-01-15 03:10:02 [loki-safety-trim] Current Loki data size: 45.2 GB
2024-01-15 03:10:02 [loki-safety-trim] Size 45.2 GB is within threshold 80 GB. No action needed.
```

### Emergency Rotation (Above Threshold)

```
2024-01-15 03:10:00 [loki-safety-trim] Starting Loki safety trim. Threshold: 80 GB
2024-01-15 03:10:01 [loki-safety-trim] Loki container: YOUR_LOKI_CONTAINER_NAME
2024-01-15 03:10:01 [loki-safety-trim] Loki data dir : /path/to/loki-data
2024-01-15 03:10:02 [loki-safety-trim] Current Loki data size: 95.8 GB
2024-01-15 03:10:02 [loki-safety-trim] WARNING: Size 95.8 GB exceeds threshold 80 GB — performing emergency rotation.
2024-01-15 03:10:03 [loki-safety-trim] Stopping Loki container: YOUR_LOKI_CONTAINER_NAME
2024-01-15 03:10:05 [loki-safety-trim] Loki container stopped successfully
2024-01-15 03:10:05 [loki-safety-trim] Deleting Loki data directory: /path/to/loki-data
2024-01-15 03:10:12 [loki-safety-trim] Loki data directory deleted
2024-01-15 03:10:12 [loki-safety-trim] Creating fresh Loki data dir: /path/to/loki-data with owner 10001:10001
2024-01-15 03:10:12 [loki-safety-trim] Fresh Loki data directory created
2024-01-15 03:10:13 [loki-safety-trim] Starting Loki container: YOUR_LOKI_CONTAINER_NAME
2024-01-15 03:10:16 [loki-safety-trim] Loki container started successfully
2024-01-15 03:10:16 [loki-safety-trim] Final Loki data size: 0.0 GB (should be near 0).
2024-01-15 03:10:16 [loki-safety-trim] Rotation complete. Old data has been deleted.
```

## 🔐 Security Considerations

- **Permissions**: Script requires root, docker group membership, or sudo access
- **Logging**: All operations are logged for audit purposes
- **Safety**: Script includes error handling and verification steps
- **Non-Destructive**: Only deletes when threshold is exceeded

## 📝 License

This script is provided as-is for operational use.

---

**Note:** This is an emergency safety mechanism. For production environments, implement proper retention policies and monitoring to prevent the need for this script to trigger.

