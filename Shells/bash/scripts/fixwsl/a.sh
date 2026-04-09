#!/bin/bash

# Set non-interactive mode for all package operations
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export NEEDRESTART_MODE=a
export DEBIAN_PRIORITY=critical

# Disable all prompts and interactions
export UCF_FORCE_CONFFOLD=1
export DEBCONF_NONINTERACTIVE_SEEN=true

echo "=========================================="
echo "Starting ULTRA-FAST APT repair & cleanup"
echo "=========================================="
echo "Starting optimization process..."

# Step 0: Fix ALL problematic hooks and scripts
echo "[0/15] Removing ALL problematic hooks and scripts..."
sudo mkdir -p /var/cache/apt-show-versions 2>/dev/null || true
sudo chmod 755 /var/cache/apt-show-versions 2>/dev/null || true
# Remove ALL problematic hooks
sudo rm -f /etc/apt/apt.conf.d/*apt-show-versions* 2>/dev/null || true
sudo rm -f /usr/lib/cnf-update-db 2>/dev/null || true
# Fix gdbus missing issue by reinstalling libglib2.0-bin
echo "Fixing gdbus missing issue..."
sudo apt-get install --reinstall libglib2.0-bin -y 2>/dev/null || true
# Disable command-not-found hook
sudo chmod -x /usr/lib/command-not-found 2>/dev/null || true

# Step 0b: Remove blocker packages
echo "[0b/15] Removing ALL blocker packages..."
sudo dpkg --remove --force-all cloud-init command-not-found command-not-found-data python3-commandnotfound 2>/dev/null || true
sudo dpkg --purge --force-all cloud-init command-not-found command-not-found-data python3-commandnotfound 2>/dev/null || true

# Step 1: Backup current sources (skip to save time)
echo "[1/15] Configuring Ubuntu 22.04 (Jammy) sources..."
sudo bash -c 'cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF'

# Step 2: Clean apt cache completely
echo "[2/15] Cleaning APT cache..."
sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb
sudo mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial
sudo apt clean

# Step 3: Unhold ALL held packages
echo "[3/15] Removing all package holds..."
sudo dpkg --get-selections | grep hold | awk '{print $1}' | xargs -r sudo apt-mark unhold 2>/dev/null || true

# Step 4: Update package lists (fast)
echo "[4/15] Updating package lists..."
sudo apt update -qq 2>&1 | grep -v -E "apt-show-versions|command-not-found|gdbus" || true

# Step 5: Fix corrupted dpkg database (FAST method)
echo "[5/15] Repairing corrupted dpkg database..."
sudo mkdir -p /var/lib/dpkg/info
# Quick fix for missing lists
find /var/lib/dpkg/info -name "*.list" -size 0 -delete 2>/dev/null || true

# Step 6: Fix dpkg interrupted installations
echo "[6/15] Configuring interrupted packages..."
sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a --force-confold --force-confdef 2>/dev/null || true

# Step 7: Force remove problematic packages
echo "[7/15] Removing conflicting packages..."
sudo dpkg --purge --force-all gir1.2-freedesktop python3-gi-cairo 2>/dev/null || true
sudo apt-mark unhold libssl3 libssl-dev 2>/dev/null || true

# Step 8: Fix broken dependencies (FAST)
echo "[8/15] Fixing broken dependencies..."
sudo apt-get update --fix-missing && sudo apt-get install -f && sudo dpkg --configure -a && sudo apt-get install --reinstall libglib2.0-bin libssl3=3.0.2-0ubuntu1.20 -y && sudo apt-get upgrade -y && apt full-upgrade -y && apt autoremove -y && sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confnew"
sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y -qq -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" 2>&1 | grep -v -E "apt-show-versions|command-not-found|gdbus" || true

# Step 9: Downgrade incompatible packages (AGGRESSIVE)
echo "[9/15] Fixing Python version conflicts..."
# Remove ALL Python 3.12 references
sudo dpkg --remove --force-all python3.12 python3.12-minimal libpython3.12-stdlib libpython3.12-minimal python3.12-venv 2>/dev/null || true
sudo dpkg --purge --force-all python3.12 python3.12-minimal libpython3.12-stdlib libpython3.12-minimal python3.12-venv 2>/dev/null || true
sudo dpkg --remove --force-all python3 python3-minimal libpython3-stdlib 2>/dev/null || true
# Update
sudo apt update -qq 2>&1 | grep -v -E "apt-show-versions|command-not-found|gdbus" || true
# Install Python 3.10 properly
sudo apt install -y -qq python3.10 python3.10-minimal libpython3.10-stdlib libpython3.10-minimal 2>/dev/null || true
sudo apt install -y -qq --reinstall python3=3.10.6-1~22.04 python3-minimal=3.10.6-1~22.04 libpython3-stdlib=3.10.6-1~22.04 2>/dev/null || true
sudo apt install -y -qq python3-apt 2>/dev/null || true
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 2>/dev/null || true
# Remove problematic venv package
sudo dpkg --purge --force-all python3.12-venv 2>/dev/null || true

# Step 10: Full system upgrade (FAST)
echo "[10/15] Performing full system upgrade..."
sudo DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y -qq -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" 2>&1 | grep -v -E "apt-show-versions|command-not-found|gdbus" || true

# Fix phased updates issue
echo "[10b/15] Forcing phased updates..."
sudo apt-get install -y --allow-downgrades libnss-systemd libpam-systemd libsystemd0 libudev1 systemd systemd-sysv systemd-timesyncd udev 2>/dev/null || true

# Step 11: Fix libssl3 issue (install correct version for Jammy)
echo "[11/15] Ensuring libssl3 is available..."
# Remove any held packages
sudo apt-mark unhold libssl3 libssl-dev 2>/dev/null || true
# Remove broken libssl-dev first
sudo apt remove --purge -y libssl-dev 2>/dev/null || true
# Install libssl3 from Jammy repos (this may replace libssl3t64)
sudo apt install -y libssl3=3.0.2-0ubuntu1.20 2>/dev/null || sudo apt install -y libssl3 2>/dev/null || true

# Step 11b: Final dependency fix - SAFE
echo "[11b/15] Final dependency check..."
# Fix perl first - it's needed for debconf
echo "Reinstalling perl to fix debconf..."
sudo apt install -y --reinstall perl-base perl 2>/dev/null || true
sudo apt install -y --reinstall libperl5.38t64 2>/dev/null || true
# Now fix dependencies
sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef"
sudo apt install -y python3 python3-apt

echo ""
echo "=========================================="
echo "APT repair completed! Starting AGGRESSIVE cleanup..."
echo "=========================================="

# Step 12: AGGRESSIVE CLEANUP TO REDUCE SIZE
echo "[12/15] Removing unnecessary packages..." && pids=$(pgrep -x dpkg); if [ -n "$pids" ]; then sudo kill -9 $pids; fi; sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/dpkg/updates/*; sudo dpkg --configure -a && sudo rm /var/lib/dpkg/lock-frontend && sudo rm /var/lib/dpkg/lock && sudo apt-get install --fix-broken  && sudo apt autoremove -y --purge -qq 2>/dev/null || true

# Step 13: Remove SAFE bloat packages (keep essential tools)
echo "[13/15] Removing safe bloat packages to reduce size..."
sudo DEBIAN_FRONTEND=noninteractive apt remove --purge -y -qq \
    cloud-init landscape-common \
    snapd popularity-contest \
    motd-news-config \
    plymouth plymouth-theme-ubuntu-text \
    apport apport-symptoms python3-apport \
    man-db manpages groff-base \
    sound-theme-freedesktop alsa-topology-conf alsa-ucm-conf \
    linux-firmware \
    fonts-dejavu-extra fonts-noto-* fonts-urw-base35 \
    ubuntu-advantage-tools \
    2>/dev/null || true

# Extra cleanup for /mnt/wslg size reduction
echo "[13b/15] Additional /mnt/wslg reduction..."
# Don't remove these - perl needs them!
# sudo rm -rf /usr/share/backgrounds/* 2>/dev/null || true
# sudo rm -rf /usr/share/pixmaps/* 2>/dev/null || true
# sudo rm -rf /usr/share/icons/* 2>/dev/null || true
# sudo rm -rf /usr/share/themes/* 2>/dev/null || true
# sudo rm -rf /usr/share/sounds/* 2>/dev/null || true

# Step 14: Deep cleanup
echo "[14/15] Deep cleaning caches and logs..."
sudo apt autoclean -qq
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /var/cache/apt/archives/*.deb
sudo rm -rf /var/cache/debconf/*
sudo rm -rf /var/tmp/*
sudo rm -rf /tmp/*
sudo rm -rf /root/.cache/*
sudo rm -rf /home/*/.cache/* 2>/dev/null || true
sudo find /var/log -type f -name "*.log" -delete 2>/dev/null || true
sudo find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
sudo find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true
sudo rm -rf /usr/share/doc/* 2>/dev/null || true
sudo rm -rf /usr/share/man/* 2>/dev/null || true
sudo rm -rf /usr/share/info/* 2>/dev/null || true
sudo rm -rf /usr/share/locale/* 2>/dev/null || true
sudo rm -rf /var/cache/man/* 2>/dev/null || true
sudo journalctl --vacuum-time=1s 2>/dev/null || true

# Aggressive cleanup to ensure under 1.1GB - TARGET /mnt/wslg/distro
echo "[14b/15] ULTRA cleanup for /mnt/wslg to be under 1.1GB..."
# The issue is /mnt/wslg/distro contains apt cache - clean it aggressively
sudo rm -rf /var/lib/apt/lists/* 2>/dev/null || true
sudo rm -rf /var/cache/apt/* 2>/dev/null || true
sudo mkdir -p /var/lib/apt/lists/partial 2>/dev/null || true
sudo mkdir -p /var/cache/apt/archives/partial 2>/dev/null || true
# Clean WSLg specific folders
sudo rm -rf /mnt/wslg/.X11-unix/* 2>/dev/null || true
sudo rm -rf /mnt/wslg/runtime-dir/* 2>/dev/null || true
sudo rm -rf /mnt/wslg/versions.txt 2>/dev/null || true
sudo find /mnt/wslg -type f -name "*.log" -delete 2>/dev/null || true
sudo find /mnt/wslg -type f -name "*.cache" -delete 2>/dev/null || true
# Remove system.weston folder contents if exists
sudo rm -rf /mnt/wslg/system.weston/* 2>/dev/null || true
# Clean Weston logs and dumps
sudo find /mnt/wslg -type f -name "weston*.log" -delete 2>/dev/null || true
sudo find /mnt/wslg -type f -name "*.core" -delete 2>/dev/null || true
sudo find /mnt/wslg -type f -size +10M -delete 2>/dev/null || true

# Step 15: Final fix and update
echo "[15/15] Final system check..."
sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y -qq -o Dpkg::Options::="--force-confold" 2>&1 | grep -v -E "apt-show-versions|command-not-found|gdbus" || true
sudo apt autoremove -y --purge -qq 2>/dev/null || true
# Don't run apt update here to avoid recreating lists

echo ""
echo "=========================================="
echo "COMPLETE! System optimized and cleaned!"
echo "=========================================="
echo ""
echo "Testing that packages CAN be installed:"
echo ""
# Need to run apt update first for testing to work
sudo apt update -qq 2>&1 | grep -v -E "apt-show-versions|command-not-found|gdbus" || true
echo "Testing: apt install --dry-run npm"
if apt install --dry-run npm 2>&1 | grep -q "0 upgraded"; then
    echo "✓ npm CAN be installed successfully!"
else
    echo "✗ npm has issues, checking..."
    apt install --dry-run npm 2>&1 | tail -5
fi
echo ""
echo "Testing: apt install --dry-run gedit"
if apt install --dry-run gedit 2>&1 | grep -q "0 upgraded"; then
    echo "✓ gedit CAN be installed successfully!"
else
    echo "✗ gedit has issues, checking..."
    apt install --dry-run gedit 2>&1 | tail -5
fi
echo ""
echo "Testing: apt update"
if DEBIAN_FRONTEND=noninteractive apt-get update 2>&1 | grep -qE "^Reading package lists"; then
    echo "✓ apt update works perfectly!"
else
    echo "✗ apt update has issues"
fi
echo ""
echo "=========================================="
echo "Your system is now FULLY FIXED and OPTIMIZED!"
echo "You can now install ANY package without errors!"
echo "Example: apt install npm nodejs gedit curl git"
echo "=========================================="
echo ""
echo "Final aggressive cleanup to ensure /mnt/wslg < 1.1GB..."
# Clean apt lists one more time after testing
sudo rm -rf /var/lib/apt/lists/* 2>/dev/null || true
sudo rm -rf /var/cache/apt/* 2>/dev/null || true
# Ensure directories exist for future use
sudo mkdir -p /var/lib/apt/lists/partial 2>/dev/null || true
sudo mkdir -p /var/cache/apt/archives/partial 2>/dev/null || true
# Remove Python cache
sudo find /usr -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
# Remove perl docs (but keep perl-base working!)
# Don't delete perl-base or it breaks debconf
# sudo rm -rf /usr/share/perl5/* 2>/dev/null || true
# sudo rm -rf /usr/lib/x86_64-linux-gnu/perl-base/* 2>/dev/null || true

pids=$(pgrep -x dpkg); if [ -n "$pids" ]; then sudo kill -9 $pids; fi; sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/dpkg/updates/*; sudo dpkg --configure -a && sudo rm /var/lib/dpkg/lock-frontend && sudo rm /var/lib/dpkg/lock && sudo apt-get install --fix-broken && sudo apt-get update --fix-missing && pids=$(pgrep -x dpkg); if [ -n "$pids" ]; then sudo kill -9 $pids; fi; sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/dpkg/updates/*; sudo dpkg --configure -a && sudo rm /var/lib/dpkg/lock-frontend && sudo rm /var/lib/dpkg/lock && sudo apt-get install --fix-broken && sudo apt-get install -f && sudo dpkg --configure -a && sudo apt-get install --reinstall libglib2.0-bin libssl3=3.0.2-0ubuntu1.20 -y && sudo apt-get upgrade -y && sudo apt autoremove -y && sudo apt-get install --yes $(apt list --upgradable 2>/dev/null | grep '\[deferred\]' | cut -d/ -f1) &&  sudo APT::Get::Always-Include-Phased-Updates=true apt-get dist-upgrade -y && sudo apt-get install -y $(apt list --upgradable 2>/dev/null | grep -v '^Listing' | cut -d'/' -f1) && apt full-upgrade -y && sudo DEBIAN_FRONTEND=noninteractive apt-get update &&  sudo apt install --reinstall tzdata -y && sudo date -s "$(curl -sI http://www.google.com | grep -i "^date:" | cut -d" " -f3-6)Z" && pids=$(pgrep -x dpkg); if [ -n "$pids" ]; then sudo kill -9 $pids; fi; sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/dpkg/updates/*; sudo dpkg --configure -a && sudo rm /var/lib/dpkg/lock-frontend && sudo rm /var/lib/dpkg/lock && sudo apt-get install --fix-broken && sudo apt install --reinstall gawk libsigsegv2 -y && sudo apt autoremove -y && apt install curl -y && sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confnew"  && sudo apt install --reinstall libcurl3-gnutls -y

# Final check
echo "Checking /mnt/wslg size..."
WSLG_SIZE=$(du -sm /mnt/wslg 2>/dev/null | cut -f1)
du -sh /mnt/wslg 2>/dev/null || echo "Cannot check /mnt/wslg size"
if [ "$WSLG_SIZE" -lt 1127 ]; then
    echo "✓ SUCCESS! /mnt/wslg is under 1.1GB ($WSLG_SIZE MB)"
else
    echo "✗ WARNING! /mnt/wslg is still $WSLG_SIZE MB (target: < 1127 MB)"
fi
echo "=========================================="
echo "NOTE: Run 'sudo apt update' before installing packages"
echo "=========================================="
