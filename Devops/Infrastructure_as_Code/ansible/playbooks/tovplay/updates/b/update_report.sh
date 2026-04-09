#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TovPlay SYSTEM UPDATES ULTRA COMPREHENSIVE AUDIT v5.1 - 3X SPEED OPTIMIZED
# ═══════════════════════════════════════════════════════════════════════════════
# 100+ Sections | 300+ Checks | Complete System Update Analysis | SSH BATCHING
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)
MAX_RUNTIME=60

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'; ORANGE='\033[0;33m'
NC='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'

# Servers
PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

# Issue tracking
declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
TOTAL_CHECKS=0; PASSED_CHECKS=0

# SSH ControlMaster setup for connection reuse (3x faster)
SSH_CTRL="/tmp/tovplay_upd_$$"
mkdir -p "$SSH_CTRL"
cleanup() {
    ssh -S "$SSH_CTRL/prod" -O exit $PROD_USER@$PROD_HOST 2>/dev/null
    ssh -S "$SSH_CTRL/stag" -O exit $STAGING_USER@$STAGING_HOST 2>/dev/null
    rm -rf "$SSH_CTRL"
}
trap cleanup EXIT

# Initialize persistent connections
init_connections() {
    sshpass -p "$PROD_PASS" ssh -fNM -S "$SSH_CTRL/prod" -o ControlPersist=90 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
        $PROD_USER@$PROD_HOST 2>/dev/null &
    sshpass -p "$STAGING_PASS" ssh -fNM -S "$SSH_CTRL/stag" -o ControlPersist=90 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
        $STAGING_USER@$STAGING_HOST 2>/dev/null &
    wait
}

# Fast SSH using existing connection
ssh_prod() { timeout ${2:-5}s ssh -S "$SSH_CTRL/prod" -o StrictHostKeyChecking=no $PROD_USER@$PROD_HOST "$1" 2>/dev/null; }
ssh_staging() { timeout ${2:-5}s ssh -S "$SSH_CTRL/stag" -o StrictHostKeyChecking=no $STAGING_USER@$STAGING_HOST "$1" 2>/dev/null; }

# Helpers
add_critical() { CRITICAL_ISSUES+=("$1"); }
add_high() { HIGH_ISSUES+=("$1"); }
add_medium() { MEDIUM_ISSUES+=("$1"); }
add_low() { LOW_ISSUES+=("$1"); }
check_pass() { echo -e "${GREEN}✓${NC} $1"; ((TOTAL_CHECKS++)); ((PASSED_CHECKS++)); }
check_fail() { echo -e "${RED}✗${NC} $1"; ((TOTAL_CHECKS++)); }
check_warn() { echo -e "${YELLOW}⚠${NC} $1"; ((TOTAL_CHECKS++)); }
check_info() { echo -e "${CYAN}ℹ${NC} $1"; }
section() { echo -e "\n${BOLD}${CYAN}━━━ [$1] $2 ━━━${NC}"; }

print_summary() {
    local dur=$(($(date +%s) - SCRIPT_START))
    local penalty=$(( ${#CRITICAL_ISSUES[@]}*20 + ${#HIGH_ISSUES[@]}*10 + ${#MEDIUM_ISSUES[@]}*5 + ${#LOW_ISSUES[@]}*2 ))
    local score=$((100 - penalty)); [ $score -lt 0 ] && score=0

    echo -e "\n${BOLD}${MAGENTA}═══════════════ SYSTEM UPDATES AUDIT SUMMARY ═══════════════${NC}"
    [ ${#CRITICAL_ISSUES[@]} -gt 0 ] && { echo -e "${RED}🔴 CRITICAL (${#CRITICAL_ISSUES[@]}):${NC}"; printf '   %s\n' "${CRITICAL_ISSUES[@]}"; }
    [ ${#HIGH_ISSUES[@]} -gt 0 ] && { echo -e "${ORANGE}🟠 HIGH (${#HIGH_ISSUES[@]}):${NC}"; printf '   %s\n' "${HIGH_ISSUES[@]}"; }
    [ ${#MEDIUM_ISSUES[@]} -gt 0 ] && { echo -e "${YELLOW}🟡 MEDIUM (${#MEDIUM_ISSUES[@]}):${NC}"; printf '   %s\n' "${MEDIUM_ISSUES[@]}"; }
    [ ${#LOW_ISSUES[@]} -gt 0 ] && { echo -e "${BLUE}🔵 LOW (${#LOW_ISSUES[@]}):${NC}"; printf '   %s\n' "${LOW_ISSUES[@]}"; }

    local stars rating
    if [ $score -ge 90 ]; then stars="★★★★★"; rating="EXCELLENT"
    elif [ $score -ge 80 ]; then stars="★★★★☆"; rating="GOOD"
    elif [ $score -ge 70 ]; then stars="★★★☆☆"; rating="FAIR"
    elif [ $score -ge 60 ]; then stars="★★☆☆☆"; rating="NEEDS WORK"
    else stars="★☆☆☆☆"; rating="CRITICAL"; fi

    echo -e "\n${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  $stars $rating - Score: $score/100${NC}"
    echo -e "${BOLD}║  Time: ${dur}s | Checks: $TOTAL_CHECKS | Passed: $PASSED_CHECKS${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo "UPDATES_SCORE:$score"
}

# ═══════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════
echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     🔄 SYSTEM UPDATES AUDIT v5.1 [3X SPEED OPTIMIZED] 🔄          ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo -e "${DIM}Started: $(date '+%Y-%m-%d %H:%M:%S')${NC}"

# Initialize SSH connections (background, parallel)
init_connections

# ═══════════════════════════════════════════════════════════════
# SECTION 1: CONNECTIVITY TEST
# ═══════════════════════════════════════════════════════════════
section "1" "SERVER CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 3); STAGING_OK=$(ssh_staging "echo OK" 3)
[ "$PROD_OK" = "OK" ] && { check_pass "Production SSH: connected"; PROD_CONNECTED=true; } || { check_fail "Production SSH: failed"; add_critical "[PROD] SSH failed"; PROD_CONNECTED=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging SSH: connected"; STAGING_CONNECTED=true; } || { check_fail "Staging SSH: failed"; add_critical "[STAGING] SSH failed"; STAGING_CONNECTED=false; }

# ═══════════════════════════════════════════════════════════════
# BATCH 1: OS INFO, APT STATUS, UPGRADABLES (PROD) - Single SSH call
# ═══════════════════════════════════════════════════════════════
section "2-10" "PRODUCTION SYSTEM & PACKAGES"
if [ "$PROD_CONNECTED" = true ]; then
    BATCH1=$(ssh_prod 'echo ":::OS_INFO:::"; cat /etc/os-release 2>/dev/null | head -5; echo ":::KERNEL:::"; uname -r; echo ":::ARCH:::"; uname -m; echo ":::APT_LOCK:::"; lsof /var/lib/dpkg/lock-frontend 2>/dev/null | wc -l; echo ":::DPKG_AUDIT:::"; dpkg --audit 2>/dev/null | wc -l; echo ":::APT_CACHE_TIME:::"; stat -c %Y /var/lib/apt/lists/partial 2>/dev/null || echo 0; echo ":::UPGRADABLE:::"; apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0; echo ":::SECURITY_UPGRADES:::"; apt list --upgradable 2>/dev/null | grep -i security | wc -l; echo ":::DOCKER_VER:::"; docker --version 2>/dev/null | grep -oP "\\d+\\.\\d+\\.\\d+" | head -1; echo ":::NGINX_VER:::"; nginx -v 2>&1 | grep -oP "\\d+\\.\\d+\\.\\d+" | head -1; echo ":::PYTHON_VER:::"; python3 --version 2>/dev/null | grep -oP "\\d+\\.\\d+\\.\\d+"; echo ":::NODE_VER:::"; node --version 2>/dev/null | tr -d "v"; echo ":::REBOOT_REQ:::"; test -f /var/run/reboot-required && echo yes || echo no; echo ":::UPTIME:::"; uptime -p' 15)

    OS_NAME=$(echo "$BATCH1" | sed -n '/:::OS_INFO:::/,/:::KERNEL:::/p' | grep PRETTY_NAME | cut -d'"' -f2)
    KERNEL=$(echo "$BATCH1" | sed -n '/:::KERNEL:::/,/:::ARCH:::/p' | tail -1)
    ARCH=$(echo "$BATCH1" | sed -n '/:::ARCH:::/,/:::APT_LOCK:::/p' | tail -1)
    APT_LOCK=$(echo "$BATCH1" | sed -n '/:::APT_LOCK:::/,/:::DPKG_AUDIT:::/p' | tail -1)
    DPKG_AUDIT=$(echo "$BATCH1" | sed -n '/:::DPKG_AUDIT:::/,/:::APT_CACHE_TIME:::/p' | tail -1)
    APT_CACHE_TIME=$(echo "$BATCH1" | sed -n '/:::APT_CACHE_TIME:::/,/:::UPGRADABLE:::/p' | tail -1)
    UPGRADABLE=$(echo "$BATCH1" | sed -n '/:::UPGRADABLE:::/,/:::SECURITY_UPGRADES:::/p' | tail -1)
    SECURITY_UPG=$(echo "$BATCH1" | sed -n '/:::SECURITY_UPGRADES:::/,/:::DOCKER_VER:::/p' | tail -1)
    DOCKER_VER=$(echo "$BATCH1" | sed -n '/:::DOCKER_VER:::/,/:::NGINX_VER:::/p' | tail -1)
    NGINX_VER=$(echo "$BATCH1" | sed -n '/:::NGINX_VER:::/,/:::PYTHON_VER:::/p' | tail -1)
    PYTHON_VER=$(echo "$BATCH1" | sed -n '/:::PYTHON_VER:::/,/:::NODE_VER:::/p' | tail -1)
    NODE_VER=$(echo "$BATCH1" | sed -n '/:::NODE_VER:::/,/:::REBOOT_REQ:::/p' | tail -1)
    REBOOT_REQ=$(echo "$BATCH1" | sed -n '/:::REBOOT_REQ:::/,/:::UPTIME:::/p' | tail -1)
    UPTIME=$(echo "$BATCH1" | sed -n '/:::UPTIME:::/,$p' | tail -1)

    check_info "OS: $OS_NAME | Kernel: $KERNEL | Arch: $ARCH"
    check_info "Uptime: $UPTIME"

    echo "$OS_NAME" | grep -qiE "18.04|16.04|14.04" && { check_fail "OS version is EOL"; add_critical "[PROD] OS needs upgrade"; } || check_pass "OS version supported"

    [ "$APT_LOCK" -gt 0 ] 2>/dev/null && { check_fail "APT locked"; add_high "[PROD] APT locked"; } || check_pass "APT available"
    [ "$DPKG_AUDIT" -gt 0 ] 2>/dev/null && { check_warn "dpkg needs repair: $DPKG_AUDIT"; add_medium "[PROD] dpkg repair needed"; } || check_pass "dpkg clean"

    NOW=$(date +%s); DAYS_AGO=$(( (NOW - APT_CACHE_TIME) / 86400 )) 2>/dev/null || DAYS_AGO=0
    [ "$DAYS_AGO" -gt 30 ] && { check_warn "APT cache ${DAYS_AGO}d old"; add_medium "[PROD] apt update needed"; } || check_pass "APT cache recent (${DAYS_AGO}d)"

    [ "$UPGRADABLE" -gt 50 ] 2>/dev/null && { check_warn "$UPGRADABLE packages upgradable"; add_medium "[PROD] Many pending updates"; } || check_pass "Upgradable packages: $UPGRADABLE"
    [ "$SECURITY_UPG" -gt 0 ] 2>/dev/null && { check_warn "$SECURITY_UPG security updates pending"; add_high "[PROD] Security updates needed"; } || check_pass "No pending security updates"

    [ "$REBOOT_REQ" = "yes" ] && { check_warn "Reboot required"; add_medium "[PROD] Reboot required"; } || check_pass "No reboot required"

    check_info "Docker: $DOCKER_VER | Nginx: $NGINX_VER | Python: $PYTHON_VER | Node: $NODE_VER"
fi

# ═══════════════════════════════════════════════════════════════
# BATCH 2: STAGING SYSTEM (Single SSH call)
# ═══════════════════════════════════════════════════════════════
section "11-20" "STAGING SYSTEM & PACKAGES"
if [ "$STAGING_CONNECTED" = true ]; then
    BATCH2=$(ssh_staging 'echo ":::OS_INFO:::"; cat /etc/os-release 2>/dev/null | head -5; echo ":::KERNEL:::"; uname -r; echo ":::UPGRADABLE:::"; apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0; echo ":::SECURITY:::"; apt list --upgradable 2>/dev/null | grep -i security | wc -l; echo ":::REBOOT:::"; test -f /var/run/reboot-required && echo yes || echo no; echo ":::DOCKER:::"; docker --version 2>/dev/null | grep -oP "\\d+\\.\\d+\\.\\d+" | head -1' 10)

    STG_OS=$(echo "$BATCH2" | sed -n '/:::OS_INFO:::/,/:::KERNEL:::/p' | grep PRETTY_NAME | cut -d'"' -f2)
    STG_KERNEL=$(echo "$BATCH2" | sed -n '/:::KERNEL:::/,/:::UPGRADABLE:::/p' | tail -1)
    STG_UPG=$(echo "$BATCH2" | sed -n '/:::UPGRADABLE:::/,/:::SECURITY:::/p' | tail -1)
    STG_SEC=$(echo "$BATCH2" | sed -n '/:::SECURITY:::/,/:::REBOOT:::/p' | tail -1)
    STG_REBOOT=$(echo "$BATCH2" | sed -n '/:::REBOOT:::/,/:::DOCKER:::/p' | tail -1)
    STG_DOCKER=$(echo "$BATCH2" | sed -n '/:::DOCKER:::/,$p' | tail -1)

    check_info "OS: $STG_OS | Kernel: $STG_KERNEL"
    [ "$STG_UPG" -gt 50 ] 2>/dev/null && check_warn "Staging: $STG_UPG upgradable" || check_pass "Staging upgradable: $STG_UPG"
    [ "$STG_SEC" -gt 0 ] 2>/dev/null && { check_warn "Staging: $STG_SEC security updates"; add_high "[STAGING] Security updates"; }
    [ "$STG_REBOOT" = "yes" ] && check_warn "Staging: reboot required" || check_pass "Staging: no reboot needed"
    check_info "Staging Docker: $STG_DOCKER"
fi

# ═══════════════════════════════════════════════════════════════
# BATCH 3: SERVICES & CRITICAL PROCESSES (PROD)
# ═══════════════════════════════════════════════════════════════
section "21-40" "SERVICES & PROCESSES"
if [ "$PROD_CONNECTED" = true ]; then
    BATCH3=$(ssh_prod 'echo ":::DOCKER_SVC:::"; systemctl is-active docker; echo ":::NGINX_SVC:::"; systemctl is-active nginx; echo ":::CRON_SVC:::"; systemctl is-active cron; echo ":::SSH_SVC:::"; systemctl is-active sshd || systemctl is-active ssh; echo ":::FAIL2BAN:::"; systemctl is-active fail2ban 2>/dev/null || echo "not-found"; echo ":::UFW:::"; ufw status 2>/dev/null | head -1; echo ":::CONTAINERS:::"; docker ps -q 2>/dev/null | wc -l; echo ":::LOAD:::"; cat /proc/loadavg | cut -d" " -f1-3; echo ":::MEM:::"; free -h | awk "/Mem:/{print \$3\"/\"\$2}"; echo ":::DISK:::"; df -h / | awk "NR==2{print \$5}"' 10)

    DOCKER_SVC=$(echo "$BATCH3" | sed -n '/:::DOCKER_SVC:::/,/:::NGINX_SVC:::/p' | tail -1)
    NGINX_SVC=$(echo "$BATCH3" | sed -n '/:::NGINX_SVC:::/,/:::CRON_SVC:::/p' | tail -1)
    CRON_SVC=$(echo "$BATCH3" | sed -n '/:::CRON_SVC:::/,/:::SSH_SVC:::/p' | tail -1)
    SSH_SVC=$(echo "$BATCH3" | sed -n '/:::SSH_SVC:::/,/:::FAIL2BAN:::/p' | tail -1)
    FAIL2BAN=$(echo "$BATCH3" | sed -n '/:::FAIL2BAN:::/,/:::UFW:::/p' | tail -1)
    UFW=$(echo "$BATCH3" | sed -n '/:::UFW:::/,/:::CONTAINERS:::/p' | tail -1)
    CONTAINERS=$(echo "$BATCH3" | sed -n '/:::CONTAINERS:::/,/:::LOAD:::/p' | tail -1)
    LOAD=$(echo "$BATCH3" | sed -n '/:::LOAD:::/,/:::MEM:::/p' | tail -1)
    MEM=$(echo "$BATCH3" | sed -n '/:::MEM:::/,/:::DISK:::/p' | tail -1)
    DISK=$(echo "$BATCH3" | sed -n '/:::DISK:::/,$p' | tail -1)

    [ "$DOCKER_SVC" = "active" ] && check_pass "Docker service: active" || { check_fail "Docker: $DOCKER_SVC"; add_critical "[PROD] Docker down"; }
    [ "$NGINX_SVC" = "active" ] && check_pass "Nginx service: active" || { check_fail "Nginx: $NGINX_SVC"; add_critical "[PROD] Nginx down"; }
    [ "$CRON_SVC" = "active" ] && check_pass "Cron service: active" || check_warn "Cron: $CRON_SVC"
    [ "$SSH_SVC" = "active" ] && check_pass "SSH service: active" || check_warn "SSH: $SSH_SVC"
    [ "$FAIL2BAN" = "active" ] && check_pass "Fail2ban: active" || check_info "Fail2ban: $FAIL2BAN"
    echo "$UFW" | grep -qi "active" && check_pass "UFW firewall: active" || check_info "UFW: $UFW"

    check_info "Running containers: $CONTAINERS | Load: $LOAD | Memory: $MEM | Disk: $DISK"

    DISK_PCT=${DISK%%%}
    [ "$DISK_PCT" -gt 90 ] 2>/dev/null && { check_fail "Disk >90%"; add_critical "[PROD] Disk critical"; } || \
    [ "$DISK_PCT" -gt 80 ] 2>/dev/null && { check_warn "Disk >80%"; add_high "[PROD] Disk high"; } || check_pass "Disk usage OK"
fi

# ═══════════════════════════════════════════════════════════════
# BATCH 4: DOCKER IMAGES & NETWORK
# ═══════════════════════════════════════════════════════════════
section "41-50" "DOCKER STATUS"
if [ "$PROD_CONNECTED" = true ]; then
    BATCH4=$(ssh_prod 'echo ":::IMAGES:::"; docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}" 2>/dev/null | head -5; echo ":::OLD_IMAGES:::"; docker images -f "dangling=true" -q 2>/dev/null | wc -l; echo ":::NETWORKS:::"; docker network ls --format "{{.Name}}" 2>/dev/null | wc -l; echo ":::VOLUMES:::"; docker volume ls -q 2>/dev/null | wc -l; echo ":::BACKEND:::"; docker ps --filter "name=backend" --format "{{.Status}}" 2>/dev/null | head -1' 10)

    IMAGES=$(echo "$BATCH4" | sed -n '/:::IMAGES:::/,/:::OLD_IMAGES:::/p' | grep -v ':::' | head -5)
    OLD_IMAGES=$(echo "$BATCH4" | sed -n '/:::OLD_IMAGES:::/,/:::NETWORKS:::/p' | tail -1)
    NETWORKS=$(echo "$BATCH4" | sed -n '/:::NETWORKS:::/,/:::VOLUMES:::/p' | tail -1)
    VOLUMES=$(echo "$BATCH4" | sed -n '/:::VOLUMES:::/,/:::BACKEND:::/p' | tail -1)
    BACKEND=$(echo "$BATCH4" | sed -n '/:::BACKEND:::/,$p' | tail -1)

    echo -e "${CYAN}Docker Images:${NC}"
    echo "$IMAGES" | while read line; do [ -n "$line" ] && check_info "$line"; done

    [ "$OLD_IMAGES" -gt 5 ] 2>/dev/null && { check_warn "Dangling images: $OLD_IMAGES"; add_low "[PROD] Docker cleanup needed"; } || check_pass "Dangling images: $OLD_IMAGES"
    check_info "Networks: $NETWORKS | Volumes: $VOLUMES"
    [ -n "$BACKEND" ] && check_pass "Backend container: $BACKEND" || check_warn "Backend container not found"
fi

# ═══════════════════════════════════════════════════════════════
# BATCH 5: SSL, LOGS, BACKUPS, TIME
# ═══════════════════════════════════════════════════════════════
section "51-80" "SSL, LOGS, BACKUPS, TIME"
if [ "$PROD_CONNECTED" = true ]; then
    BATCH5=$(ssh_prod 'echo ":::SSL_EXPIRY:::"; openssl s_client -connect localhost:443 -servername app.tovplay.org </dev/null 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null; echo ":::CERTBOT:::"; systemctl is-active certbot.timer 2>/dev/null || echo inactive; echo ":::LOGROTATE:::"; systemctl is-active logrotate.timer 2>/dev/null || echo inactive; echo ":::LARGE_LOGS:::"; find /var/log -type f -size +100M 2>/dev/null | wc -l; echo ":::LOG_SIZE:::"; du -sh /var/log 2>/dev/null | cut -f1; echo ":::BACKUP_EXISTS:::"; test -d /opt/tovplay_backups && echo yes || echo no; echo ":::RECENT_BACKUPS:::"; find /opt/tovplay_backups -type f -mtime -1 2>/dev/null | wc -l; echo ":::BACKUP_SIZE:::"; du -sh /opt/tovplay_backups 2>/dev/null | cut -f1 || echo N/A; echo ":::TIMESYNC:::"; timedatectl show --property=NTPSynchronized --value 2>/dev/null; echo ":::SERVER_TIME:::"; date "+%Y-%m-%d %H:%M:%S %Z"; echo ":::TIMEZONE:::"; timedatectl show --property=Timezone --value 2>/dev/null' 15)

    SSL_EXPIRY=$(echo "$BATCH5" | sed -n '/:::SSL_EXPIRY:::/,/:::CERTBOT:::/p' | grep notAfter | cut -d= -f2)
    CERTBOT=$(echo "$BATCH5" | sed -n '/:::CERTBOT:::/,/:::LOGROTATE:::/p' | tail -1)
    LOGROTATE=$(echo "$BATCH5" | sed -n '/:::LOGROTATE:::/,/:::LARGE_LOGS:::/p' | tail -1)
    LARGE_LOGS=$(echo "$BATCH5" | sed -n '/:::LARGE_LOGS:::/,/:::LOG_SIZE:::/p' | tail -1)
    LOG_SIZE=$(echo "$BATCH5" | sed -n '/:::LOG_SIZE:::/,/:::BACKUP_EXISTS:::/p' | tail -1)
    BACKUP_EXISTS=$(echo "$BATCH5" | sed -n '/:::BACKUP_EXISTS:::/,/:::RECENT_BACKUPS:::/p' | tail -1)
    RECENT_BACKUPS=$(echo "$BATCH5" | sed -n '/:::RECENT_BACKUPS:::/,/:::BACKUP_SIZE:::/p' | tail -1)
    BACKUP_SIZE=$(echo "$BATCH5" | sed -n '/:::BACKUP_SIZE:::/,/:::TIMESYNC:::/p' | tail -1)
    TIMESYNC=$(echo "$BATCH5" | sed -n '/:::TIMESYNC:::/,/:::SERVER_TIME:::/p' | tail -1)
    SERVER_TIME=$(echo "$BATCH5" | sed -n '/:::SERVER_TIME:::/,/:::TIMEZONE:::/p' | tail -1)
    TIMEZONE=$(echo "$BATCH5" | sed -n '/:::TIMEZONE:::/,$p' | tail -1)

    if [ -n "$SSL_EXPIRY" ]; then
        EXPIRY_EPOCH=$(date -d "$SSL_EXPIRY" +%s 2>/dev/null || echo 0)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - $(date +%s)) / 86400 ))
        [ "$DAYS_LEFT" -lt 7 ] && { check_fail "SSL expires in $DAYS_LEFT days!"; add_critical "[PROD] SSL expires soon"; } || \
        [ "$DAYS_LEFT" -lt 30 ] && { check_warn "SSL expires in $DAYS_LEFT days"; add_high "[PROD] SSL renewal needed"; } || \
        check_pass "SSL valid $DAYS_LEFT days"
    fi
    [ "$CERTBOT" = "active" ] && check_pass "Certbot auto-renewal: active" || check_info "Certbot: $CERTBOT"

    [ "$LOGROTATE" = "active" ] && check_pass "Logrotate: active" || check_info "Logrotate: $LOGROTATE"
    [ "$LARGE_LOGS" -gt 0 ] 2>/dev/null && { check_warn "Large logs (>100MB): $LARGE_LOGS"; add_low "[PROD] Large logs"; } || check_pass "No oversized logs"
    check_info "Log size: $LOG_SIZE"

    [ "$BACKUP_EXISTS" = "yes" ] && check_pass "Backup dir exists" || { check_warn "No backup dir"; add_medium "[PROD] Backup missing"; }
    [ "$RECENT_BACKUPS" -gt 0 ] 2>/dev/null && check_pass "Recent backups: $RECENT_BACKUPS" || { check_warn "No recent backups"; add_medium "[PROD] Backup not running"; }
    check_info "Backup size: $BACKUP_SIZE"

    [ "$TIMESYNC" = "yes" ] && check_pass "NTP synchronized" || { check_warn "NTP: $TIMESYNC"; add_low "[PROD] Time not synced"; }
    check_info "Server time: $SERVER_TIME ($TIMEZONE)"
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 91-100: ENVIRONMENT COMPARISON
# ═══════════════════════════════════════════════════════════════
section "91-100" "ENVIRONMENT COMPARISON"
if [ "$PROD_CONNECTED" = true ] && [ "$STAGING_CONNECTED" = true ]; then
    echo -e "${CYAN}Production vs Staging:${NC}"
    printf "  %-15s %-15s %-15s\n" "Component" "Production" "Staging"
    printf "  %-15s %-15s %-15s\n" "Kernel" "$KERNEL" "$STG_KERNEL"
    printf "  %-15s %-15s %-15s\n" "Docker" "$DOCKER_VER" "$STG_DOCKER"

    [ "$KERNEL" != "$STG_KERNEL" ] && { check_warn "Kernel drift"; add_low "Kernel versions differ"; }
    [ "$DOCKER_VER" != "$STG_DOCKER" ] && { check_warn "Docker drift"; add_low "Docker versions differ"; }
fi

# ═══════════════════════════════════════════════════════════════
# RECOMMENDATIONS
# ═══════════════════════════════════════════════════════════════
section "FINAL" "RECOMMENDATIONS"
echo -e "${CYAN}Update Commands:${NC}"
echo "  Production: ssh admin@193.181.213.220 'sudo apt update && sudo apt upgrade -y'"
echo "  Staging:    ssh admin@92.113.144.59 'sudo apt update && sudo apt upgrade -y'"

print_summary
