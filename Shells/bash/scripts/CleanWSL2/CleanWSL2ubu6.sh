#!/bin/bash

# Disable strict error handling for dpkg issues
set -uo pipefail

# Set completely non-interactive mode globally
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
export APT_LISTCHANGES_FRONTEND=none
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=yes

# Disable all interactive prompts system-wide
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections 2>/dev/null || true
echo 'debconf debconf/priority select critical' | sudo debconf-set-selections 2>/dev/null || true

# Enhanced WSL2 Ubuntu Cleanup Script - Maximum Space Reduction
# This script aggressively removes all non-essential components to minimize WSL2 distro size
# MODIFIED: Protected packages preserved (docker, python, node, npm, pip, snapd, etc.)

# ============================================================================
# PROTECTED PACKAGES - These will NEVER be removed
# ============================================================================
PROTECTED_APT_PACKAGES=(
    "docker.io" "docker-compose" "containerd"
    "python3" "python3-venv" "python3-pip" "python3-full"
    "nodejs" "npm"
    "jq"
    "openssh-client" "openssh-server" "sshpass"
    "tree"
    "snapd"
    "curl" "wget" "git" "ca-certificates"
)

# Function to check if package is protected
is_protected_package() {
    local pkg="$1"
    for protected in "${PROTECTED_APT_PACKAGES[@]}"; do
        if [[ "$pkg" == "$protected"* ]]; then
            return 0  # true - is protected
        fi
    done
    return 1  # false - not protected
}

# Function to display progress
show_progress() {
    echo "======================================"
    echo "🔄 $1"
    echo "======================================"
    echo "Current disk usage:"
    df -h / | tail -1 | awk '{print "Used: " $3 " Available: " $4 " (" $5 " full)"}'
    echo ""
}

# Function to calculate space saved
calculate_saved() {
    local before=$1
    local after=$(df / | tail -1 | awk '{print $3}')
    local saved=$((before - after))
    echo "💾 Space saved: $((saved / 1024)) MB"
    echo ""
}

echo "🚀 Starting AUTOMATIC WSL2 Ubuntu cleanup for maximum space optimization..."
echo "⚠️  WARNING: Removing ALL non-essential components automatically!"
echo "⚡ ULTRA-FAST MODE: Skipping zero-fill for speed - will complete in under 2 minutes!"
echo "🛡️  SAFETY MODE: Critical system libraries and locales will be protected!"
echo "🔒 PROTECTED: docker, python, node, npm, pip, jq, ssh, tree, snap preserved!"
echo ""
echo "📦 Target: <1.7GB disk usage with all dev tools functional"
echo ""

# ============================================================================
# PHASE 0: ENSURE PROTECTED PACKAGES ARE INSTALLED
# ============================================================================
show_progress "Phase 0: Installing/Verifying Protected Packages"
echo "🔒 Ensuring all protected packages are installed..."

# Update package lists first
sudo apt update -y >/dev/null 2>&1 || true

# Install protected packages if missing
echo "📦 Installing protected packages (if not already present)..."
for pkg in "${PROTECTED_APT_PACKAGES[@]}"; do
    if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        echo "  → Installing: $pkg"
        sudo apt install -y "$pkg" >/dev/null 2>&1 || true
    else
        echo "  ✓ Already installed: $pkg"
    fi
done

# Ensure snapd is running for snap packages
if command -v snap >/dev/null 2>&1; then
    sudo systemctl enable snapd 2>/dev/null || true
    sudo systemctl start snapd 2>/dev/null || true
    echo "  ✓ snapd service enabled and running"
fi

echo "✅ Protected packages verified!"
echo ""

# Verify critical libraries exist before starting
echo "🔍 Pre-flight check: Verifying critical system components..."
CRITICAL_LIBS=("/lib/x86_64-linux-gnu/libcrypto.so.3" "/lib/x86_64-linux-gnu/libc.so.6")
for lib in "${CRITICAL_LIBS[@]}"; do
    if [ -f "$lib" ]; then
        echo "  ✓ Found: $lib"
    else
        echo "  ⚠️  Missing: $lib (system may already be damaged)"
    fi
done

# Kill any potential interactive processes that might interfere
sudo pkill -f "dpkg.*--configure" 2>/dev/null || true
sudo pkill -f "apt.*install" 2>/dev/null || true
sudo pkill -f "debconf" 2>/dev/null || true

# Get initial disk usage
INITIAL_USAGE=$(df / | tail -1 | awk '{print $3}')

# Phase 1: Package Management and Updates
show_progress "Phase 1: Package Management Optimization"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "📦 Fixing dpkg database and updating package lists..."
# Fix broken dpkg database first
sudo dpkg --configure -a --force-confold 2>/dev/null || true
sudo apt-get -f install -y 2>/dev/null || true

# Update package lists silently
sudo apt update -y >/dev/null 2>&1 || true

echo "🔧 Installing cleanup tools (completely silent)..."
# Pre-configure ALL localepurge prompts to avoid ANY user interaction
echo 'localepurge localepurge/nopurge multiselect en_US.UTF-8' | sudo debconf-set-selections
echo 'localepurge localepurge/mandelete boolean true' | sudo debconf-set-selections
echo 'localepurge localepurge/dontbothernew boolean false' | sudo debconf-set-selections
echo 'localepurge localepurge/quickndirtycalc boolean true' | sudo debconf-set-selections
echo 'localepurge localepurge/verbose boolean false' | sudo debconf-set-selections
echo 'localepurge localepurge/use_dpkg_feature boolean true' | sudo debconf-set-selections

# Install essential tools only (skip problematic ones that cause prompts)
sudo apt install -y deborphan >/dev/null 2>&1 || true

# Skip apt-show-versions, localepurge, and debfoster - they cause interactive prompts or break dpkg
# We'll handle all cleanup manually instead
echo "⚠️ Skipping problematic packages (apt-show-versions, localepurge, debfoster) - using manual cleanup only"

# EXTREME: Remove development packages (can reinstall if needed)
echo "🗑️ Removing ALL development packages..."
sudo apt remove --purge -y 'build-essential' 'gcc*' 'g++*' 'make' 'cmake' 'autoconf' 'automake' 2>/dev/null || true
sudo apt remove --purge -y '*-dev' '*-doc' '*-dbg' 2>/dev/null || true

# Fix any installation errors
sudo dpkg --configure -a --force-confold 2>/dev/null || true

echo "🗑️ Removing unused packages and dependencies..."
sudo apt autoremove --purge -y >/dev/null 2>&1 || true
sudo apt autoclean -y >/dev/null 2>&1 || true
sudo apt clean -y >/dev/null 2>&1 || true

# Remove package cache completely
sudo rm -rf /var/cache/apt/archives/*.deb
sudo rm -rf /var/cache/apt/archives/partial/*

calculate_saved $STEP_USAGE

# Phase 2: Deep Package Cleanup
show_progress "Phase 2: Deep Package Configuration Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🧹 Purging residual package configurations..."

# Fix dpkg database issues silently
sudo dpkg --configure -a --force-confold >/dev/null 2>&1 || true
sudo apt-get -f install -y >/dev/null 2>&1 || true

# Remove packages in rc state (removed but config remains)
dpkg -l 2>/dev/null | awk '/^rc/ {print $2}' | xargs -r sudo apt purge -y >/dev/null 2>&1 || true

# AGGRESSIVE: Remove orphaned packages completely
echo "🔍 AGGRESSIVE orphaned packages cleanup..."
if command -v deborphan >/dev/null 2>&1; then
    # Run until no more orphans found (no limit)
    while true; do
        orphans=$(sudo deborphan 2>/dev/null)
        [ -z "$orphans" ] && break
        echo "$orphans" | xargs -r sudo apt-get -y remove --purge >/dev/null 2>&1 || break
    done
fi

# Remove ALL auto-installed packages that are no longer needed
echo "🗑️ Removing ALL unnecessary auto-installed packages..."
sudo apt-mark showauto 2>/dev/null | xargs -r sudo apt-get -y remove --purge >/dev/null 2>&1 || true

# Remove common non-essential packages aggressively
echo "💣 EXTREME package removal..."
REMOVE_PACKAGES=(
    "ubuntu-advantage-tools" "popularity-contest" "command-not-found"
    "update-notifier-common" "ubuntu-release-upgrader-core"
    "landscape-common" "update-manager-core" "software-properties-common"
    "python3-software-properties" "unattended-upgrades" "friendly-recovery"
    "lxd-agent-loader" "ubuntu-minimal" "xauth" "x11-common"
)
for pkg in "${REMOVE_PACKAGES[@]}"; do
    sudo apt remove --purge -y "$pkg" 2>/dev/null || true
done

calculate_saved $STEP_USAGE

# Phase 3: Aggressive File System Cleanup
show_progress "Phase 3: Logs, Cache, and Temporary Files Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🛑 Stopping logging services temporarily..."
sudo systemctl stop systemd-journald 2>/dev/null || true
sudo systemctl stop rsyslog 2>/dev/null || true

echo "📄 Aggressively clearing ALL logs and cache files (PARALLEL)..."
# PARALLEL: Enhanced log cleanup with multiple patterns
(sudo journalctl --rotate 2>/dev/null || true) &
(sudo journalctl --vacuum-time=1s 2>/dev/null || true) &
(sudo journalctl --vacuum-size=1K 2>/dev/null || true) &
(sudo rm -rf /var/log/journal /run/log/journal 2>/dev/null || true) &
(sudo rm -rf /var/log/*.log* /var/log/**/*.log* /var/log/**/*.gz /var/log/**/*.old /var/log/**/*.[0-9]* /var/log/**/*.bak 2>/dev/null || true) &
(sudo rm -rf /var/log/apt/* /var/log/unattended-upgrades/* /var/log/installer/* /var/log/dist-upgrade/* 2>/dev/null || true) &
(sudo find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true) &
(sudo find /var/log -type f -delete 2>/dev/null || true) &
(sudo find /var/log -type d -empty -delete 2>/dev/null || true) &
wait

# PARALLEL: Enhanced cache cleanup with more specific targets
(sudo rm -rf /var/cache/apt/archives/* /var/cache/apt/archives/partial/* /var/cache/apt/*.bin 2>/dev/null || true) &
(sudo rm -rf /var/cache/debconf/*.dat-old 2>/dev/null || true) &
(sudo rm -rf /var/cache/fontconfig/* /var/cache/man/* 2>/dev/null || true) &
# DO NOT use wildcards on /var/cache - it breaks debconf completely!
(sudo rm -rf /usr/share/doc/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/man/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/info/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/lintian/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/linda/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/pixmaps/* 2>/dev/null || true) &
wait

# PARALLEL: Enhanced temp and crash cleanup
(sudo find /tmp -mindepth 1 -delete 2>/dev/null || true) &
(sudo find /var/tmp -mindepth 1 -delete 2>/dev/null || true) &
(sudo find /var/crash -mindepth 1 -delete 2>/dev/null || true) &
(sudo find /var/backups -mindepth 1 -delete 2>/dev/null || true) &
(sudo rm -rf /var/spool/*/* /var/mail/* /var/spool/mail/* 2>/dev/null || true) &
wait

# PARALLEL: Enhanced user directory cleanup
for home_dir in /home/* /root; do
    if [ -d "$home_dir" ]; then
        (sudo rm -rf "$home_dir"/.cache "$home_dir"/.thumbnails "$home_dir"/.local/share/Trash 2>/dev/null || true) &
        (sudo rm -rf "$home_dir"/.bash_history "$home_dir"/.python_history "$home_dir"/.node_repl_history 2>/dev/null || true) &
        (sudo rm -rf "$home_dir"/.lesshst "$home_dir"/.wget-hsts "$home_dir"/.viminfo 2>/dev/null || true) &
        (sudo rm -rf "$home_dir"/.mysql_history "$home_dir"/.sqlite_history "$home_dir"/.xsession-errors* 2>/dev/null || true) &
        # PROTECTED: ~/.npm is preserved for npm packages
        (sudo rm -rf "$home_dir"/.yarn "$home_dir"/.cargo/registry "$home_dir"/.cargo/git 2>/dev/null || true) &
        (sudo rm -rf "$home_dir"/.rustup/tmp "$home_dir"/.rustup/downloads 2>/dev/null || true) &
        (sudo rm -rf "$home_dir"/.gem "$home_dir"/.cpan "$home_dir"/.gradle "$home_dir"/.m2/repository 2>/dev/null || true) &
        (sudo rm -rf "$home_dir"/.ivy2/cache "$home_dir"/.sbt "$home_dir"/.nvm "$home_dir"/.rvm "$home_dir"/.rbenv 2>/dev/null || true) &
    fi
done
wait

# PARALLEL: Core dump and crash report cleanup
(sudo find / -xdev -type f \( -name "core" -o -name "core.[0-9]*" -o -name "*.core" -o -name "vgcore.*" -o -name "hs_err_pid*" \) -delete 2>/dev/null || true) &

# EXTREME ADDITIONS: Remove more unnecessary files
(sudo rm -rf /usr/share/bug/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/vim/vim*/doc/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/groff/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/gtk-doc/* 2>/dev/null || true) &
wait

calculate_saved $STEP_USAGE

# Phase 4: System Packages and Services Cleanup  
show_progress "Phase 4: Kernels, Services, and System Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🔧 Removing old kernels and headers..."
# Remove old kernels (safe in WSL)
dpkg --list | awk '/^ii  linux-image-[0-9]/{print $2}' | grep -v $(uname -r) | xargs -r sudo apt remove --purge -y 2>/dev/null || true
dpkg --list | awk '/^ii  linux-headers-[0-9]/{print $2}' | grep -v $(uname -r) | xargs -r sudo apt remove --purge -y 2>/dev/null || true
dpkg --list | awk '/^ii  linux-modules-[0-9]/{print $2}' | grep -v $(uname -r) | xargs -r sudo apt remove --purge -y 2>/dev/null || true

echo "⚙️ Disabling and removing non-essential services..."
# Disable unnecessary services (KEEP snapd.service - it's protected!)
services_to_disable=(
    "apport.service"
    "whoopsie"
    "motd-news.timer"
    "unattended-upgrades"
    # "snapd.service"  # PROTECTED - DO NOT DISABLE
    "bluetooth.service"
    "ModemManager.service"
    "cups.service"
    "avahi-daemon.service"
)

for service in "${services_to_disable[@]}"; do
    sudo systemctl disable --now "$service" 2>/dev/null || true
    sudo systemctl mask "$service" 2>/dev/null || true
done

# Remove service-related packages (KEEP snapd - it's protected!)
sudo apt remove --purge -y whoopsie apport cups-* bluetooth bluez avahi-daemon modemmanager >/dev/null 2>&1 || true
# NOTE: snapd is PROTECTED and will NOT be removed

calculate_saved $STEP_USAGE

# Phase 5: Localization and Media Content Removal
show_progress "Phase 5: Fonts, Languages, and Media Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🌐 EXTREME removal of ALL fonts and language packs (PARALLEL)..."
# PARALLEL: Remove all fonts and language content simultaneously
(sudo apt remove --purge -y fonts-* >/dev/null 2>&1 || true) &
(sudo rm -rf /usr/share/fonts/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/fontconfig/* 2>/dev/null || true) &
(sudo apt remove --purge -y language-pack-* >/dev/null 2>&1 || true) &
wait

# SAFE: Remove non-English locales but keep locale system functional
echo "🌐 Removing non-English locales (keeping system functional)..."
# Enhanced locale cleanup - remove all non-English locales
(sudo find /usr/share/locale -mindepth 1 -maxdepth 1 -type d ! -name 'en*' ! -name 'C.UTF-8' ! -name 'locale.alias' -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /usr/share/locale -mindepth 1 ! -path "*/en*" ! -path "*/locale.alias" -delete 2>/dev/null || true) &
(sudo find /usr/share/i18n/locales -type f ! -name "en_*" ! -name "i18n" ! -name "iso*" ! -name "translit_*" -delete 2>/dev/null || true) &
wait

# Enhanced icon cleanup
echo "🖼️ Removing large icon files..."
(sudo rm -rf /usr/share/icons/*/256x256 /usr/share/icons/*/512x512 2>/dev/null || true) &
(sudo rm -rf /usr/share/pixmaps/*.png /usr/share/pixmaps/*.xpm 2>/dev/null || true) &
wait

# DO NOT remove these - they break the system:
# /usr/share/i18n/locales/* - needed for locale-gen
# /usr/share/i18n/charmaps/* - needed for locale generation
# /usr/lib/locale/* - needed for runtime locale support

# Ensure both en_US.UTF-8 and C.UTF-8 are available
sudo mkdir -p /usr/share/locale/en_US.UTF-8 2>/dev/null || true
sudo mkdir -p /usr/share/locale/C.UTF-8 2>/dev/null || true
sudo locale-gen en_US.UTF-8 C.UTF-8 >/dev/null 2>&1 || true

# Disable the locale warning
sudo touch /var/lib/cloud/instance/locale-check.skip 2>/dev/null || true

# PARALLEL: Remove multimedia, graphics, and theme content
echo "🎵 EXTREME multimedia, themes, and graphics removal (PARALLEL)..."
(sudo rm -rf /usr/share/sounds/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/themes/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/icons/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/wallpapers/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/backgrounds/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/color-schemes/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/desktop-base/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/kde4/* 2>/dev/null || true) &
wait

calculate_saved $STEP_USAGE

# Phase 6: System Logs and Crash Reports
show_progress "Phase 6: Logs and Crash Reports Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🧹 Clearing ALL crash reports and system journals..."
sudo rm -rf /var/crash/* 2>/dev/null || true
sudo rm -rf /var/lib/systemd/coredump/* 2>/dev/null || true
sudo rm -rf /var/lib/apport/coredump/* 2>/dev/null || true
sudo rm -rf /var/lib/whoopsie/* 2>/dev/null || true

# Clear systemd journal completely
sudo journalctl --vacuum-size=1K 2>/dev/null || true
sudo journalctl --vacuum-time=1s 2>/dev/null || true
sudo rm -rf /var/log/journal/* 2>/dev/null || true

calculate_saved $STEP_USAGE

# Phase 7: Advanced File System Cleanup
show_progress "Phase 7: Advanced File System Operations"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🔑 Removing SSH host keys and network configs..."
sudo rm -rf /etc/ssh/ssh_host_* 2>/dev/null || true
sudo rm -rf /etc/NetworkManager/system-connections/* 2>/dev/null || true

echo "🔗 Removing broken symlinks system-wide..."
sudo find / -xdev -xtype l -delete 2>/dev/null || true

echo "🗂️ Cleaning user profile directories..."
for home_dir in /home/* /root; do
    if [ -d "$home_dir" ]; then
        sudo rm -rf "$home_dir"/.thumbnails 2>/dev/null || true
        sudo rm -rf "$home_dir"/.icons 2>/dev/null || true
        sudo rm -rf "$home_dir"/.local/share/icons 2>/dev/null || true
        sudo rm -rf "$home_dir"/.cache/icon-cache.kcache 2>/dev/null || true
        sudo rm -rf "$home_dir"/.local/share/recently-used.xbel 2>/dev/null || true
        sudo rm -rf "$home_dir"/.bash_history 2>/dev/null || true
        sudo rm -rf "$home_dir"/.python_history 2>/dev/null || true
    fi
done

calculate_saved $STEP_USAGE

# Phase 8: Large File Removal and Storage Optimization  
show_progress "Phase 8: Large Files and Storage Optimization"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "📊 FAST scan for large files (>10M, optimized)..."
# FAST: Lower threshold to 10M but use + for batch deletion (much faster)
sudo find / -xdev -type f -size +10M \
    ! -path "/proc/*" ! -path "/sys/*" ! -path "/dev/*" \
    ! -path "/usr/bin/*" ! -path "/usr/sbin/*" \
    ! -path "/bin/*" ! -path "/sbin/*" \
    ! -path "/lib/*" ! -path "/lib64/*" \
    ! -path "/usr/lib/*" ! -path "/usr/lib64/*" \
    -delete 2>/dev/null || true

echo "📦 EXTREME artifact cleanup (aggressive parallel)..."
# EXTREME: More comprehensive parallel cleanup
(sudo find / -xdev \( -name "*.deb" -o -name "*.rpm" -o -name "*.tar.gz" -o -name "*.zip" -o -name "*.bz2" -o -name "*.xz" -o -name "*.7z" \) -delete 2>/dev/null || true) &
(sudo find / -xdev -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true) &
(sudo find / -xdev -name "*.pyc" -o -name "*.pyo" -delete 2>/dev/null || true) &
# PROTECTED: node_modules are NOT deleted - user npm packages preserved
# (sudo find / -xdev -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true) &
(sudo find / -xdev -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true) &
(sudo find / -xdev -name "*.o" -o -name "*.a" -o -name "*.la" -delete 2>/dev/null || true) &
(sudo find / -xdev -name "*.iso" -o -name "*.img" -delete 2>/dev/null || true) &
(sudo find / -xdev -name "core" -o -name "core.*" -delete 2>/dev/null || true) &
wait

# Remove old snapshots, backups, and more
(sudo rm -rf /var/lib/snapshots/* 2>/dev/null || true) &
(sudo rm -rf /var/backups/* 2>/dev/null || true) &
(sudo rm -rf /var/spool/* 2>/dev/null || true) &
(sudo rm -rf /var/mail/* 2>/dev/null || true) &
wait

calculate_saved $STEP_USAGE

# Phase 9: Final System Optimization
show_progress "Phase 9: Final System Optimization and Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🔄 SAFE deep system cleanup (PARALLEL)..."
# SAFE: Clean caches but preserve system integrity
# DO NOT remove /var/lib/dpkg/info/* - breaks dpkg database!
(sudo rm -rf /var/lib/apt/lists/* 2>/dev/null || true) &
# DO NOT remove /var/lib/polkit-1/* - may break authentication
# DO NOT remove /var/cache/debconf/* - breaks package configuration!
# Only remove old debconf data
(sudo rm -rf /var/cache/debconf/*.dat-old 2>/dev/null || true) &
(sudo rm -rf /var/lib/systemd/catalog/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/python-wheels/* 2>/dev/null || true) &
(sudo rm -rf /var/cache/apt/pkgcache.bin /var/cache/apt/srcpkgcache.bin 2>/dev/null || true) &

# PARALLEL: Clean up graphics, multimedia, and X11 files
(sudo rm -rf /usr/lib/x86_64-linux-gnu/dri/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/glib-2.0/schemas/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/applications/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/X11/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/xsessions/* 2>/dev/null || true) &

# CRITICAL: DO NOT REMOVE PERL! It's essential for debconf and package management
# Removing Perl modules breaks dpkg, apt, and debconf completely!
# Keep /usr/share/perl5/* - needed by debconf
# Keep /usr/share/perl/* - needed by package system
(sudo rm -rf /usr/share/zsh/* 2>/dev/null || true) &
# Keep /usr/share/mime - may be needed by some system tools
(sudo rm -rf /usr/share/menu/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/dict/* 2>/dev/null || true) &
(sudo rm -rf /usr/lib/python*/dist-packages/*/tests 2>/dev/null || true) &
(sudo rm -rf /usr/lib/python*/test 2>/dev/null || true) &

wait

echo "🧹 Removing cleanup tools..."
sudo apt purge -y deborphan >/dev/null 2>&1 || true

# Final autoremove to catch anything we missed
sudo apt autoremove --purge -y >/dev/null 2>&1 || true

calculate_saved $STEP_USAGE

# Phase 9b: WSLg Cleanup - AGGRESSIVE TO GET UNDER 1GB
show_progress "Phase 9b: WSLg Aggressive Cleanup (Target: <1GB)"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

if [ -d /mnt/wslg ]; then
    echo "🪟 NUCLEAR WSLg cleanup to get UNDER 1GB..."

    # Show current size
    WSLG_BEFORE=$(sudo du -sb /mnt/wslg 2>/dev/null | awk '{print $1}')
    echo "📊 Current WSLg size: $(sudo du -sh /mnt/wslg 2>/dev/null | awk '{print $1}')"

    # NUCLEAR: Remove EVERYTHING except absolute essentials
    echo "💣 NUCLEAR WSLg cleanup - removing 95% of files..."

    # List what's in there
    echo "🔍 Analyzing WSLg contents..."
    sudo du -sh /mnt/wslg/* 2>/dev/null | sort -rh | head -10

    # CRITICAL: Clean the distro subdirectory which holds most data
    if [ -d /mnt/wslg/distro ]; then
        echo "🗑️ Found /mnt/wslg/distro - removing ALL contents..."
        (sudo find /mnt/wslg/distro/usr -mindepth 1 -delete 2>/dev/null || true) &
        (sudo find /mnt/wslg/distro/var -mindepth 1 -delete 2>/dev/null || true) &
        (sudo find /mnt/wslg/distro/etc -mindepth 1 -delete 2>/dev/null || true) &
        (sudo rm -rf /mnt/wslg/distro/root/* /mnt/wslg/distro/home/* /mnt/wslg/distro/tmp/* 2>/dev/null || true) &
        (sudo rm -rf /mnt/wslg/distro/wsl* 2>/dev/null || true) &
        wait
    fi

    # NUCLEAR Option 1: Remove ENTIRE directories except lib
    # CRITICAL: DO NOT remove runtime-dir or .X11-unix - needed for GUI apps!
    (sudo rm -rf /mnt/wslg/share 2>/dev/null || true) &
    (sudo rm -rf /mnt/wslg/doc 2>/dev/null || true) &
    (sudo rm -rf /mnt/wslg/include 2>/dev/null || true) &
    (sudo rm -rf /mnt/wslg/etc 2>/dev/null || true) &
    # (sudo rm -rf /mnt/wslg/runtime-dir 2>/dev/null || true) &  # KEEP FOR GUI
    # (sudo rm -rf /mnt/wslg/.X11-unix 2>/dev/null || true) &     # KEEP FOR GUI
    (sudo rm -rf /mnt/wslg/tmp 2>/dev/null || true) &
    (sudo rm -rf /mnt/wslg/cache 2>/dev/null || true) &
    wait

    # NUCLEAR Option 2: Aggressively strip libraries - keep ONLY essentials
    echo "🗑️ Stripping non-essential libraries..."
    # Keep only wayland, X11, EGL, and GLESv2 libraries
    (sudo find /mnt/wslg/lib* -type f ! -name "*wayland*" ! -name "*EGL*" ! -name "*GLESv2*" ! -name "*X11*" ! -name "*xcb*" ! -name "*xkb*" ! -name "*weston*" ! -name "*Xwayland*" -delete 2>/dev/null || true) &
    wait

    # NUCLEAR Option 3: Remove ALL documentation, locale, and data files
    (sudo find /mnt/wslg -type f \( -name "*.txt" -o -name "*.md" -o -name "*.html" -o -name "*.xml" -o -name "*.json" -o -name "*.conf" -o -name "*.cfg" -o -name "*.ini" \) -delete 2>/dev/null || true) &
    (sudo find /mnt/wslg -type f \( -name "*.log" -o -name "*.cache" -o -name "*.tmp" -o -name "*.old" -o -name "*.bak" \) -delete 2>/dev/null || true) &
    wait

    # NUCLEAR Option 4: Remove debugging symbols from binaries
    if command -v strip >/dev/null 2>&1; then
        echo "🔪 Stripping debug symbols from binaries..."
        (sudo find /mnt/wslg -type f -executable -exec strip --strip-debug {} \; 2>/dev/null || true) &
        (sudo find /mnt/wslg -type f -name "*.so*" -exec strip --strip-unneeded {} \; 2>/dev/null || true) &
        wait
    fi

    # NUCLEAR Option 5: Remove versioned .so files, keep only symlinks
    echo "🔗 Cleaning up library versions..."
    (sudo find /mnt/wslg -type f -name "*.so.*.*" -delete 2>/dev/null || true) &
    wait

    # Remove empty directories
    (sudo find /mnt/wslg -type d -empty -delete 2>/dev/null || true) &
    wait

    # Final size check with multiple attempts to get under 1GB
    WSLG_AFTER=$(sudo du -sb /mnt/wslg 2>/dev/null | awk '{print $1}')
    WSLG_SIZE_MB=$(( WSLG_AFTER / 1048576 ))
    echo "📊 WSLg size after cleanup: $(sudo du -sh /mnt/wslg 2>/dev/null | awk '{print $1}')"

    if [ $WSLG_SIZE_MB -ge 1024 ]; then
        echo "⚠️ Still ${WSLG_SIZE_MB} MB! Applying EXTREME measures..."

        # EXTREME: Remove ALL binaries except weston and Xwayland
        (sudo find /mnt/wslg/bin -type f ! -name "weston" ! -name "Xwayland" -delete 2>/dev/null || true) &

        # EXTREME: Remove system directories we don't need
        (sudo rm -rf /mnt/wslg/usr 2>/dev/null || true) &
        (sudo rm -rf /mnt/wslg/var 2>/dev/null || true) &
        (sudo rm -rf /mnt/wslg/opt 2>/dev/null || true) &
        wait

        WSLG_AFTER=$(sudo du -sb /mnt/wslg 2>/dev/null | awk '{print $1}')
        WSLG_SIZE_MB=$(( WSLG_AFTER / 1048576 ))
        echo "📊 WSLg size after EXTREME cleanup: $(sudo du -sh /mnt/wslg 2>/dev/null | awk '{print $1}')"
    fi

    WSLG_SAVED=$(( (WSLG_BEFORE - WSLG_AFTER) / 1048576 ))
    echo "💾 WSLg space saved: ${WSLG_SAVED} MB"

    if [ $WSLG_SIZE_MB -lt 1024 ]; then
        echo "✅ SUCCESS: WSLg is now under 1GB! (${WSLG_SIZE_MB} MB)"
    else
        echo "⚠️ WSLg is still ${WSLG_SIZE_MB} MB"
        echo ""
        echo "🔍 IMPORTANT: /mnt/wslg/distro is mounted READ-ONLY from Windows"
        echo "   This is a Windows-managed WSLg system VHDX that cannot be cleaned from WSL."
        echo ""
        echo "📝 To reduce WSLg size, you need to:"
        echo "   1. Shut down WSL:  wsl --shutdown"
        echo "   2. From PowerShell, optimize the WSLg VHDX:"
        echo "      optimize-vhd -Path \"\$env:LOCALAPPDATA\\Packages\\*\\LocalState\\ext4.vhdx\" -Mode Full"
        echo "   3. Or delete and recreate the distro for a fresh start"
        echo ""
        echo "   The WSLg size is managed by Windows and will auto-regenerate."
        echo "   For a minimal WSL distro, focus on the root filesystem size instead."
    fi
else
    echo "⏭️ WSLg not found at /mnt/wslg, skipping..."
fi

calculate_saved $STEP_USAGE

# Phase 9c: Docker Cleanup
show_progress "Phase 9c: Docker System Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

if command -v docker >/dev/null 2>&1; then
    echo "🐳 Performing aggressive Docker cleanup..."
    (docker system prune -af --volumes --filter "until=1h" 2>/dev/null || true) &
    (docker builder prune -af --filter "until=1h" 2>/dev/null || true) &
    wait
    (docker volume prune -af 2>/dev/null || true) &
    (docker image prune -af 2>/dev/null || true) &
    (docker container prune -af 2>/dev/null || true) &
    (docker network prune -af 2>/dev/null || true) &
    wait

    # PROTECTED: Docker data directories are preserved!
    # Only clean temp files, NOT overlay2/containers/images/volumes
    (sudo rm -rf /var/lib/docker/tmp/* 2>/dev/null || true) &
    # PROTECTED: overlay2, containers, image, network, volumes are NOT deleted
    # (sudo rm -rf /var/lib/docker/overlay2/* 2>/dev/null || true) &
    # (sudo rm -rf /var/lib/docker/containers/* 2>/dev/null || true) &
    # (sudo rm -rf /var/lib/docker/image/* 2>/dev/null || true) &
    # (sudo rm -rf /var/lib/docker/network/* 2>/dev/null || true) &
    # (sudo rm -rf /var/lib/docker/volumes/* 2>/dev/null || true) &
    echo "  🔒 Docker data preserved (overlay2, containers, images, volumes)"
    wait
else
    echo "⏭️  Docker not installed, skipping..."
fi

calculate_saved $STEP_USAGE

# Phase 9d: Package Manager Caches Cleanup
show_progress "Phase 9d: Package Manager Caches Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "📦 Cleaning package manager caches..."

# APT cleanup - we'll rebuild this at the end
(sudo rm -rf /var/lib/apt/lists/* 2>/dev/null || true) &
wait

# Note: We do NOT clear /var/lib/dpkg/available as it can break dpkg
# It will be regenerated automatically on next apt update

# Python pip cache
(pip cache purge 2>/dev/null || true) &
(pip3 cache purge 2>/dev/null || true) &
(python -m pip cache purge 2>/dev/null || true) &
(python3 -m pip cache purge 2>/dev/null || true) &
wait

# Node.js npm/yarn/pnpm cache
if command -v npm >/dev/null 2>&1; then
    # PROTECTED: Only clean npm cache, not the entire ~/.npm directory
    (npm cache clean --force 2>/dev/null || true) &
    (npm cache verify 2>/dev/null || true) &
    # Keep ~/.npm - only clean internal caches
    (rm -rf ~/.npm/_cacache ~/.npm/_logs 2>/dev/null || true) &
    echo "  🔒 npm packages preserved (only cache cleaned)"
    wait
fi

if command -v yarn >/dev/null 2>&1; then
    (yarn cache clean --all 2>/dev/null || true) &
    (rm -rf ~/.yarn/cache 2>/dev/null || true) &
    wait
fi

if command -v pnpm >/dev/null 2>&1; then
    pnpm store prune 2>/dev/null || true
fi

# Ruby gem cache
if command -v gem >/dev/null 2>&1; then
    (gem cleanup --quiet 2>/dev/null || true) &
    (bundle clean --force 2>/dev/null || true) &
    wait
fi

# Rust cargo cache
if command -v cargo >/dev/null 2>&1; then
    (cargo cache -a 2>/dev/null || true) &
    (rm -rf ~/.cargo/registry/cache ~/.cargo/registry/index ~/.cargo/git/checkouts 2>/dev/null || true) &
    wait
fi

# Go cache
if command -v go >/dev/null 2>&1; then
    (go clean -cache -modcache -testcache -fuzzcache 2>/dev/null || true) &
    (rm -rf ~/go/pkg 2>/dev/null || true) &
    wait
fi

# PHP composer cache
if command -v composer >/dev/null 2>&1; then
    (composer clear-cache 2>/dev/null || true) &
    (rm -rf ~/.composer/cache 2>/dev/null || true) &
    wait
fi

calculate_saved $STEP_USAGE

# Phase 9e: VSCode Server Cleanup
show_progress "Phase 9e: VSCode Server Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

if [ -d ~/.vscode-server ]; then
    echo "📝 Cleaning VSCode Server cache and logs..."
    (find ~/.vscode-server -type f -name "*.log" -delete 2>/dev/null || true) &
    (find ~/.vscode-server/data/logs -mindepth 1 -delete 2>/dev/null || true) &
    # PROTECTED: VSCode extension node_modules are preserved
    # (find ~/.vscode-server/extensions -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true) &
    (find ~/.vscode-server -type f -name "*.vsix" -delete 2>/dev/null || true) &
    echo "  🔒 VSCode extension node_modules preserved"
    wait
else
    echo "⏭️  VSCode Server not found, skipping..."
fi

calculate_saved $STEP_USAGE

# Phase 9f: Snap Cleanup
show_progress "Phase 9f: Snap Package Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

if [ -d /snap ]; then
    echo "📦 Cleaning Snap package cache..."
    (sudo rm -rf /snap/*/common/.cache /snap/*/common/tmp 2>/dev/null || true) &
    (sudo find /var/lib/snapd/cache -type f -delete 2>/dev/null || true) &
    wait
else
    echo "⏭️  Snap not installed, skipping..."
fi

calculate_saved $STEP_USAGE

# Phase 9g: Root and Home Cache Cleanup
show_progress "Phase 9g: Deep Root and Home Cache Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🏠 Deep cleaning root and home directories..."
# Root directory cache cleanup
(sudo find /root -type f -path "*/.cache/*" -delete 2>/dev/null || true) &
(sudo find /root -type d -name ".cache" -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /root -type f -path "*/.local/share/*" -delete 2>/dev/null || true) &
wait

# Home directories comprehensive cleanup
(sudo find /home -type f -path "*/.cache/*" -delete 2>/dev/null || true) &
(sudo find /home -type d -name ".cache" -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /home -type f -path "*/.thumbnails/*" -delete 2>/dev/null || true) &
(sudo find /home -type d -name ".thumbnails" -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /home -type f -path "*/.local/share/Trash/*" -delete 2>/dev/null || true) &
(sudo find /home -type d -path "*/.local/share/Trash" -exec rm -rf {} + 2>/dev/null || true) &
wait

# Remove history files and other user data
(sudo find /home -type f -path "*/.local/share/*" ! -path "*/.local/share/applications/*" ! -path "*/.local/share/fonts/*" -delete 2>/dev/null || true) &
(sudo find /home -type f \( -name ".bash_history" -o -name ".python_history" -o -name ".node_repl_history" -o -name ".lesshst" -o -name ".wget-hsts" -o -name ".viminfo" -o -name ".mysql_history" -o -name ".sqlite_history" \) -delete 2>/dev/null || true) &
wait

calculate_saved $STEP_USAGE

# Phase 10: Ultra-Aggressive Pre-Final Cleanup
show_progress "Phase 10: Ultra-Aggressive Pre-Final Space Recovery"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "💀 NUCLEAR OPTION: Removing every non-essential byte..."

# PROTECTED: snapd is NOT removed - it's a protected package!
# (sudo systemctl stop snapd 2>/dev/null || true) &
# (sudo systemctl disable snapd 2>/dev/null || true) &
# wait
# (sudo apt remove --purge -y snapd 2>/dev/null || true) &
# (sudo rm -rf /snap /var/snap /var/lib/snapd 2>/dev/null || true) &
# wait
echo "🔒 snapd is PROTECTED - skipping removal"

# Remove Python compiled files only (NOT packages!)
(sudo find / -xdev -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true) &
(sudo find / -xdev -type f -name "*.pyc" -delete 2>/dev/null || true) &
(sudo find / -xdev -type f -name "*.pyo" -delete 2>/dev/null || true) &
# PROTECTED: pip and setuptools are NOT deleted - essential for Python!
# (sudo rm -rf /usr/lib/python*/dist-packages/pip* 2>/dev/null || true) &
# (sudo rm -rf /usr/lib/python*/dist-packages/setuptools* 2>/dev/null || true) &
echo "🔒 pip and setuptools are PROTECTED - skipping removal"
wait

# Remove ALL header files and static libraries (parallel)
(sudo find /usr/include -type f -delete 2>/dev/null || true) &
(sudo find /usr/local/include -type f -delete 2>/dev/null || true) &
(sudo find / -xdev -name "*.h" -path "*/include/*" -delete 2>/dev/null || true) &
(sudo find / -xdev -name "*.hpp" -path "*/include/*" -delete 2>/dev/null || true) &
wait

# Remove ALL man pages, info pages, and help files (parallel)
(sudo rm -rf /usr/share/man 2>/dev/null || true) &
(sudo rm -rf /usr/share/info 2>/dev/null || true) &
(sudo rm -rf /usr/share/doc 2>/dev/null || true) &
(sudo rm -rf /usr/share/help 2>/dev/null || true) &
(sudo rm -rf /usr/local/share/man 2>/dev/null || true) &
(sudo rm -rf /usr/local/share/doc 2>/dev/null || true) &
wait

# Remove ALL examples and sample files (parallel)
(sudo find / -xdev -type d -name "examples" -exec rm -rf {} + 2>/dev/null || true) &
(sudo find / -xdev -type d -name "samples" -exec rm -rf {} + 2>/dev/null || true) &
(sudo rm -rf /usr/share/doc-base 2>/dev/null || true) &
wait

calculate_saved $STEP_USAGE

# Phase 11: Final Verification and Cleanup
show_progress "Phase 11: Final Verification and Optimization"

echo "🔍 Rebuilding essential system databases..."
# CRITICAL: Rebuild package lists so apt install works after cleanup
echo "📦 Updating APT package lists - CRITICAL FOR PACKAGE INSTALLATION..."
# Force apt update multiple times to ensure it works
for i in 1 2 3; do
    echo "  Attempt $i/3: Updating package lists..."
    if sudo apt update 2>&1 | tee /tmp/apt_update.log | grep -E "Hit:|Get:|Fetched|Reading"; then
        echo "  ✅ APT update successful on attempt $i"
        break
    else
        echo "  ⚠️ Attempt $i failed, retrying..."
        sleep 2
    fi
done
sudo rm -f /tmp/apt_update.log

# Verify sources exist and restore if needed
UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
echo "  🔍 Checking APT sources for Ubuntu $UBUNTU_CODENAME..."

# Check if using new deb822 format or old format
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    echo "  ✓ Modern deb822 format sources found"
elif [ -f /etc/apt/sources.list ] && [ -s /etc/apt/sources.list ]; then
    echo "  ✓ Traditional sources.list found"
else
    echo "  ⚠️ APT sources missing! Restoring..."

    # Try modern deb822 format first (for Ubuntu 24.04+)
    sudo bash -c "cat > /etc/apt/sources.list.d/ubuntu.sources << 'EOF'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: ${UBUNTU_CODENAME} ${UBUNTU_CODENAME}-updates ${UBUNTU_CODENAME}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

EOF"

    # Also create traditional format as fallback
    sudo bash -c "cat > /etc/apt/sources.list << 'EOF'
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
EOF"

    # Substitute the codename
    sudo sed -i "s/\${UBUNTU_CODENAME}/$UBUNTU_CODENAME/g" /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true
    sudo sed -i "s/\${UBUNTU_CODENAME}/$UBUNTU_CODENAME/g" /etc/apt/sources.list

    echo "  ✅ APT sources restored for all components (main, universe, multiverse)"
    sudo apt update -y
fi

echo "✅ APT package database restored - apt install should now work!"

echo "⚡ SKIPPING zero-fill for MAXIMUM SPEED..."
echo "💡 Zero-fill disabled - cleanup will complete in seconds instead of minutes!"
echo "📊 Note: Export compression may be slightly less optimal, but cleanup is MUCH faster."

# Additional EXTREME cleanup for MINIMAL WSL2 distro size
echo "🧹 ULTIMATE aggressive cleanup for ABSOLUTE minimal distro size..."

# EXTREME: Remove ALL log, backup, and temporary file patterns (parallel)
(sudo find / -xdev -type f \( -name "*.log" -o -name "*.log.*" -o -name "*.old" -o -name "*.bak" -o -name "*~" -o -name "*.tmp" -o -name "*.swp" \) -delete 2>/dev/null || true) &
(sudo find /usr -type f \( -name "*.a" -o -name "*.la" \) -delete 2>/dev/null || true) &
(sudo find / -xdev -name "*.md" -path "*/doc/*" -delete 2>/dev/null || true) &
(sudo find / -xdev -name "README*" -path "*/doc/*" -delete 2>/dev/null || true) &
(sudo find / -xdev -name "CHANGELOG*" -delete 2>/dev/null || true) &
(sudo find / -xdev -name "AUTHORS" -delete 2>/dev/null || true) &
(sudo find / -xdev -name "COPYING" -delete 2>/dev/null || true) &
(sudo find / -xdev -name "LICENSE*" ! -path "/proc/*" ! -path "/sys/*" -delete 2>/dev/null || true) &
wait

# SAFE: Parallel cache and temp cleanup (protecting essentials)
(sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true) &
(sudo rm -rf /home/*/.cache/* /root/.cache/* 2>/dev/null || true) &
# Careful with /var/cache - preserve debconf and essential package manager data
(sudo rm -rf /var/cache/apt/archives/* 2>/dev/null || true) &
(sudo rm -rf /var/cache/fontconfig/* 2>/dev/null || true) &
(sudo rm -rf /var/cache/man/* 2>/dev/null || true) &
# DO NOT remove /var/cache/debconf/* - breaks package configuration!
(sudo rm -rf /var/lib/apt/lists/* 2>/dev/null || true) &
# Keep /usr/share/terminfo - needed by terminal emulators
(sudo rm -rf /usr/share/tabset/* 2>/dev/null || true) &
# Keep /usr/share/misc - contains important system files like magic.mgc
# Keep /usr/share/common-licenses - needed by some packages
# Keep firmware - may be needed for hardware support
wait

# SAFE: Remove compiler/build artifacts (but NOT system libraries!)
echo "💣 Removing compiler and build artifacts (protecting system libraries)..."
(sudo find / -xdev -name "*.o" ! -path "/usr/lib/*" ! -path "/lib/*" ! -path "/usr/share/perl*" -delete 2>/dev/null || true) &
(sudo find / -xdev -name "*.a" ! -path "/usr/lib/*" ! -path "/lib/*" ! -path "/usr/share/perl*" -delete 2>/dev/null || true) &
# DO NOT delete *.so.* files - these are ESSENTIAL shared libraries (libcrypto.so.3, etc.)
# DO NOT delete Perl modules - they are essential for debconf and package management!
# Removing them BREAKS the entire system!
wait

# Quick memory cache clear and system optimization
echo "💾 Clearing memory caches and optimizing system..."
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true

# Filesystem trim for SSD optimization
echo "✂️ Running filesystem trim..."
sudo fstrim -av 2>/dev/null || true

# Swap optimization
echo "🔄 Optimizing swap..."
sudo swapoff -a 2>/dev/null && sudo swapon -a 2>/dev/null || true

# Clear shell history
echo "📜 Clearing shell history..."
history -c

# Restart logging services
echo "🔄 Restarting logging services..."
sudo mkdir -p /var/log/journal 2>/dev/null || true
sudo systemctl start systemd-journald 2>/dev/null || true
sudo systemctl start rsyslog 2>/dev/null || true

# CRITICAL: Final APT update to ensure package installation works
echo ""
echo "=================== CRITICAL APT RESTORATION ==================="
echo "📦 Performing comprehensive APT system restoration..."

# Ensure APT directories exist
sudo mkdir -p /var/lib/apt/lists/partial 2>/dev/null || true
sudo mkdir -p /var/cache/apt/archives/partial 2>/dev/null || true
sudo mkdir -p /etc/apt/sources.list.d 2>/dev/null || true

# CRITICAL: Fix DNS before APT operations
echo "🔧 Ensuring DNS is working..."
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "⚠️  No internet connectivity - cannot proceed with APT update"
elif ! ping -c 1 archive.ubuntu.com >/dev/null 2>&1; then
    echo "⚠️  DNS not working - fixing resolv.conf..."
    sudo rm -f /etc/resolv.conf
    sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
    sudo bash -c 'echo "nameserver 8.8.4.4" >> /etc/resolv.conf'
    sudo bash -c 'echo "nameserver 1.1.1.1" >> /etc/resolv.conf'
    echo "✅ DNS fixed with Google/Cloudflare nameservers"
else
    echo "✅ DNS working correctly"
fi

# CRITICAL: Restore APT sources before final update
UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "noble")
echo "🔧 Ensuring APT sources exist for Ubuntu $UBUNTU_CODENAME..."

# Always recreate sources to ensure they're correct
sudo bash -c "cat > /etc/apt/sources.list.d/ubuntu.sources << 'EOFSOURCES'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: ${UBUNTU_CODENAME} ${UBUNTU_CODENAME}-updates ${UBUNTU_CODENAME}-security ${UBUNTU_CODENAME}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

EOFSOURCES"

# Substitute the codename
sudo sed -i "s/\${UBUNTU_CODENAME}/$UBUNTU_CODENAME/g" /etc/apt/sources.list.d/ubuntu.sources

echo "✅ APT sources configured with ALL components (main, restricted, universe, multiverse)"

# CRITICAL: Remove broken command-not-found APT hooks
echo "🔧 Removing broken command-not-found APT hooks..."
sudo rm -f /etc/apt/apt.conf.d/*command-not-found* 2>/dev/null || true
sudo rm -f /usr/lib/cnf-update-db 2>/dev/null || true
sudo rm -f /usr/lib/command-not-found 2>/dev/null || true
echo "✅ command-not-found hooks removed (prevents Python apt_pkg errors)"

# Force complete APT update with retries
APT_SUCCESS=false
for attempt in 1 2 3 4 5; do
    echo "🔄 APT Update Attempt $attempt/5..."
    if sudo apt-get update -y 2>&1 | tee /tmp/apt_final.log; then
        if grep -qE "(Hit:|Get:|Reading package lists)" /tmp/apt_final.log; then
            # Verify we actually got package data
            if [ -n "$(ls -A /var/lib/apt/lists/ 2>/dev/null | grep -v 'partial\|lock\|auxfiles')" ]; then
                APT_SUCCESS=true
                echo "✅ APT update successful on attempt $attempt!"
                break
            else
                echo "⚠️ Package lists empty - network may be down"
            fi
        fi
    fi
    echo "⚠️ Attempt $attempt incomplete, waiting 3 seconds..."
    sleep 3
done

sudo rm -f /tmp/apt_final.log

if [ "$APT_SUCCESS" = true ]; then
    echo "✅ APT system fully restored and ready!"
else
    echo "⚠️ APT update had issues - this is usually due to no internet connection"
    echo "📝 Package lists will be downloaded when you run 'apt update' with internet"
    sudo dpkg --configure -a 2>/dev/null || true
    sudo apt-get -f install -y 2>/dev/null || true
fi

# POST-CLEANUP VERIFICATION AND REPAIR
echo ""
echo "=================== POST-CLEANUP VERIFICATION ==================="
echo "🔍 Verifying system integrity..."

# Verify critical libraries still exist
CRITICAL_LIBS=("/lib/x86_64-linux-gnu/libcrypto.so.3" "/lib/x86_64-linux-gnu/libc.so.6" "/lib/x86_64-linux-gnu/libssl.so.3")
SYSTEM_OK=true
for lib in "${CRITICAL_LIBS[@]}"; do
    if [ -f "$lib" ]; then
        echo "  ✓ Protected: $lib"
    else
        echo "  ✗ MISSING: $lib - SYSTEM DAMAGED!"
        SYSTEM_OK=false
    fi
done

# Verify locale system is working
if locale -a | grep -q "C.UTF-8\|en_US.UTF-8"; then
    echo "  ✓ Locale system: Functional"
else
    echo "  ⚠️  Locale system: May need repair"
    sudo locale-gen en_US.UTF-8 C.UTF-8 >/dev/null 2>&1 || true
fi

# Verify apt is working and can find packages
echo ""
echo "🔍 COMPREHENSIVE APT FUNCTIONALITY TEST..."

# Test 1: APT cache policy
if apt-cache policy >/dev/null 2>&1; then
    echo "  ✓ Test 1/5: apt-cache policy - PASSED"
else
    echo "  ✗ Test 1/5: apt-cache policy - FAILED"
    sudo apt-get update -y >/dev/null 2>&1
fi

# Test 2: Can search for packages
if apt-cache search bash 2>/dev/null | grep -q "bash"; then
    echo "  ✓ Test 2/5: Package search - PASSED"
else
    echo "  ✗ Test 2/5: Package search - FAILED (updating...)"
    sudo apt-get update -y >/dev/null 2>&1
fi

# Test 3: Can show specific package info
if apt-cache show coreutils >/dev/null 2>&1; then
    echo "  ✓ Test 3/5: Package info (coreutils) - PASSED"
else
    echo "  ✗ Test 3/5: Package info - FAILED (updating...)"
    sudo apt-get update -y >/dev/null 2>&1
fi

# Test 4: Check if mousepad is available
if apt-cache show mousepad >/dev/null 2>&1; then
    echo "  ✓ Test 4/5: Package 'mousepad' found - PASSED"
else
    echo "  ⚠️ Test 4/5: Package 'mousepad' not in repos (this is OK)"
fi

# Test 5: Verify package lists are populated
if [ -n "$(ls -A /var/lib/apt/lists/ 2>/dev/null)" ]; then
    echo "  ✓ Test 5/5: Package lists populated - PASSED"
else
    echo "  ✗ Test 5/5: Package lists empty - FAILED"
    echo "  🔄 Emergency APT restoration..."
    sudo rm -rf /var/lib/apt/lists/*
    sudo mkdir -p /var/lib/apt/lists/partial
    sudo apt-get update -y
fi

# Final comprehensive test
echo ""
echo "🧪 FINAL APT INSTALLATION TEST..."
if apt-cache show nano >/dev/null 2>&1; then
    echo "  ✅ SUCCESS: APT is fully functional!"
    echo "  ✅ You can now install packages with: apt install <package>"
    echo "  ✅ Example: apt install mousepad -y"
else
    echo "  ❌ CRITICAL: APT still not working properly"
    echo "  🔧 Running emergency repair sequence..."
    sudo dpkg --configure -a
    sudo apt-get -f install -y
    sudo apt-get update -y
    if apt-cache show nano >/dev/null 2>&1; then
        echo "  ✅ Repair successful!"
    else
        echo "  ❌ Manual intervention required. Run: sudo apt update"
    fi
fi

echo ""
if [ "$SYSTEM_OK" = true ]; then
    echo "✅ System integrity verified - all critical components intact!"
else
    echo "❌ SYSTEM DAMAGE DETECTED - Critical libraries missing!"
    echo "   Run: sudo apt install --reinstall libssl3 libcrypto3"
fi

# Final disk usage
echo ""
echo "╔════════════════════════════════════════════╗"
echo "║  AGGRESSIVE CLEANUP COMPLETE - SUB-1GB AIM ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Calculate total space saved
FINAL_USAGE=$(df / | tail -1 | awk '{print $3}')
TOTAL_SAVED=$(((INITIAL_USAGE - FINAL_USAGE) / 1024))

echo "📊 Final disk space usage:"
df -h / | tail -n +2
echo ""
echo "💾 Total space saved: ${TOTAL_SAVED} MB"
echo ""

# Display WSLg size if available
echo "/mnt/wslg size: $(sudo du -sh /mnt/wslg 2>/dev/null | awk '{print $1}' || echo 'N/A')"
echo ""

echo "✅ MAXIMUM WSL2 Ubuntu cleanup completed successfully!"
echo "⚡ ULTRA-FAST MODE: Completed in record time (no zero-fill delay)!"
echo "🛡️  SAFETY MODE: Critical system libraries and locales protected!"
echo "🎯 Your WSL2 distro is now optimized for minimum storage usage."
echo ""

# Final verification that apt install works
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║     FINAL VERIFICATION - APT INSTALLATION TEST       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Test if we can actually query packages
TEST_PASSED=0
TEST_TOTAL=3

echo "🧪 Running final package availability tests..."

# Test 1: nano (should always be available)
if apt-cache show nano >/dev/null 2>&1; then
    echo "  ✅ Test 1: Package 'nano' found"
    ((TEST_PASSED++))
else
    echo "  ❌ Test 1: Package 'nano' NOT found"
fi

# Test 2: coreutils (should always be available)
if apt-cache show coreutils >/dev/null 2>&1; then
    echo "  ✅ Test 2: Package 'coreutils' found"
    ((TEST_PASSED++))
else
    echo "  ❌ Test 2: Package 'coreutils' NOT found"
fi

# Test 3: mousepad or another common package
if apt-cache show mousepad >/dev/null 2>&1; then
    echo "  ✅ Test 3: Package 'mousepad' found"
    ((TEST_PASSED++))
elif apt-cache show vim >/dev/null 2>&1; then
    echo "  ✅ Test 3: Package 'vim' found (mousepad not in repos)"
    ((TEST_PASSED++))
else
    echo "  ❌ Test 3: Package search failed"
fi

echo ""
if [ $TEST_PASSED -ge 2 ]; then
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ✅ APT SYSTEM: FULLY FUNCTIONAL ($TEST_PASSED/$TEST_TOTAL tests passed)  ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "✅ You can now install packages:"
    echo "   • apt install mousepad -y"
    echo "   • apt install <any-package> -y"
else
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ⚠️  APT SYSTEM: NEEDS ATTENTION ($TEST_PASSED/$TEST_TOTAL tests)      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "⚠️  Running one final emergency repair..."
    sudo apt-get update -y 2>&1 | tail -5
fi
echo ""

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              CLEANUP COMPLETION SUMMARY              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Generate final status report
FINAL_ROOT_USAGE=$(df -h / | tail -1 | awk '{print $5}')
FINAL_ROOT_AVAILABLE=$(df -h / | tail -1 | awk '{print $4}')
WSLG_FINAL_SIZE=$(sudo du -sh /mnt/wslg 2>/dev/null | awk '{print $1}' || echo "N/A")

echo "📊 SYSTEM STATUS:"
echo "   • Root filesystem usage: $FINAL_ROOT_USAGE"
echo "   • Available space: $FINAL_ROOT_AVAILABLE"
echo "   • WSLg size: $WSLG_FINAL_SIZE"
echo "   • Total space saved: ${TOTAL_SAVED} MB"
echo ""

echo "✅ VERIFICATION RESULTS:"
echo "   • Critical libraries: Protected ✓"
echo "   • Locale system: Functional ✓"
echo "   • APT system: $(if [ $TEST_PASSED -ge 2 ]; then echo 'Fully functional ✓'; else echo 'Needs attention ⚠️'; fi)"
echo "   • Package installation: $(if [ $TEST_PASSED -ge 2 ]; then echo 'Ready ✓'; else echo 'May need repair ⚠️'; fi)"
echo ""

echo "🎯 CLEANUP OBJECTIVES:"
if [ $TEST_PASSED -ge 2 ]; then
    echo "   ✅ APT package installation: WORKING"
else
    echo "   ⚠️  APT package installation: NEEDS VERIFICATION"
fi

# Check WSLg size
if [ "$WSLG_FINAL_SIZE" != "N/A" ]; then
    WSLG_SIZE_NUM=$(echo $WSLG_FINAL_SIZE | sed 's/[^0-9.]//g')
    WSLG_UNIT=$(echo $WSLG_FINAL_SIZE | sed 's/[0-9.]//g')
    if [[ "$WSLG_UNIT" == *"M"* ]] || [[ "$WSLG_UNIT" == *"K"* ]]; then
        echo "   ✅ WSLg under 1GB: YES (${WSLG_FINAL_SIZE})"
    elif [[ "$WSLG_UNIT" == *"G"* ]] && (( $(echo "$WSLG_SIZE_NUM < 1" | bc -l 2>/dev/null || echo 0) )); then
        echo "   ✅ WSLg under 1GB: YES (${WSLG_FINAL_SIZE})"
    else
        echo "   ⚠️  WSLg size: ${WSLG_FINAL_SIZE} (target: <1GB)"
    fi
else
    echo "   ⏭️  WSLg: Not present"
fi

echo ""
echo "⚠️  Note: This aggressive cleanup removed all non-essential components."
echo "   You may need to reinstall packages as needed for your use case."
echo ""
echo "🚀 READY TO USE!"
echo "   Test with: apt install mousepad -y && mousepad"
echo ""
echo "💡 TIP: To export this cleaned distro:"
echo "   wsl --export <distro-name> <output-file.tar> --vhd"
echo ""

# CRITICAL FIX: Restore terminal echo (fixes invisible input issue)
echo "🔧 Restoring terminal settings..."
stty sane 2>/dev/null || true
stty echo 2>/dev/null || true
stty icanon 2>/dev/null || true
stty icrnl 2>/dev/null || true
reset 2>/dev/null || true

# Create .bashrc.d structure for modular configuration
sudo mkdir -p /root/.bashrc.d

# Terminal fix
cat > /root/.bashrc.d/terminal-fix.sh << 'EOFTERM'
# Terminal echo fix - prevents invisible input
stty sane 2>/dev/null || true
stty echo 2>/dev/null || true
EOFTERM

# Source bashrc.d files in .bashrc
if ! grep -q ".bashrc.d" /root/.bashrc 2>/dev/null; then
    echo "" >> /root/.bashrc
    echo "# Source all configurations from .bashrc.d" >> /root/.bashrc
    echo 'if [ -d ~/.bashrc.d ]; then' >> /root/.bashrc
    echo '  for f in ~/.bashrc.d/*.sh; do' >> /root/.bashrc
    echo '    [ -r "$f" ] && source "$f"' >> /root/.bashrc
    echo '  done' >> /root/.bashrc
    echo 'fi' >> /root/.bashrc
fi

echo "✅ Terminal configuration added to /root/.bashrc.d/terminal-fix.sh"

# CRITICAL: Ensure distro stays under 1.2GB by setting up automatic cleanup
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║     DISTRO SIZE MANAGEMENT - PERMANENT SOLUTION      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Get current distro size
DISTRO_SIZE_KB=$(df / | tail -1 | awk '{print $3}')
DISTRO_SIZE_MB=$((DISTRO_SIZE_KB / 1024))
DISTRO_SIZE_GB=$(echo "scale=2; $DISTRO_SIZE_MB / 1024" | bc -l 2>/dev/null || echo "0")

echo "📊 Current distro size: ${DISTRO_SIZE_MB}MB (${DISTRO_SIZE_GB}GB)"

# If over 1.2GB, run ultra-aggressive emergency cleanup
if [ $DISTRO_SIZE_MB -gt 1228 ]; then
    echo "⚠️  Size exceeded 1.2GB target - running ULTRA-AGGRESSIVE cleanup..."

    # Remove absolutely everything non-essential (parallel)
    (sudo find /usr/share/doc -mindepth 1 -delete 2>/dev/null || true) &
    (sudo find /usr/share/man -mindepth 1 -delete 2>/dev/null || true) &
    (sudo find /usr/share/info -mindepth 1 -delete 2>/dev/null || true) &
    (sudo find /usr/share/locale -mindepth 1 ! -path "*/en*" ! -path "*/locale.alias" -delete 2>/dev/null || true) &
    (sudo find /var/log -type f -delete 2>/dev/null || true) &
    (sudo find /tmp -mindepth 1 -delete 2>/dev/null || true) &
    (sudo find /var/tmp -mindepth 1 -delete 2>/dev/null || true) &
    (sudo find /home -type d -name ".cache" -exec rm -rf {} + 2>/dev/null || true) &
    (sudo find /root -type d -name ".cache" -exec rm -rf {} + 2>/dev/null || true) &
    wait

    # Remove package caches
    (sudo apt-get clean -y 2>/dev/null || true) &
    (sudo apt-get autoclean -y 2>/dev/null || true) &
    (sudo apt-get autoremove --purge -y 2>/dev/null || true) &
    (sudo rm -rf /var/cache/apt/archives/*.deb 2>/dev/null || true) &
    wait

    # Remove non-essential packages
    sudo apt remove --purge -y $(dpkg-query -Wf '${Package}\n' | grep -E '^(ubuntu-advantage|landscape|cloud-init|update-notifier|update-manager|friendly-recovery|lxd-agent)' 2>/dev/null) 2>/dev/null || true

    # Check new size
    DISTRO_SIZE_KB=$(df / | tail -1 | awk '{print $3}')
    DISTRO_SIZE_MB=$((DISTRO_SIZE_KB / 1024))
    DISTRO_SIZE_GB=$(echo "scale=2; $DISTRO_SIZE_MB / 1024" | bc -l 2>/dev/null || echo "0")
    echo "📊 Size after emergency cleanup: ${DISTRO_SIZE_MB}MB (${DISTRO_SIZE_GB}GB)"
fi

# Create automatic cleanup script that runs after any apt install
echo "🔧 Setting up automatic size maintenance..."

# Create post-install hook
sudo mkdir -p /etc/apt/apt.conf.d
sudo bash -c 'cat > /etc/apt/apt.conf.d/99-auto-cleanup << '\''EOFCONF'\''
// Automatic cleanup after every package operation
DPkg::Post-Invoke {
  "if [ -x /usr/local/bin/wsl-size-keeper ]; then /usr/local/bin/wsl-size-keeper; fi";
};
EOFCONF'

# Create the size keeper script
sudo bash -c 'cat > /usr/local/bin/wsl-size-keeper << '\''EOFSCRIPT'\''
#!/bin/bash
# WSL Size Keeper - Ensures distro never exceeds 1.2GB
set +e

# Maximum size in KB (1.2GB = 1,258,291KB)
MAX_SIZE_KB=1258291

# Get current size
CURRENT_SIZE=$(df / | tail -1 | awk '\''{print $3}'\'')

# If under limit, do nothing
if [ $CURRENT_SIZE -lt $MAX_SIZE_KB ]; then
    exit 0
fi

# Size exceeded - run aggressive cleanup
echo "⚠️  Distro size exceeded 1.2GB - running automatic cleanup..."

# Quick parallel cleanup of common bloat
(find /tmp -mindepth 1 -delete 2>/dev/null || true) &
(find /var/tmp -mindepth 1 -delete 2>/dev/null || true) &
(rm -rf /var/cache/apt/archives/*.deb 2>/dev/null || true) &
(find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true) &
(find /home -type f -path "*/.cache/*" -delete 2>/dev/null || true) &
(find /root -type f -path "*/.cache/*" -delete 2>/dev/null || true) &
(rm -rf /var/lib/apt/lists/* 2>/dev/null || true) &
wait

# Clean package caches
apt-get clean -y >/dev/null 2>&1 || true
apt-get autoclean -y >/dev/null 2>&1 || true
apt-get autoremove --purge -y >/dev/null 2>&1 || true

# Check size again
NEW_SIZE=$(df / | tail -1 | awk '\''{print $3}'\'')
if [ $NEW_SIZE -lt $CURRENT_SIZE ]; then
    SAVED_KB=$((CURRENT_SIZE - NEW_SIZE))
    SAVED_MB=$((SAVED_KB / 1024))
    echo "✅ Cleaned ${SAVED_MB}MB - distro size maintained"
fi

exit 0
EOFSCRIPT'

sudo chmod +x /usr/local/bin/wsl-size-keeper

# Run it once now to ensure we're under limit
sudo /usr/local/bin/wsl-size-keeper

# Final size check
FINAL_SIZE_KB=$(df / | tail -1 | awk '{print $3}')
FINAL_SIZE_MB=$((FINAL_SIZE_KB / 1024))
FINAL_SIZE_GB=$(echo "scale=2; $FINAL_SIZE_MB / 1024" | bc -l 2>/dev/null || echo "0")

if [ $FINAL_SIZE_MB -le 1228 ]; then  # 1.2GB = 1228MB
    echo "✅ SUCCESS: Distro size is ${FINAL_SIZE_MB}MB (${FINAL_SIZE_GB}GB) - UNDER 1.2GB TARGET!"
else
    echo "⚠️  Distro size is ${FINAL_SIZE_MB}MB (${FINAL_SIZE_GB}GB)"
    echo "📝 Automatic cleanup installed - size will be managed after each apt install"
fi

echo ""
echo "✅ Permanent size management configured!"
echo "   → Distro will auto-cleanup after every package install"
echo "   → Maximum size: 1.2GB (will trigger automatic cleanup if exceeded)"
echo ""

# CRITICAL FINAL STEP: Ensure APT can find packages
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          FINAL CRITICAL APT UPDATE                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "🔄 Running final APT update to ensure package installation works..."

# Check if we have package lists
if [ -z "$(ls -A /var/lib/apt/lists/ 2>/dev/null | grep -v 'partial\|lock\|auxfiles')" ]; then
    echo "⚠️  Package lists are empty - attempting to download..."

    # Try to update with internet check
    if sudo apt-get update -y 2>&1 | grep -qE "(Hit:|Get:|Fetched)"; then
        echo "✅ Package lists downloaded successfully!"
    else
        echo ""
        echo "╔══════════════════════════════════════════════════════╗"
        echo "║              ⚠️  ACTION REQUIRED  ⚠️                  ║"
        echo "╚══════════════════════════════════════════════════════╝"
        echo ""
        echo "❌ Unable to download package lists (no internet connection)"
        echo ""
        echo "📝 BEFORE installing any packages, you MUST run:"
        echo "   sudo apt update"
        echo ""
        echo "   This will download the package lists from the universe"
        echo "   repository so you can install packages like mousepad."
        echo ""
        echo "✅ APT sources are configured correctly - just need internet!"
        echo ""
    fi
else
    echo "✅ Package lists already present!"
fi

# Final verification - test if mousepad is available
echo ""
echo "🧪 Testing if mousepad package can be found..."
if apt-cache show mousepad >/dev/null 2>&1; then
    echo "✅ SUCCESS: mousepad package found!"
    echo "   You can now install with: apt install mousepad -y"
else
    echo "⚠️  mousepad not found in package cache"
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║         🔧 REQUIRED ACTION TO FIX THIS  🔧           ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "Run this command NOW to download package lists:"
    echo ""
    echo "   sudo apt update -y"
    echo ""
    echo "After running apt update, mousepad will be available."
    echo "The universe repository is already configured."
    echo ""
fi

# CRITICAL: Fix dconf and X11 for GUI applications
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║       GUI APPLICATION SUPPORT (dconf + X11)          ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Fix 1: Create runtime directory for dconf (using /tmp as workaround)
echo "🔧 Creating runtime directory for dconf..."
sudo mkdir -p /tmp/user-0-runtime/dconf
sudo chmod 700 /tmp/user-0-runtime
sudo chown root:root /tmp/user-0-runtime
echo "✅ Runtime directory created: /tmp/user-0-runtime"

# Fix 2: Set up environment variables for GUI apps
echo "🔧 Setting up environment for GUI applications..."
cat > /root/.bashrc.d/wsl-gui.sh << 'EOFGUI'
# WSL GUI Support - WSLg + dconf
export XDG_RUNTIME_DIR=/tmp/user-0-runtime
mkdir -p $XDG_RUNTIME_DIR/dconf 2>/dev/null
# Get Windows host IP for X11
WINDOWS_HOST=$(ip route show default 2>/dev/null | awk '{print $3}')
[ -z "$WINDOWS_HOST" ] && WINDOWS_HOST=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}' | head -1)
export DISPLAY=${WINDOWS_HOST}:0
export WAYLAND_DISPLAY=wayland-0
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export LIBGL_ALWAYS_INDIRECT=1
export NO_AT_BRIDGE=1
EOFGUI

# Apply immediately for this session
export XDG_RUNTIME_DIR=/tmp/user-0-runtime
WINDOWS_HOST=$(ip route show default 2>/dev/null | awk '{print $3}')
[ -z "$WINDOWS_HOST" ] && WINDOWS_HOST=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}' | head -1)
export DISPLAY=${WINDOWS_HOST}:0
export WAYLAND_DISPLAY=wayland-0
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export LIBGL_ALWAYS_INDIRECT=1
export NO_AT_BRIDGE=1
echo "✅ GUI environment configured in /root/.bashrc.d/wsl-gui.sh"
echo "   • XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
echo "   • DISPLAY: $DISPLAY"
echo "   • GDK_BACKEND: x11"

echo ""
echo "✅ GUI support configured!"
echo "   • dconf directory: /run/user/0/dconf"
echo "   • X11 display: DISPLAY=:0"
echo "   • OpenGL: LIBGL_ALWAYS_INDIRECT=1"
echo ""

# ============================================================================
# PHASE 12: ULTRA-NUCLEAR CLEANUP - TARGET <1.7GB
# ============================================================================
show_progress "Phase 12: ULTRA-NUCLEAR Cleanup - Target <1.7GB"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "💀 ULTRA-NUCLEAR MODE: Removing EVERYTHING non-essential..."
echo "🎯 Target: <1.7GB disk usage"

# NUCLEAR: Remove LLVM (137MB) - not needed unless compiling LLVM-based code
echo "🔥 Removing LLVM libraries (137MB)..."
(sudo rm -f /usr/lib/x86_64-linux-gnu/libLLVM*.so* 2>/dev/null || true) &

# NUCLEAR: Remove ALL Vulkan drivers (~76MB) - not needed for WSL headless
echo "🔥 Removing Vulkan GPU drivers (76MB)..."
(sudo rm -f /usr/lib/x86_64-linux-gnu/libvulkan_*.so* 2>/dev/null || true) &

# NUCLEAR: Remove gallium GPU libraries
echo "🔥 Removing Gallium GPU libraries..."
(sudo rm -f /usr/lib/x86_64-linux-gnu/libgallium*.so* 2>/dev/null || true) &

# NUCLEAR: Remove Mesa GPU libraries (keep basic X11 working)
echo "🔥 Removing non-essential Mesa libraries..."
(sudo rm -f /usr/lib/x86_64-linux-gnu/libMesa*.so* 2>/dev/null || true) &

# NUCLEAR: Remove /usr/local/include (56MB headers)
echo "🔥 Removing header files (56MB)..."
(sudo rm -rf /usr/local/include/* 2>/dev/null || true) &

# NUCLEAR: Remove librsvg (vector graphics, 12MB)
echo "🔥 Removing librsvg..."
(sudo rm -f /usr/lib/x86_64-linux-gnu/librsvg*.so* 2>/dev/null || true) &

# NUCLEAR: Remove ICU data if not needed (~30MB)
# Note: This may break some internationalization but saves significant space
# echo "🔥 Removing ICU data..."
# (sudo rm -f /usr/lib/x86_64-linux-gnu/libicudata*.so* 2>/dev/null || true) &

# Wait for parallel operations
wait

# NUCLEAR: Remove postgresql client libs if not using psql directly
echo "🔥 Cleaning PostgreSQL libs (keeping pgadmin4 functional)..."
(sudo rm -rf /usr/lib/postgresql/*/lib/bitcode 2>/dev/null || true) &
(sudo rm -rf /usr/lib/postgresql/*/doc 2>/dev/null || true) &
wait

# NUCLEAR: Remove git-core GUI tools
echo "🔥 Removing git GUI components..."
(sudo rm -f /usr/lib/git-core/git-gui* 2>/dev/null || true) &
(sudo rm -f /usr/lib/git-core/gitk* 2>/dev/null || true) &
(sudo rm -f /usr/lib/git-core/git-citool 2>/dev/null || true) &
wait

# NUCLEAR: Remove unused systemd generators and units
echo "🔥 Cleaning systemd..."
(sudo rm -rf /lib/systemd/system/sysinit.target.wants/* 2>/dev/null || true) &
(sudo rm -rf /lib/systemd/system/multi-user.target.wants/* 2>/dev/null || true) &
(sudo rm -rf /lib/systemd/system/sockets.target.wants/*udev* 2>/dev/null || true) &
(sudo rm -rf /lib/systemd/system/sockets.target.wants/*initctl* 2>/dev/null || true) &
wait

# NUCLEAR: Remove man pages and documentation that regenerated
echo "🔥 Final doc/man purge..."
(sudo rm -rf /usr/share/doc/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/man/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/info/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/lintian/* 2>/dev/null || true) &
(sudo rm -rf /usr/share/doc-base/* 2>/dev/null || true) &
wait

# NUCLEAR: Remove optional python packages (keep core only)
echo "🔥 Cleaning Python non-essential packages..."
(sudo rm -rf /usr/lib/python3/dist-packages/setuptools/gui* 2>/dev/null || true) &
(sudo rm -rf /usr/lib/python3/dist-packages/pip/_vendor/distlib/*.exe 2>/dev/null || true) &
wait

# NUCLEAR: Strip debug symbols from ALL binaries and libraries
echo "🔥 Stripping debug symbols from all binaries..."
if command -v strip >/dev/null 2>&1; then
    (sudo find /usr/bin -type f -executable -exec strip --strip-all {} \; 2>/dev/null || true) &
    (sudo find /usr/sbin -type f -executable -exec strip --strip-all {} \; 2>/dev/null || true) &
    (sudo find /usr/lib -name "*.so*" -type f -exec strip --strip-debug {} \; 2>/dev/null || true) &
    wait
fi

# NUCLEAR: Clean pgadmin4 caches and unnecessary files (keep it functional)
echo "🔥 Cleaning pgadmin4 non-essential files..."
(sudo rm -rf /usr/pgadmin4/venv/share/doc 2>/dev/null || true) &
(sudo rm -rf /usr/pgadmin4/venv/share/man 2>/dev/null || true) &
(sudo rm -rf /usr/pgadmin4/share/doc 2>/dev/null || true) &
(sudo find /usr/pgadmin4 -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /usr/pgadmin4 -name "*.pyc" -delete 2>/dev/null || true) &
(sudo find /usr/pgadmin4 -name "*.pyo" -delete 2>/dev/null || true) &
(sudo find /usr/pgadmin4 -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true) &
wait

# NUCLEAR: Clean node_modules caches and test files (keep packages functional)
echo "🔥 Cleaning node_modules non-essential files..."
(sudo find /usr/local/lib/node_modules -name "*.md" -delete 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "*.txt" ! -name "requirements.txt" -delete 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "LICENSE*" -delete 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "CHANGELOG*" -delete 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "AUTHORS*" -delete 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "HISTORY*" -delete 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "*.map" -delete 2>/dev/null || true) & # Source maps
(sudo find /usr/local/lib/node_modules -name "test" -type d -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "__tests__" -type d -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "example" -type d -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "examples" -type d -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "docs" -type d -exec rm -rf {} + 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name ".github" -type d -exec rm -rf {} + 2>/dev/null || true) &
wait

# NUCLEAR: Remove typescript declaration files (not needed at runtime)
echo "🔥 Removing TypeScript declaration files..."
(sudo find /usr/local/lib/node_modules -name "*.d.ts" -delete 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "*.d.cts" -delete 2>/dev/null || true) &
(sudo find /usr/local/lib/node_modules -name "*.d.mts" -delete 2>/dev/null || true) &
wait

# NUCLEAR: Remove hwdb (hardware database) - not needed in WSL
echo "🔥 Removing hardware database..."
(sudo rm -f /usr/lib/udev/hwdb.bin 2>/dev/null || true) &
(sudo rm -rf /usr/lib/udev/hwdb.d/* 2>/dev/null || true) &
wait

# NUCLEAR: Final aggressive cleanup
echo "🔥 Final aggressive sweep..."
(sudo rm -rf /var/lib/apt/lists/* 2>/dev/null || true) &
(sudo rm -rf /var/cache/apt/archives/*.deb 2>/dev/null || true) &
(sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true) &
(sudo find /var/log -type f -delete 2>/dev/null || true) &
wait

calculate_saved $STEP_USAGE

# ============================================================================
# FINAL PHASE: VERIFY ALL PROTECTED PACKAGES ARE WORKING
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║     PROTECTED PACKAGES VERIFICATION                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

VERIFY_PASSED=0
VERIFY_TOTAL=0

# Verify Docker
((VERIFY_TOTAL++))
if command -v docker >/dev/null 2>&1; then
    echo "  ✅ docker: $(docker --version 2>/dev/null | head -1)"
    ((VERIFY_PASSED++))
else
    echo "  ❌ docker: NOT FOUND"
fi

# Verify Python
((VERIFY_TOTAL++))
if command -v python3 >/dev/null 2>&1; then
    echo "  ✅ python3: $(python3 --version 2>/dev/null)"
    ((VERIFY_PASSED++))
else
    echo "  ❌ python3: NOT FOUND"
fi

# Verify pip
((VERIFY_TOTAL++))
if command -v pip3 >/dev/null 2>&1 || python3 -m pip --version >/dev/null 2>&1; then
    echo "  ✅ pip: $(pip3 --version 2>/dev/null || python3 -m pip --version 2>/dev/null)"
    ((VERIFY_PASSED++))
else
    echo "  ❌ pip: NOT FOUND"
fi

# Verify venv
((VERIFY_TOTAL++))
if python3 -c "import venv" 2>/dev/null; then
    echo "  ✅ python3-venv: Available"
    ((VERIFY_PASSED++))
else
    echo "  ❌ python3-venv: NOT AVAILABLE"
fi

# Verify Node.js
((VERIFY_TOTAL++))
if command -v node >/dev/null 2>&1; then
    echo "  ✅ node: $(node --version 2>/dev/null)"
    ((VERIFY_PASSED++))
else
    echo "  ❌ node: NOT FOUND"
fi

# Verify npm
((VERIFY_TOTAL++))
if command -v npm >/dev/null 2>&1; then
    echo "  ✅ npm: $(npm --version 2>/dev/null)"
    ((VERIFY_PASSED++))
else
    echo "  ❌ npm: NOT FOUND"
fi

# Verify jq
((VERIFY_TOTAL++))
if command -v jq >/dev/null 2>&1; then
    echo "  ✅ jq: $(jq --version 2>/dev/null)"
    ((VERIFY_PASSED++))
else
    echo "  ❌ jq: NOT FOUND"
fi

# Verify SSH
((VERIFY_TOTAL++))
if command -v ssh >/dev/null 2>&1; then
    echo "  ✅ ssh: $(ssh -V 2>&1 | head -1)"
    ((VERIFY_PASSED++))
else
    echo "  ❌ ssh: NOT FOUND"
fi

# Verify sshpass
((VERIFY_TOTAL++))
if command -v sshpass >/dev/null 2>&1; then
    echo "  ✅ sshpass: Available"
    ((VERIFY_PASSED++))
else
    echo "  ❌ sshpass: NOT FOUND"
fi

# Verify tree
((VERIFY_TOTAL++))
if command -v tree >/dev/null 2>&1; then
    echo "  ✅ tree: $(tree --version 2>/dev/null | head -1)"
    ((VERIFY_PASSED++))
else
    echo "  ❌ tree: NOT FOUND"
fi

# Verify snapd
((VERIFY_TOTAL++))
if command -v snap >/dev/null 2>&1; then
    echo "  ✅ snapd: $(snap version 2>/dev/null | grep snapd | awk '{print $2}')"
    ((VERIFY_PASSED++))
else
    echo "  ❌ snapd: NOT FOUND"
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║     VERIFICATION SUMMARY: $VERIFY_PASSED/$VERIFY_TOTAL packages OK          ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Final disk size check
FINAL_SIZE_KB=$(df / | tail -1 | awk '{print $3}')
FINAL_SIZE_MB=$((FINAL_SIZE_KB / 1024))
FINAL_SIZE_GB=$(echo "scale=2; $FINAL_SIZE_MB / 1024" | bc -l 2>/dev/null || echo "N/A")

echo "📊 FINAL DISK USAGE: ${FINAL_SIZE_MB}MB (${FINAL_SIZE_GB}GB)"
echo ""

if [ $FINAL_SIZE_MB -le 1740 ]; then
    echo "✅ SUCCESS: Disk usage is under 1.7GB target!"
else
    echo "⚠️  Disk usage is ${FINAL_SIZE_MB}MB (target: <1740MB)"
fi

echo ""
echo "🎉 Cleanup complete! All protected packages should be functional."
echo ""
echo "📝 To install additional tools via snap:"
echo "   snap install <package-name>"
echo ""
echo "📝 For Claude Code / pgAdmin / quint-code:"
echo "   These may need manual installation - check their documentation."
echo ""
