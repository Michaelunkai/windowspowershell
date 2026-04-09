#!/bin/bash
# WSL2 Ultimate Cleanup Script
# Note: /mnt/wslg/distro is READ-ONLY, cannot be cleaned directly
# To reduce wslg size, disable WSLg in .wslconfig

# Clean main Ubuntu system
sudo apt autoremove -y 2>/dev/null || true
sudo apt autoclean -y 2>/dev/null || true
sudo apt clean -y 2>/dev/null || true
sudo rm -rf /var/cache/apt/archives/* /var/cache/apt/*.bin /var/lib/apt/lists/* 2>/dev/null || true
sudo rm -rf /var/cache/debconf/* /var/cache/fontconfig/* /var/cache/ldconfig/* /var/cache/man/* 2>/dev/null || true
sudo rm -rf /var/backups/* /var/crash/* /var/mail/* /var/spool/mail/* 2>/dev/null || true
sudo rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* /usr/share/locale/* 2>/dev/null || true
sudo rm -rf /usr/share/lintian/* /usr/share/linda/* /usr/share/gtk-doc/* /usr/share/help/* 2>/dev/null || true
sudo rm -rf /usr/share/icons/* /usr/share/pixmaps/* /usr/share/backgrounds/* /usr/share/wallpapers/* 2>/dev/null || true
sudo rm -rf /usr/share/themes/* /usr/share/sounds/* /usr/share/vim/*/doc/* 2>/dev/null || true
sudo rm -rf /tmp/* /var/tmp/* ~/.cache/* /root/.cache/* 2>/dev/null || true
sudo rm -rf /var/log/*.log /var/log/*.gz /var/log/*.[0-9] /var/log/*-[0-9]* 2>/dev/null || true
sudo journalctl --vacuum-size=1M 2>/dev/null || true
sudo rm -rf /var/log/journal/*/* 2>/dev/null || true
find /usr/lib -type f -name '*.pyc' -delete 2>/dev/null || true
find /usr/lib -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find /usr -type f -name '*.a' -delete 2>/dev/null || true
docker system prune -af --volumes 2>/dev/null || true
docker builder prune -af 2>/dev/null || true
# Truncate wslg logs
sudo truncate -s 0 /mnt/wslg/*.log 2>/dev/null || true
sudo rm -rf /mnt/wslg/doc/* 2>/dev/null || true
echo "Current /mnt/wslg size:"
du -sh /mnt/wslg
echo ""
echo "To reduce wslg further, create C:\\Users\\$USER\\.wslconfig with:"
echo "[wsl2]"
echo "guiApplications=false"
echo ""
echo "Then run: wsl --shutdown"
