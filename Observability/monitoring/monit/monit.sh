#!/bin/bash
# Monit Auto Disk Cleanup - One-liner installer for Ubuntu/WSL2
# Monitors disk every 5 seconds, auto-cleans at 70%/85% thresholds

set -e

echo ">>> Installing monit..."
sudo apt-get update -qq && sudo apt-get install -y monit

echo ">>> Creating monit configuration..."
sudo tee /etc/monit/conf.d/disk.conf > /dev/null << 'MONITCONF'
set daemon 5
set log /var/log/monit.log
set httpd port 2812 and
    use address 0.0.0.0
    allow 0.0.0.0/0

check filesystem rootfs with path /
    if space usage > 70% then exec "/opt/disk-cleanup.sh"
    if space usage > 85% then exec "/opt/disk-emergency.sh"
MONITCONF

echo ">>> Creating cleanup script..."
sudo tee /opt/disk-cleanup.sh > /dev/null << 'CLEANUP'
#!/bin/bash
docker system prune -af 2>/dev/null
truncate -s 0 /var/lib/docker/volumes/monitoring_prometheus-data/_data/query.log 2>/dev/null
journalctl --vacuum-size=100M 2>/dev/null
find /var/log -type f -name "*.log" -size +50M -exec truncate -s 0 {} \; 2>/dev/null
apt-get clean 2>/dev/null
CLEANUP

echo ">>> Creating emergency cleanup script..."
sudo tee /opt/disk-emergency.sh > /dev/null << 'EMERGENCY'
#!/bin/bash
docker system prune -af --volumes 2>/dev/null
journalctl --vacuum-size=50M 2>/dev/null
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null
find /var/log -type f -name "*.gz" -delete 2>/dev/null
find /tmp -type f -mtime +1 -delete 2>/dev/null
apt-get clean 2>/dev/null
EMERGENCY

echo ">>> Setting permissions..."
sudo chmod +x /opt/disk-cleanup.sh /opt/disk-emergency.sh

echo ">>> Validating monit configuration..."
sudo monit -t

echo ">>> Restarting monit..."
sudo systemctl restart monit
sudo systemctl enable monit

echo ">>> Waiting for monit to start..."
sleep 2

echo ">>> Monit status:"
sudo monit status

WSL_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================"
echo "MONIT INSTALLED - Disk auto-cleanup active"
echo "  - Check interval: 5 seconds"
echo "  - 70% threshold: standard cleanup"
echo "  - 85% threshold: emergency cleanup"
echo "  - Web UI (WSL):     http://localhost:2812"
echo "  - Web UI (Windows): http://${WSL_IP}:2812"
echo "============================================"
