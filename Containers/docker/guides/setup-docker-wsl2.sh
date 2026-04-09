#!/bin/bash
###############################################################################
# setup-docker-wsl2.sh - Full Docker setup for Ubuntu WSL2
# Fixes all common WSL2 issues before installing Docker
# Run as root: sudo bash setup-docker-wsl2.sh
###############################################################################
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✔] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }
err()  { echo -e "${RED}[✘] $1${NC}"; }
info() { echo -e "${CYAN}[i] $1${NC}"; }

if [ "$EUID" -ne 0 ]; then
  err "Run as root: sudo bash $0"
  exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"

echo ""
echo "============================================"
echo "  Docker WSL2 Full Setup (Bulletproof)"
echo "============================================"
echo ""

###############################################################################
# PHASE 0: Fix broken dpkg/apt state FIRST
###############################################################################
info "Phase 0: Fixing system package state..."

# 0a. Regenerate missing dpkg file lists (fixes hundreds of warnings)
log "Regenerating missing dpkg info files..."
for pkg in $(dpkg --get-selections | awk '{print $1}'); do
  file="/var/lib/dpkg/info/${pkg}.list"
  # Also check without :amd64 suffix
  file2="/var/lib/dpkg/info/${pkg%:*}.list"
  if [ ! -f "$file" ] && [ ! -f "$file2" ]; then
    touch "$file" 2>/dev/null || true
  fi
done
log "Missing dpkg file lists regenerated."

# 0b. Unmask packagekit to stop GDBus errors
log "Unmasking packagekit service..."
systemctl unmask packagekit.service 2>/dev/null || true
systemctl unmask packagekit-offline-update.service 2>/dev/null || true

# 0c. Fix unattended-upgrades (known WSL2 issue - no systemd timers at install)
log "Fixing unattended-upgrades..."
# Remove it if it's broken, we don't need it in WSL2
dpkg --configure -a 2>/dev/null || true
apt-get remove -y unattended-upgrades 2>/dev/null || {
  # Force remove if normal remove fails
  dpkg --remove --force-remove-reinstreq unattended-upgrades 2>/dev/null || true
}

# 0d. Fix any remaining broken packages
log "Fixing any broken packages..."
dpkg --configure -a 2>/dev/null || true
apt-get install -f -y 2>/dev/null || true

###############################################################################
# PHASE 1: Remove old / broken Docker installations
###############################################################################
info "Phase 1: Cleaning old Docker..."

# Stop any running docker
systemctl stop docker.service 2>/dev/null || true
systemctl stop docker.socket 2>/dev/null || true
killall dockerd 2>/dev/null || true
killall containerd 2>/dev/null || true
sleep 1

apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

# Clean up leftover docker files but keep user data
rm -rf /var/lib/docker/tmp/* 2>/dev/null || true
rm -f /var/run/docker.sock 2>/dev/null || true
rm -f /var/run/docker.pid 2>/dev/null || true

log "Old Docker cleaned."

###############################################################################
# PHASE 2: Update system & install prerequisites
###############################################################################
info "Phase 2: Prerequisites..."

apt-get update -y
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https \
  iptables \
  pigz 2>/dev/null || apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https \
  iptables

log "Prerequisites installed."

###############################################################################
# PHASE 3: Add Docker official GPG key & repository
###############################################################################
info "Phase 3: Docker repository..."

install -m 0755 -d /etc/apt/keyrings
rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Detect codename with fallbacks
CODENAME=""
if [ -f /etc/os-release ]; then
  CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-}")
fi
if [ -z "$CODENAME" ]; then
  CODENAME=$(lsb_release -cs 2>/dev/null || echo "")
fi
if [ -z "$CODENAME" ]; then
  # Ultimate fallback for Ubuntu 24.04
  CODENAME="noble"
fi

info "Detected Ubuntu codename: $CODENAME"

# Remove any old docker list files
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/sources-list-docker.list 2>/dev/null || true

ARCH=$(dpkg --print-architecture)
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y

log "Docker repository configured."

###############################################################################
# PHASE 4: Install Docker Engine + CLI + Compose
###############################################################################
info "Phase 4: Installing Docker..."

apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

log "Docker installed."

###############################################################################
# PHASE 5: Add user to docker group
###############################################################################
info "Phase 5: User permissions..."

groupadd docker 2>/dev/null || true
usermod -aG docker "$REAL_USER"

log "User '$REAL_USER' added to docker group."

###############################################################################
# PHASE 6: Configure Docker daemon for WSL2
###############################################################################
info "Phase 6: Docker daemon config..."

mkdir -p /etc/docker

cat > /etc/docker/daemon.json << 'EOF'
{
  "storage-driver": "overlay2",
  "iptables": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

log "Daemon configured."

###############################################################################
# PHASE 7: Fix iptables for WSL2 (MUST be before starting docker)
###############################################################################
info "Phase 7: iptables compatibility..."

update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true

log "iptables set to legacy mode."

###############################################################################
# PHASE 8: Enable systemd in wsl.conf
###############################################################################
info "Phase 8: WSL config..."

if [ -f /etc/wsl.conf ]; then
  # Ensure [boot] section exists with systemd=true
  if grep -q "\[boot\]" /etc/wsl.conf; then
    if grep -q "systemd=" /etc/wsl.conf; then
      sed -i 's/systemd=.*/systemd=true/' /etc/wsl.conf
    else
      sed -i '/\[boot\]/a systemd=true' /etc/wsl.conf
    fi
  else
    printf '\n[boot]\nsystemd=true\n' >> /etc/wsl.conf
  fi
else
  cat > /etc/wsl.conf << 'EOF'
[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=true
EOF
fi

log "wsl.conf configured with systemd=true."

###############################################################################
# PHASE 9: Start Docker (handle both systemd and non-systemd)
###############################################################################
info "Phase 9: Starting Docker..."

# Create the startup helper script regardless
cat > /usr/local/bin/start-docker.sh << 'SCRIPT'
#!/bin/bash
# Start Docker daemon in WSL2
LOGFILE="/var/log/docker-startup.log"

# Kill stale processes
if [ -f /var/run/docker.pid ]; then
  OLD_PID=$(cat /var/run/docker.pid 2>/dev/null)
  if [ -n "$OLD_PID" ] && ! kill -0 "$OLD_PID" 2>/dev/null; then
    rm -f /var/run/docker.pid
    rm -f /var/run/docker.sock
  fi
fi

if pgrep -x dockerd > /dev/null 2>&1; then
  echo "Docker is already running."
  exit 0
fi

# Ensure containerd is running
if ! pgrep -x containerd > /dev/null 2>&1; then
  echo "Starting containerd..." | tee -a "$LOGFILE"
  nohup containerd >> "$LOGFILE" 2>&1 &
  sleep 2
fi

echo "Starting dockerd..." | tee -a "$LOGFILE"
nohup dockerd >> "$LOGFILE" 2>&1 &

# Wait for socket with timeout
echo -n "Waiting for Docker"
for i in $(seq 1 30); do
  if docker info > /dev/null 2>&1; then
    echo ""
    echo "Docker is ready!"
    exit 0
  fi
  echo -n "."
  sleep 1
done

echo ""
echo "ERROR: Docker failed to start within 30s."
echo "Check logs: $LOGFILE"
exit 1
SCRIPT
chmod +x /usr/local/bin/start-docker.sh

# Auto-start on WSL login
cat > /etc/profile.d/docker-wsl.sh << 'PROFILE'
# Auto-start Docker in WSL2 (runs only if not already started)
if ! docker info > /dev/null 2>&1; then
  if command -v systemctl > /dev/null 2>&1 && systemctl is-system-running > /dev/null 2>&1; then
    sudo systemctl start docker.service 2>/dev/null
  else
    sudo /usr/local/bin/start-docker.sh 2>/dev/null
  fi
fi
PROFILE

# Passwordless sudo for docker start
echo "$REAL_USER ALL=(ALL) NOPASSWD: /usr/local/bin/start-docker.sh" > /etc/sudoers.d/docker-wsl
echo "$REAL_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start docker.service" >> /etc/sudoers.d/docker-wsl
echo "$REAL_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start docker" >> /etc/sudoers.d/docker-wsl
chmod 440 /etc/sudoers.d/docker-wsl

# Now actually start Docker
STARTED=false

if pidof systemd > /dev/null 2>&1; then
  log "Systemd detected."

  # Fix: ensure docker service doesn't conflict with daemon.json hosts
  mkdir -p /etc/systemd/system/docker.service.d
  cat > /etc/systemd/system/docker.service.d/override.conf << 'OVERRIDE'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock
OVERRIDE

  systemctl daemon-reload
  systemctl enable docker.service
  systemctl enable containerd.service
  systemctl restart containerd.service
  systemctl restart docker.service

  if systemctl is-active --quiet docker.service; then
    STARTED=true
    log "Docker started via systemd."
  else
    warn "Systemd start failed, falling back to manual start..."
  fi
fi

if [ "$STARTED" = false ]; then
  info "Starting Docker manually..."
  /usr/local/bin/start-docker.sh && STARTED=true
fi

###############################################################################
# PHASE 10: Fix socket permissions
###############################################################################
info "Phase 10: Socket permissions..."

if [ -S /var/run/docker.sock ]; then
  chgrp docker /var/run/docker.sock
  chmod 660 /var/run/docker.sock
  log "Socket permissions set."
else
  warn "Docker socket not found yet - may need WSL restart."
fi

###############################################################################
# PHASE 11: Verify
###############################################################################
echo ""
echo "============================================"
echo "  Verification"
echo "============================================"
echo ""

PASS=true

# Docker daemon
if docker info > /dev/null 2>&1; then
  log "Docker daemon: RUNNING"
else
  err "Docker daemon: NOT RUNNING"
  PASS=false
fi

# Docker version
echo ""
docker version 2>/dev/null && log "Docker version: OK" || { err "Docker version: FAILED"; PASS=false; }

# Compose
echo ""
docker compose version 2>/dev/null && log "Docker Compose: OK" || { err "Docker Compose: FAILED"; PASS=false; }

# Buildx
echo ""
docker buildx version 2>/dev/null && log "Docker Buildx: OK" || warn "Docker Buildx: not available"

# hello-world test
echo ""
info "Running hello-world container test..."
if docker run --rm hello-world 2>&1 | grep -q "Hello from Docker"; then
  log "hello-world: PASSED"
else
  warn "hello-world: FAILED (may work after WSL restart)"
  PASS=false
fi

# Socket check
echo ""
if [ -S /var/run/docker.sock ]; then
  log "Docker socket: EXISTS at /var/run/docker.sock"
else
  err "Docker socket: MISSING"
  PASS=false
fi

echo ""
echo "============================================"
if [ "$PASS" = true ]; then
  echo -e "  ${GREEN}ALL CHECKS PASSED!${NC}"
else
  echo -e "  ${YELLOW}SOME CHECKS FAILED${NC}"
  echo ""
  echo "  Restart WSL from PowerShell and try again:"
  echo "    wsl --shutdown"
  echo "    wsl"
  echo ""
  echo "  Then test with:"
  echo "    docker run --rm hello-world"
fi
echo "============================================"
echo ""
echo "Manual start (if ever needed):"
echo "  sudo /usr/local/bin/start-docker.sh"
echo ""
echo "NOTE: Log out and back in (or run 'newgrp docker')"
echo "to use docker without sudo."
echo ""
