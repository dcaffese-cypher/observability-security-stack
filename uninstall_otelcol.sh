# 1. Stop and disable the service
sudo systemctl stop otelcol
sudo systemctl disable otelcol

# 2. Delete the systemd unit
sudo rm -f /etc/systemd/system/otelcol.service
sudo systemctl daemon-reload
sudo systemctl reset-failed

# 3. Delete installation and configuration directories
sudo rm -rf /opt/otelcol
sudo rm -rf /etc/otelcol

# 4. Delete the downloaded package if it is still there.
sudo rm -f /tmp/otelcol-contrib_*.tar.gz
