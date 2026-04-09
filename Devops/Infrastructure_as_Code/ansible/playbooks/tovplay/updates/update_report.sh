#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TovPlay SYSTEM UPDATES AUDIT v6.0 [5X ENHANCED] - MEGA BATCH Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; ORANGE='\033[0;33m'
NC='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
TOTAL_CHECKS=0; PASSED_CHECKS=0

ssh_prod() {
    sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
        "$PROD_USER@$PROD_HOST" "$1" 2>/dev/null
}

ssh_staging() {
    sshpass -p "$STAGING_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
        "$STAGING_USER@$STAGING_HOST" "$1" 2>/dev/null
}

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

    echo -e "\n${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              🔴 THINGS TO FIX - UPDATES                       ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
        for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
        for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}🟠 HIGH: $issue${NC}"; done
        for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
        for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}🔵 LOW: $issue${NC}"; done
    else
        echo -e "  ${GREEN}✓ No issues found! System updates are current.${NC}"
    fi

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
    echo "UPDATE_SCORE:$score"
}

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     🔄 SYSTEM UPDATES AUDIT v6.0 [5X] - $(date '+%Y-%m-%d %H:%M:%S')      ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"

section "1" "SERVER CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK")
STAGING_OK=$(ssh_staging "echo OK")
[ "$PROD_OK" = "OK" ] && { check_pass "Production SSH: connected"; PROD_CONNECTED=true; } || { check_fail "Production SSH: failed"; add_critical "[PROD] SSH failed"; PROD_CONNECTED=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging SSH: connected"; STAGING_CONNECTED=true; } || { check_fail "Staging SSH: failed"; add_critical "[STAGING] SSH failed"; STAGING_CONNECTED=false; }

# ═══════════════════════════════════════════════════════════════════════════════
# MEGA BATCH 1: Production System Audit (80+ checks in ONE SSH call)
# ═══════════════════════════════════════════════════════════════════════════════
section "2-80" "PRODUCTION SYSTEM MEGA AUDIT (5X Enhanced)"
if [ "$PROD_CONNECTED" = true ]; then
    # Use MARKER-BASED parsing - each value prefixed with unique marker for reliable extraction
    MEGA_PROD=$(ssh_prod "
echo \"M_OS_NAME:\$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'\"' -f2)\"
echo \"M_OS_VERSION:\$(cat /etc/os-release 2>/dev/null | grep VERSION_ID | cut -d'\"' -f2)\"
echo \"M_OS_CODENAME:\$(cat /etc/os-release 2>/dev/null | grep VERSION_CODENAME | cut -d= -f2)\"
echo \"M_KERNEL:\$(uname -r)\"
echo \"M_ARCH:\$(uname -m)\"
echo \"M_UPTIME:\$(uptime -p)\"
echo \"M_UPTIME_SECONDS:\$(cat /proc/uptime | cut -d' ' -f1 | cut -d. -f1)\"
echo \"M_LAST_BOOT:\$(who -b | awk '{print \$3,\$4}')\"
echo \"M_APT_LOCK:\$(lsof /var/lib/dpkg/lock-frontend 2>/dev/null | wc -l)\"
echo \"M_DPKG_AUDIT:\$(dpkg --audit 2>/dev/null | wc -l)\"
echo \"M_DPKG_INTERRUPTED:\$(dpkg --get-selections | grep -c 'deinstall' || echo 0)\"
echo \"M_APT_CACHE_TIME:\$(stat -c %Y /var/lib/apt/lists/partial 2>/dev/null || echo 0)\"
echo \"M_UPGRADABLE:\$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0)\"
echo \"M_SECURITY_UPG:\$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)\"
echo \"M_INSTALLED_PKGS:\$(dpkg -l | grep -c '^ii')\"
echo \"M_AUTOREMOVE:\$(apt-get --dry-run autoremove 2>/dev/null | grep -c 'will be removed' || echo 0)\"
echo \"M_APT_SOURCES:\$(find /etc/apt/sources.list.d/ -type f 2>/dev/null | wc -l)\"
echo \"M_HELD_PKGS:\$(dpkg --get-selections | grep -c 'hold' || echo 0)\"
echo \"M_DOCKER_VER:\$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)\"
echo \"M_DOCKER_COMPOSE_VER:\$(docker-compose --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)\"
echo \"M_NGINX_VER:\$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)\"
echo \"M_PYTHON_VER:\$(python3 --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')\"
echo \"M_PIP_VER:\$(pip3 --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)\"
echo \"M_NODE_VER:\$(node --version 2>/dev/null | tr -d 'v')\"
echo \"M_NPM_VER:\$(npm --version 2>/dev/null)\"
echo \"M_GIT_VER:\$(git --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')\"
echo \"M_CURL_VER:\$(curl --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')\"
echo \"M_OPENSSL_VER:\$(openssl version 2>/dev/null | grep -oP '\d+\.\d+\.\d+[a-z]*' | head -1)\"
echo \"M_POSTGRES_CLIENT:\$(psql --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)\"
echo \"M_REBOOT_REQ:\$(test -f /var/run/reboot-required && echo yes || echo no)\"
echo \"M_REBOOT_REASON:\$(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ',' | sed 's/,$//')\"
echo \"M_KERNEL_RUNNING:\$(uname -r)\"
echo \"M_KERNEL_INSTALLED:\$(dpkg -l | grep linux-image-\$(uname -r) | head -1 | awk '{print \$2}' | sed 's/linux-image-//')\"
echo \"M_UNATTENDED_UPG:\$(systemctl is-active unattended-upgrades 2>/dev/null || echo inactive)\"
echo \"M_LAST_APT_UPDATE:\$(stat -c %Y /var/lib/apt/periodic/update-success-stamp 2>/dev/null || echo 0)\"
echo \"M_DOCKER_SVC:\$(systemctl is-active docker)\"
echo \"M_NGINX_SVC:\$(systemctl is-active nginx)\"
echo \"M_CRON_SVC:\$(systemctl is-active cron)\"
echo \"M_SSH_SVC:\$(systemctl is-active sshd || systemctl is-active ssh)\"
echo \"M_FAIL2BAN:\$(systemctl is-active fail2ban 2>/dev/null || echo not-found)\"
echo \"M_UFW_STATUS:\$(ufw status 2>/dev/null | head -1)\"
echo \"M_CERTBOT_TIMER:\$(systemctl is-active certbot.timer 2>/dev/null || echo inactive)\"
echo \"M_LOGROTATE_TIMER:\$(systemctl is-active logrotate.timer 2>/dev/null || echo inactive)\"
echo \"M_FAILED_SERVICES:\$(systemctl list-units --state=failed --no-legend 2>/dev/null | wc -l)\"
echo \"M_FAILED_LIST:\$(systemctl list-units --state=failed --no-legend 2>/dev/null | awk '{print \$1}' | tr '\n' ',' | sed 's/,$//')\"
echo \"M_LOAD_1MIN:\$(cat /proc/loadavg | cut -d' ' -f1)\"
echo \"M_LOAD_5MIN:\$(cat /proc/loadavg | cut -d' ' -f2)\"
echo \"M_LOAD_15MIN:\$(cat /proc/loadavg | cut -d' ' -f3)\"
echo \"M_CPU_CORES:\$(nproc)\"
echo \"M_MEM_TOTAL:\$(free -m | awk '/Mem:/{print \$2}')\"
echo \"M_MEM_USED:\$(free -m | awk '/Mem:/{print \$3}')\"
echo \"M_MEM_FREE:\$(free -m | awk '/Mem:/{print \$4}')\"
echo \"M_MEM_AVAILABLE:\$(free -m | awk '/Mem:/{print \$7}')\"
echo \"M_SWAP_TOTAL:\$(free -m | awk '/Swap:/{print \$2}')\"
echo \"M_SWAP_USED:\$(free -m | awk '/Swap:/{print \$3}')\"
echo \"M_DISK_ROOT_SIZE:\$(df -BG / | awk 'NR==2{print \$2}' | tr -d 'G')\"
echo \"M_DISK_ROOT_USED:\$(df -BG / | awk 'NR==2{print \$3}' | tr -d 'G')\"
echo \"M_DISK_ROOT_AVAIL:\$(df -BG / | awk 'NR==2{print \$4}' | tr -d 'G')\"
echo \"M_DISK_ROOT_PCT:\$(df / | awk 'NR==2{print \$5}' | tr -d '%')\"
echo \"M_INODES_USED:\$(df -i / | awk 'NR==2{print \$5}')\"
echo \"M_CONTAINERS_RUNNING:\$(docker ps -q 2>/dev/null | wc -l)\"
echo \"M_CONTAINERS_TOTAL:\$(docker ps -aq 2>/dev/null | wc -l)\"
echo \"M_CONTAINERS_STOPPED:\$(docker ps -aq -f status=exited 2>/dev/null | wc -l)\"
echo \"M_IMAGES_TOTAL:\$(docker images -q 2>/dev/null | wc -l)\"
echo \"M_IMAGES_DANGLING:\$(docker images -f 'dangling=true' -q 2>/dev/null | wc -l)\"
echo \"M_NETWORKS:\$(docker network ls -q 2>/dev/null | wc -l)\"
echo \"M_VOLUMES:\$(docker volume ls -q 2>/dev/null | wc -l)\"
echo \"M_VOLUMES_DANGLING:\$(docker volume ls -f dangling=true -q 2>/dev/null | wc -l)\"
echo \"M_SSL_CERT_EXPIRES:\$(openssl s_client -connect localhost:443 -servername app.tovplay.org </dev/null 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)\"
echo \"M_SSL_CERT_ISSUER:\$(openssl s_client -connect localhost:443 -servername app.tovplay.org </dev/null 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//')\"
echo \"M_SSL_CERT_SUBJECT:\$(openssl s_client -connect localhost:443 -servername app.tovplay.org </dev/null 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')\"
echo \"M_SSL_CERTS_COUNT:\$(find /etc/letsencrypt/live/ -name 'cert.pem' 2>/dev/null | wc -l)\"
echo \"M_LARGE_LOGS:\$(find /var/log -type f -size +100M 2>/dev/null | wc -l)\"
echo \"M_LOG_SIZE_MB:\$(du -sm /var/log 2>/dev/null | cut -f1)\"
echo \"M_SYSLOG_ERRORS:\$(tail -100 /var/log/syslog 2>/dev/null | grep -c 'error' || echo 0)\"
echo \"M_BACKUP_DIR:\$(test -d /opt/tovplay_backups && echo yes || echo no)\"
echo \"M_RECENT_BACKUPS:\$(find /opt/tovplay_backups -type f -mtime -1 2>/dev/null | wc -l)\"
echo \"M_TOTAL_BACKUPS:\$(find /opt/tovplay_backups -type f 2>/dev/null | wc -l)\"
echo \"M_BACKUP_SIZE_MB:\$(du -sm /opt/tovplay_backups 2>/dev/null | cut -f1 || echo 0)\"
echo \"M_OLDEST_BACKUP:\$(find /opt/tovplay_backups -type f 2>/dev/null | head -1 | xargs stat -c %Y 2>/dev/null || echo 0)\"
echo \"M_NTP_SYNC:\$(timedatectl show --property=NTPSynchronized --value 2>/dev/null)\"
echo \"M_TIMEZONE:\$(timedatectl show --property=Timezone --value 2>/dev/null)\"
echo \"M_SERVER_TIME:\$(date '+%s')\"
echo \"M_LISTEN_PORTS:\$(ss -tlnp 2>/dev/null | grep LISTEN | wc -l)\"
echo \"M_ESTABLISHED_CONN:\$(ss -tn 2>/dev/null | grep ESTAB | wc -l)\"
echo \"M_TIMEWAIT_CONN:\$(ss -tn 2>/dev/null | grep TIME-WAIT | wc -l)\"
echo \"M_TOTAL_PROCESSES:\$(ps aux | wc -l)\"
echo \"M_ZOMBIE_PROCESSES:\$(ps aux | awk '\$8~/Z/{print}' | wc -l)\"
echo \"M_ROOT_PROCESSES:\$(ps -U root | wc -l)\"
echo \"M_DISK_IO_READS:\$(cat /proc/diskstats | awk '{sum+=\$6} END {print sum}')\"
echo \"M_DISK_IO_WRITES:\$(cat /proc/diskstats | awk '{sum+=\$10} END {print sum}')\"
" | tr -d '\r')

    # Parse using markers - robust extraction regardless of line position
    extract_value() { echo "$MEGA_PROD" | grep "^M_$1:" | head -1 | cut -d: -f2-; }

    OS_NAME=$(extract_value "OS_NAME")
    OS_VERSION=$(extract_value "OS_VERSION")
    OS_CODENAME=$(extract_value "OS_CODENAME")
    KERNEL=$(extract_value "KERNEL")
    ARCH=$(extract_value "ARCH")
    UPTIME=$(extract_value "UPTIME")
    UPTIME_SECONDS=$(extract_value "UPTIME_SECONDS")
    LAST_BOOT=$(extract_value "LAST_BOOT")
    APT_LOCK=$(extract_value "APT_LOCK")
    DPKG_AUDIT=$(extract_value "DPKG_AUDIT")
    DPKG_INTERRUPTED=$(extract_value "DPKG_INTERRUPTED")
    APT_CACHE_TIME=$(extract_value "APT_CACHE_TIME")
    UPGRADABLE=$(extract_value "UPGRADABLE")
    SECURITY_UPG=$(extract_value "SECURITY_UPG")
    INSTALLED_PKGS=$(extract_value "INSTALLED_PKGS")
    AUTOREMOVE=$(extract_value "AUTOREMOVE")
    APT_SOURCES=$(extract_value "APT_SOURCES")
    HELD_PKGS=$(extract_value "HELD_PKGS")
    DOCKER_VER=$(extract_value "DOCKER_VER")
    DOCKER_COMPOSE_VER=$(extract_value "DOCKER_COMPOSE_VER")
    NGINX_VER=$(extract_value "NGINX_VER")
    PYTHON_VER=$(extract_value "PYTHON_VER")
    PIP_VER=$(extract_value "PIP_VER")
    NODE_VER=$(extract_value "NODE_VER")
    NPM_VER=$(extract_value "NPM_VER")
    GIT_VER=$(extract_value "GIT_VER")
    CURL_VER=$(extract_value "CURL_VER")
    OPENSSL_VER=$(extract_value "OPENSSL_VER")
    POSTGRES_CLIENT=$(extract_value "POSTGRES_CLIENT")
    REBOOT_REQ=$(extract_value "REBOOT_REQ")
    REBOOT_REASON=$(extract_value "REBOOT_REASON")
    KERNEL_RUNNING=$(extract_value "KERNEL_RUNNING")
    KERNEL_INSTALLED=$(extract_value "KERNEL_INSTALLED")
    UNATTENDED_UPG=$(extract_value "UNATTENDED_UPG")
    LAST_APT_UPDATE=$(extract_value "LAST_APT_UPDATE")
    DOCKER_SVC=$(extract_value "DOCKER_SVC")
    NGINX_SVC=$(extract_value "NGINX_SVC")
    CRON_SVC=$(extract_value "CRON_SVC")
    SSH_SVC=$(extract_value "SSH_SVC")
    FAIL2BAN=$(extract_value "FAIL2BAN")
    UFW_STATUS=$(extract_value "UFW_STATUS")
    CERTBOT_TIMER=$(extract_value "CERTBOT_TIMER")
    LOGROTATE_TIMER=$(extract_value "LOGROTATE_TIMER")
    FAILED_SERVICES=$(extract_value "FAILED_SERVICES")
    FAILED_LIST=$(extract_value "FAILED_LIST")
    LOAD_1MIN=$(extract_value "LOAD_1MIN")
    LOAD_5MIN=$(extract_value "LOAD_5MIN")
    LOAD_15MIN=$(extract_value "LOAD_15MIN")
    CPU_CORES=$(extract_value "CPU_CORES")
    MEM_TOTAL=$(extract_value "MEM_TOTAL")
    MEM_USED=$(extract_value "MEM_USED")
    MEM_FREE=$(extract_value "MEM_FREE")
    MEM_AVAILABLE=$(extract_value "MEM_AVAILABLE")
    SWAP_TOTAL=$(extract_value "SWAP_TOTAL")
    SWAP_USED=$(extract_value "SWAP_USED")
    DISK_ROOT_SIZE=$(extract_value "DISK_ROOT_SIZE")
    DISK_ROOT_USED=$(extract_value "DISK_ROOT_USED")
    DISK_ROOT_AVAIL=$(extract_value "DISK_ROOT_AVAIL")
    DISK_ROOT_PCT=$(extract_value "DISK_ROOT_PCT")
    INODES_USED=$(extract_value "INODES_USED")
    CONTAINERS_RUNNING=$(extract_value "CONTAINERS_RUNNING")
    CONTAINERS_TOTAL=$(extract_value "CONTAINERS_TOTAL")
    CONTAINERS_STOPPED=$(extract_value "CONTAINERS_STOPPED")
    IMAGES_TOTAL=$(extract_value "IMAGES_TOTAL")
    IMAGES_DANGLING=$(extract_value "IMAGES_DANGLING")
    NETWORKS=$(extract_value "NETWORKS")
    VOLUMES=$(extract_value "VOLUMES")
    VOLUMES_DANGLING=$(extract_value "VOLUMES_DANGLING")
    SSL_CERT_EXPIRES=$(extract_value "SSL_CERT_EXPIRES")
    SSL_CERT_ISSUER=$(extract_value "SSL_CERT_ISSUER")
    SSL_CERT_SUBJECT=$(extract_value "SSL_CERT_SUBJECT")
    SSL_CERTS_COUNT=$(extract_value "SSL_CERTS_COUNT")
    LARGE_LOGS=$(extract_value "LARGE_LOGS")
    LOG_SIZE_MB=$(extract_value "LOG_SIZE_MB")
    SYSLOG_ERRORS=$(extract_value "SYSLOG_ERRORS")
    BACKUP_DIR=$(extract_value "BACKUP_DIR")
    RECENT_BACKUPS=$(extract_value "RECENT_BACKUPS")
    TOTAL_BACKUPS=$(extract_value "TOTAL_BACKUPS")
    BACKUP_SIZE_MB=$(extract_value "BACKUP_SIZE_MB")
    OLDEST_BACKUP=$(extract_value "OLDEST_BACKUP")
    NTP_SYNC=$(extract_value "NTP_SYNC")
    TIMEZONE=$(extract_value "TIMEZONE")
    SERVER_TIME=$(extract_value "SERVER_TIME")
    LISTEN_PORTS=$(extract_value "LISTEN_PORTS")
    ESTABLISHED_CONN=$(extract_value "ESTABLISHED_CONN")
    TIMEWAIT_CONN=$(extract_value "TIMEWAIT_CONN")
    TOTAL_PROCESSES=$(extract_value "TOTAL_PROCESSES")
    ZOMBIE_PROCESSES=$(extract_value "ZOMBIE_PROCESSES")
    ROOT_PROCESSES=$(extract_value "ROOT_PROCESSES")
    DISK_IO_READS=$(extract_value "DISK_IO_READS")
    DISK_IO_WRITES=$(extract_value "DISK_IO_WRITES")

    # Display System Info
    check_info "OS: $OS_NAME ($OS_CODENAME)"
    check_info "Version: $OS_VERSION | Kernel: $KERNEL | Arch: $ARCH"
    check_info "Uptime: $UPTIME (${UPTIME_SECONDS}s) | Last boot: $LAST_BOOT"

    # OS Version Check
    echo "$OS_VERSION" | grep -qE "18.04|16.04|14.04" && { check_fail "OS version is EOL"; add_critical "[PROD] OS needs upgrade"; } || check_pass "OS version supported"

    # Package Management
    [ "${APT_LOCK:-0}" -gt 0 ] && { check_fail "APT locked (PID in use)"; add_high "[PROD] APT locked"; } || check_pass "APT available"
    [ "${DPKG_AUDIT:-0}" -gt 0 ] && { check_warn "dpkg needs repair: $DPKG_AUDIT issues"; add_medium "[PROD] dpkg repair needed"; } || check_pass "dpkg healthy"
    [ "${DPKG_INTERRUPTED:-0}" -gt 0 ] && { check_warn "Interrupted package installs: $DPKG_INTERRUPTED"; add_medium "[PROD] dpkg interrupted"; }

    NOW=$(date +%s); DAYS_AGO=$(( (NOW - APT_CACHE_TIME) / 86400 )) 2>/dev/null || DAYS_AGO=0
    [ "$DAYS_AGO" -gt 30 ] && { check_warn "APT cache ${DAYS_AGO}d old"; add_medium "[PROD] apt update needed"; } || check_pass "APT cache recent (${DAYS_AGO}d)"

    check_info "Installed packages: $INSTALLED_PKGS | Autoremove candidates: $AUTOREMOVE"
    check_info "APT sources: $APT_SOURCES | Held packages: $HELD_PKGS"

    [ "${UPGRADABLE:-0}" -gt 50 ] && { check_warn "$UPGRADABLE packages upgradable"; add_medium "[PROD] Many pending updates"; } || check_pass "Upgradable packages: $UPGRADABLE"
    [ "${SECURITY_UPG:-0}" -gt 0 ] && { check_warn "$SECURITY_UPG security updates pending"; add_high "[PROD] Security updates needed"; } || check_pass "No pending security updates"

    # Software Versions
    check_info "Docker: $DOCKER_VER | Docker Compose: $DOCKER_COMPOSE_VER"
    check_info "Nginx: $NGINX_VER | Python: $PYTHON_VER | pip: $PIP_VER"
    check_info "Node: $NODE_VER | npm: $NPM_VER | Git: $GIT_VER"
    check_info "curl: $CURL_VER | OpenSSL: $OPENSSL_VER | PostgreSQL client: $POSTGRES_CLIENT"

    # Reboot Status
    [ "$REBOOT_REQ" = "yes" ] && { check_warn "Reboot required: $REBOOT_REASON"; add_medium "[PROD] Reboot required"; } || check_pass "No reboot required"
    [ "$KERNEL_RUNNING" != "$KERNEL_INSTALLED" ] && { check_warn "Kernel mismatch (running: $KERNEL_RUNNING, installed: $KERNEL_INSTALLED)"; add_low "[PROD] Kernel update pending"; }

    [ "$UNATTENDED_UPG" = "active" ] && check_pass "Unattended upgrades: active" || check_info "Unattended upgrades: $UNATTENDED_UPG"
    LAST_UPD_DAYS=0
    # Validate that LAST_APT_UPDATE is a valid unix timestamp (only digits, 10 chars)
    if [ -n "$LAST_APT_UPDATE" ] && [[ "$LAST_APT_UPDATE" =~ ^[0-9]{10,}$ ]]; then
        LAST_UPD_DAYS=$(( (NOW - LAST_APT_UPDATE) / 86400 ))
    else
        LAST_UPD_DAYS=999
    fi
    [ "${LAST_UPD_DAYS:-0}" -gt 7 ] 2>/dev/null && { check_warn "Last apt update: ${LAST_UPD_DAYS}d ago"; add_low "[PROD] APT update overdue"; } || check_pass "Last apt update: ${LAST_UPD_DAYS}d ago"

    # Services
    [ "$DOCKER_SVC" = "active" ] && check_pass "Docker: active" || { check_fail "Docker: $DOCKER_SVC"; add_critical "[PROD] Docker down"; }
    [ "$NGINX_SVC" = "active" ] && check_pass "Nginx: active" || { check_fail "Nginx: $NGINX_SVC"; add_critical "[PROD] Nginx down"; }
    [ "$CRON_SVC" = "active" ] && check_pass "Cron: active" || { check_warn "Cron: $CRON_SVC"; add_medium "[PROD] Cron down"; }
    [ "$SSH_SVC" = "active" ] && check_pass "SSH: active" || check_warn "SSH: $SSH_SVC"
    [ "$FAIL2BAN" = "active" ] && check_pass "Fail2ban: active" || check_info "Fail2ban: $FAIL2BAN"
    echo "$UFW_STATUS" | grep -qi "active" && check_pass "UFW: active" || check_info "UFW: $UFW_STATUS"
    [ "$CERTBOT_TIMER" = "active" ] && check_pass "Certbot timer: active" || check_info "Certbot: $CERTBOT_TIMER"
    [ "$LOGROTATE_TIMER" = "active" ] && check_pass "Logrotate timer: active" || check_info "Logrotate: $LOGROTATE_TIMER"

    [ "${FAILED_SERVICES:-0}" -gt 0 ] && { check_fail "$FAILED_SERVICES failed services: $FAILED_LIST"; add_high "[PROD] Failed services"; } || check_pass "No failed services"

    # System Resources
    check_info "Load: $LOAD_1MIN (1m) $LOAD_5MIN (5m) $LOAD_15MIN (15m) | CPU cores: $CPU_CORES"
    if [ -n "$CPU_CORES" ] && [ "$CPU_CORES" != "0" ] && [ -n "$LOAD_1MIN" ]; then
        LOAD_THRESHOLD=$(echo "$CPU_CORES * 2" | bc 2>/dev/null || echo 99)
        LOAD_CHECK=$(echo "$LOAD_1MIN > $LOAD_THRESHOLD" | bc 2>/dev/null || echo 0)
        [ "$LOAD_CHECK" = "1" ] && { check_warn "High load: $LOAD_1MIN"; add_high "[PROD] CPU overloaded"; } || check_pass "Load OK"
    else
        check_pass "Load OK"
    fi

    MEM_PCT=0
    if [ -n "$MEM_TOTAL" ] && [ "$MEM_TOTAL" != "0" ] && [ -n "$MEM_USED" ]; then
        MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
    fi
    check_info "Memory: ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PCT}%) | Available: ${MEM_AVAILABLE}MB"
    check_info "Swap: ${SWAP_USED}MB / ${SWAP_TOTAL}MB"
    [ "${MEM_PCT:-0}" -gt 90 ] 2>/dev/null && { check_fail "Memory critical: ${MEM_PCT}%"; add_critical "[PROD] Memory >90%"; } || \
    [ "${MEM_PCT:-0}" -gt 80 ] 2>/dev/null && { check_warn "Memory high: ${MEM_PCT}%"; add_high "[PROD] Memory >80%"; } || check_pass "Memory: ${MEM_PCT}% OK"
    [ "${SWAP_USED:-0}" -gt 1024 ] 2>/dev/null && { check_warn "Swap usage high: ${SWAP_USED}MB"; add_low "[PROD] High swap usage"; }

    check_info "Disk: ${DISK_ROOT_USED}G / ${DISK_ROOT_SIZE}G used (${DISK_ROOT_PCT}%) | Available: ${DISK_ROOT_AVAIL}G"
    check_info "Inodes: $INODES_USED"
    [ "${DISK_ROOT_PCT:-0}" -gt 95 ] && { check_fail "Disk critical: ${DISK_ROOT_PCT}%"; add_critical "[PROD] Disk >95%"; } || \
    [ "${DISK_ROOT_PCT:-0}" -gt 90 ] && { check_warn "Disk high: ${DISK_ROOT_PCT}%"; add_medium "[PROD] Disk >90%"; } || check_pass "Disk: ${DISK_ROOT_PCT}% OK"

    # Docker Stats
    check_info "Docker: ${CONTAINERS_RUNNING}/${CONTAINERS_TOTAL} running | Stopped: $CONTAINERS_STOPPED"
    check_info "Images: $IMAGES_TOTAL total | Dangling: $IMAGES_DANGLING"
    check_info "Networks: $NETWORKS | Volumes: $VOLUMES | Dangling volumes: $VOLUMES_DANGLING"
    [ "${IMAGES_DANGLING:-0}" -gt 10 ] && { check_warn "Many dangling images: $IMAGES_DANGLING"; add_low "[PROD] Docker cleanup needed"; }
    [ "${VOLUMES_DANGLING:-0}" -gt 5 ] && { check_warn "Dangling volumes: $VOLUMES_DANGLING"; add_low "[PROD] Volume cleanup needed"; }

    # SSL
    if [ -n "$SSL_CERT_EXPIRES" ]; then
        EXPIRY_EPOCH=$(date -d "$SSL_CERT_EXPIRES" +%s 2>/dev/null || echo 0)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - $(date +%s)) / 86400 ))
        check_info "SSL: $SSL_CERT_SUBJECT"
        check_info "SSL Issuer: $SSL_CERT_ISSUER"
        [ "$DAYS_LEFT" -lt 7 ] && { check_fail "SSL expires in $DAYS_LEFT days!"; add_critical "[PROD] SSL expires soon"; } || \
        [ "$DAYS_LEFT" -lt 30 ] && { check_warn "SSL expires in $DAYS_LEFT days"; add_high "[PROD] SSL renewal needed"; } || \
        check_pass "SSL valid: $DAYS_LEFT days remaining"
    fi
    check_info "Let's Encrypt certificates: $SSL_CERTS_COUNT"

    # Logs & Backups
    check_info "Log size: ${LOG_SIZE_MB}MB | Large logs (>100MB): $LARGE_LOGS"
    [ "${LARGE_LOGS:-0}" -gt 5 ] && { check_warn "Many large logs: $LARGE_LOGS"; add_low "[PROD] Log cleanup needed"; }
    [ "${SYSLOG_ERRORS:-0}" -gt 100 ] && { check_warn "Syslog errors: $SYSLOG_ERRORS in last 100 lines"; add_low "[PROD] Check syslog"; }

    [ "$BACKUP_DIR" = "yes" ] && check_pass "Backup directory exists" || { check_warn "No backup directory"; add_medium "[PROD] Backup missing"; }
    [ "${RECENT_BACKUPS:-0}" -gt 0 ] && check_pass "Recent backups: $RECENT_BACKUPS (last 24h)" || { check_warn "No recent backups"; add_medium "[PROD] Backup not running"; }
    check_info "Total backups: $TOTAL_BACKUPS | Size: ${BACKUP_SIZE_MB}MB"
    if [ "${OLDEST_BACKUP:-0}" -gt 0 ]; then
        OLDEST_DAYS=$(( (NOW - OLDEST_BACKUP) / 86400 ))
        check_info "Oldest backup: ${OLDEST_DAYS}d ago"
    fi

    # Time Sync
    [ "$NTP_SYNC" = "yes" ] && check_pass "NTP synchronized" || { check_warn "NTP: $NTP_SYNC"; add_low "[PROD] Time not synced"; }
    check_info "Timezone: $TIMEZONE | Server time: $(date -d @$SERVER_TIME '+%Y-%m-%d %H:%M:%S')"

    # Network
    check_info "Network: $LISTEN_PORTS listening | $ESTABLISHED_CONN established | $TIMEWAIT_CONN time-wait"
    [ "${ESTABLISHED_CONN:-0}" -gt 1000 ] && { check_warn "High connection count: $ESTABLISHED_CONN"; add_low "[PROD] High connections"; }

    # Processes
    check_info "Processes: $TOTAL_PROCESSES total | $ZOMBIE_PROCESSES zombies | $ROOT_PROCESSES root-owned"
    [ "${ZOMBIE_PROCESSES:-0}" -gt 5 ] && { check_warn "Zombie processes: $ZOMBIE_PROCESSES"; add_low "[PROD] Zombie processes"; }

    # Disk I/O
    check_info "Disk I/O: ${DISK_IO_READS} reads | ${DISK_IO_WRITES} writes"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# MEGA BATCH 2: Staging System Audit (40+ checks in ONE SSH call)
# ═══════════════════════════════════════════════════════════════════════════════
section "81-120" "STAGING SYSTEM MEGA AUDIT (5X Enhanced)"
if [ "$STAGING_CONNECTED" = true ]; then
    # Use MARKER-BASED parsing for staging too
    MEGA_STG=$(ssh_staging "
echo \"S_OS:\$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'\"' -f2)\"
echo \"S_VERSION:\$(cat /etc/os-release 2>/dev/null | grep VERSION_ID | cut -d'\"' -f2)\"
echo \"S_CODENAME:\$(cat /etc/os-release 2>/dev/null | grep VERSION_CODENAME | cut -d= -f2)\"
echo \"S_KERNEL:\$(uname -r)\"
echo \"S_UPTIME:\$(uptime -p)\"
echo \"S_UPG:\$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0)\"
echo \"S_SEC:\$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)\"
echo \"S_REBOOT:\$(test -f /var/run/reboot-required && echo yes || echo no)\"
echo \"S_DOCKER:\$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)\"
echo \"S_NGINX:\$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)\"
echo \"S_PYTHON:\$(python3 --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')\"
echo \"S_NODE:\$(node --version 2>/dev/null | tr -d 'v')\"
echo \"S_DOCKER_SVC:\$(systemctl is-active docker)\"
echo \"S_NGINX_SVC:\$(systemctl is-active nginx)\"
echo \"S_CONTAINERS:\$(docker ps -q 2>/dev/null | wc -l)\"
echo \"S_LOAD:\$(cat /proc/loadavg | cut -d' ' -f1-3)\"
echo \"S_MEM_PCT:\$(free | awk '/Mem:/{printf \"%.0f\", \$3/\$2*100}')\"
echo \"S_DISK_PCT:\$(df / | awk 'NR==2{print \$5}' | tr -d '%')\"
echo \"S_INSTALLED_PKGS:\$(dpkg -l | grep -c '^ii')\"
echo \"S_FAILED_SVC:\$(systemctl list-units --state=failed --no-legend 2>/dev/null | wc -l)\"
" | tr -d '\r')

    # Parse using markers - robust extraction
    stg_extract() { echo "$MEGA_STG" | grep "^S_$1:" | head -1 | cut -d: -f2-; }

    STG_OS=$(stg_extract "OS")
    STG_VERSION=$(stg_extract "VERSION")
    STG_CODENAME=$(stg_extract "CODENAME")
    STG_KERNEL=$(stg_extract "KERNEL")
    STG_UPTIME=$(stg_extract "UPTIME")
    STG_UPG=$(stg_extract "UPG")
    STG_SEC=$(stg_extract "SEC")
    STG_REBOOT=$(stg_extract "REBOOT")
    STG_DOCKER=$(stg_extract "DOCKER")
    STG_NGINX=$(stg_extract "NGINX")
    STG_PYTHON=$(stg_extract "PYTHON")
    STG_NODE=$(stg_extract "NODE")
    STG_DOCKER_SVC=$(stg_extract "DOCKER_SVC")
    STG_NGINX_SVC=$(stg_extract "NGINX_SVC")
    STG_CONTAINERS=$(stg_extract "CONTAINERS")
    STG_LOAD=$(stg_extract "LOAD")
    STG_MEM_PCT=$(stg_extract "MEM_PCT")
    STG_DISK_PCT=$(stg_extract "DISK_PCT")
    STG_INSTALLED_PKGS=$(stg_extract "INSTALLED_PKGS")
    STG_FAILED_SVC=$(stg_extract "FAILED_SVC")

    check_info "OS: $STG_OS ($STG_CODENAME)"
    check_info "Version: $STG_VERSION | Kernel: $STG_KERNEL | Uptime: $STG_UPTIME"
    check_info "Installed packages: $STG_INSTALLED_PKGS"

    [ "${STG_UPG:-0}" -gt 50 ] && { check_warn "Staging: $STG_UPG upgradable"; add_medium "[STAGING] Many updates"; } || check_pass "Staging upgradable: $STG_UPG"
    [ "${STG_SEC:-0}" -gt 0 ] && { check_warn "Staging: $STG_SEC security updates"; add_high "[STAGING] Security updates"; } || check_pass "Staging: no security updates"
    [ "$STG_REBOOT" = "yes" ] && { check_warn "Staging: reboot required"; add_low "[STAGING] Reboot needed"; } || check_pass "Staging: no reboot needed"

    check_info "Docker: $STG_DOCKER | Nginx: $STG_NGINX | Python: $STG_PYTHON | Node: $STG_NODE"

    [ "$STG_DOCKER_SVC" = "active" ] && check_pass "Staging Docker: active" || { check_warn "Staging Docker: $STG_DOCKER_SVC"; add_high "[STAGING] Docker down"; }
    [ "$STG_NGINX_SVC" = "active" ] && check_pass "Staging Nginx: active" || { check_warn "Staging Nginx: $STG_NGINX_SVC"; add_high "[STAGING] Nginx down"; }

    check_info "Containers: $STG_CONTAINERS | Load: $STG_LOAD | Memory: ${STG_MEM_PCT}% | Disk: ${STG_DISK_PCT}%"

    [ "${STG_MEM_PCT:-0}" -gt 90 ] 2>/dev/null && { check_warn "Staging memory high: ${STG_MEM_PCT}%"; add_medium "[STAGING] Memory >90%"; }
    [ "${STG_DISK_PCT:-0}" -gt 90 ] 2>/dev/null && { check_warn "Staging disk high: ${STG_DISK_PCT}%"; add_medium "[STAGING] Disk >90%"; }
    [ "${STG_FAILED_SVC:-0}" -gt 0 ] 2>/dev/null && { check_warn "Staging: $STG_FAILED_SVC failed services"; add_medium "[STAGING] Failed services"; }
fi

section "121-140" "ENVIRONMENT COMPARISON (Enhanced)"
if [ "$PROD_CONNECTED" = true ] && [ "$STAGING_CONNECTED" = true ]; then
    echo -e "${CYAN}Production vs Staging Versions:${NC}"
    printf "  %-20s %-20s %-20s %-10s\n" "Component" "Production" "Staging" "Match"
    printf "  %-20s %-20s %-20s %-10s\n" "────────────────────" "────────────────────" "────────────────────" "──────────"
    printf "  %-20s %-20s %-20s %-10s\n" "OS" "$OS_VERSION" "$STG_VERSION" "$([ "$OS_VERSION" = "$STG_VERSION" ] && echo '✓' || echo '✗')"
    printf "  %-20s %-20s %-20s %-10s\n" "Kernel" "$KERNEL" "$STG_KERNEL" "$([ "$KERNEL" = "$STG_KERNEL" ] && echo '✓' || echo '✗')"
    printf "  %-20s %-20s %-20s %-10s\n" "Docker" "$DOCKER_VER" "$STG_DOCKER" "$([ "$DOCKER_VER" = "$STG_DOCKER" ] && echo '✓' || echo '✗')"
    printf "  %-20s %-20s %-20s %-10s\n" "Nginx" "$NGINX_VER" "$STG_NGINX" "$([ "$NGINX_VER" = "$STG_NGINX" ] && echo '✓' || echo '✗')"
    printf "  %-20s %-20s %-20s %-10s\n" "Python" "$PYTHON_VER" "$STG_PYTHON" "$([ "$PYTHON_VER" = "$STG_PYTHON" ] && echo '✓' || echo '✗')"
    printf "  %-20s %-20s %-20s %-10s\n" "Node" "$NODE_VER" "$STG_NODE" "$([ "$NODE_VER" = "$STG_NODE" ] && echo '✓' || echo '✗')"

    # Version drift warnings (info only, not penalized)
    [ "$KERNEL" != "$STG_KERNEL" ] && check_info "Kernel versions differ (expected in most environments)"
    [ "$DOCKER_VER" != "$STG_DOCKER" ] && check_info "Docker versions differ"
    [ "$PYTHON_VER" != "$STG_PYTHON" ] && check_info "Python versions differ"
fi

section "FINAL" "RECOMMENDATIONS & QUICK COMMANDS"
echo -e "${CYAN}Update Commands:${NC}"
echo "  Production: ssh admin@193.181.213.220 'sudo apt update && sudo apt upgrade -y'"
echo "  Staging:    ssh admin@92.113.144.59 'sudo apt update && sudo apt upgrade -y'"
echo ""
echo -e "${CYAN}Docker Cleanup:${NC}"
echo "  Remove dangling images: docker image prune -f"
echo "  Remove dangling volumes: docker volume prune -f"
echo "  Remove stopped containers: docker container prune -f"

print_summary
