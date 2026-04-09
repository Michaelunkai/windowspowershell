#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# INFRASTRUCTURE AUDIT v6.1 [5X ENHANCED] - MEGA BATCH Edition [FIXED PARSING]
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

# Source ultra-fast SSH helpers (uses ansall.sh ControlMaster for instant connections)
SCRIPT_DIR_ABS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR_ABS/fast_ssh_helpers.sh" 2>/dev/null || true

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
TOTAL_CHECKS=0; PASSED_CHECKS=0

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
    echo -e "${BOLD}${RED}║              🔴 THINGS TO FIX - INFRASTRUCTURE                ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
        for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
        for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}🟠 HIGH: $issue${NC}"; done
        for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
        for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}🔵 LOW: $issue${NC}"; done
    else
        echo -e "  ${GREEN}✓ No issues found! Infrastructure is healthy.${NC}"
    fi

    local stars rating
    [ $score -ge 90 ] && { stars="★★★★★"; rating="EXCELLENT"; } || \
    [ $score -ge 80 ] && { stars="★★★★☆"; rating="GOOD"; } || \
    [ $score -ge 70 ] && { stars="★★★☆☆"; rating="FAIR"; } || \
    [ $score -ge 60 ] && { stars="★★☆☆☆"; rating="NEEDS WORK"; } || \
    { stars="★☆☆☆☆"; rating="CRITICAL"; }

    echo -e "\n${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  $stars $rating - Score: $score/100${NC}"
    echo -e "${BOLD}║  Time: ${dur}s | Checks: $TOTAL_CHECKS | Passed: $PASSED_CHECKS${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo "INFRASTRUCTURE_SCORE:$score"
}

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     🖥️ INFRASTRUCTURE AUDIT v6.1 [5X ENHANCED] - $(date '+%Y-%m-%d %H:%M:%S')      ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

section "1" "CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 15)
STAGING_OK=$(ssh_staging "echo OK" 15)
[ "$PROD_OK" = "OK" ] && { check_pass "Production SSH: connected"; PROD_CONN=true; } || { check_fail "Production SSH: failed"; add_critical "[PROD] SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging SSH: connected"; STAGING_CONN=true; } || { check_warn "Staging SSH: failed"; STAGING_CONN=false; }

section "2-60" "PRODUCTION INFRASTRUCTURE [MEGA BATCH x3]"
if [ "$PROD_CONN" = true ]; then
    # MEGA BATCH 1: System basics (36 single-line commands)
    MEGA1=$(ssh_prod "
hostname
cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'\"' -f2
cat /etc/os-release 2>/dev/null | grep VERSION_ID | cut -d'\"' -f2
uname -r
uname -m
uptime -p
cat /proc/loadavg | cut -d' ' -f1-3
nproc
free | awk '/Mem:/{print \$2}'
free | awk '/Mem:/{print \$3}'
free | awk '/Mem:/{printf \"%.0f\", \$3/\$2*100}'
free -h | awk '/Mem:/{print \$2}'
free -h | awk '/Mem:/{print \$3}'
df -h / | awk 'NR==2{print \$2}'
df -h / | awk 'NR==2{print \$3}'
df -h / | awk 'NR==2{print \$4}'
df -h / | awk 'NR==2{print \$5}' | tr -d '%'
df -i / | awk 'NR==2{print \$5}'
ps aux | wc -l
ps aux | awk '\$8~/Z/{print}' | wc -l
ps aux --sort=-%cpu | head -3 | tail -2 | awk '{printf \"%s %.1f%%\\n\", \$11, \$3}'
ps aux --sort=-%mem | head -3 | tail -2 | awk '{printf \"%s %.1f%%\\n\", \$11, \$4}'
systemctl is-active docker
systemctl is-active nginx
systemctl is-active cron
systemctl is-active sshd || systemctl is-active ssh
systemctl show docker --property=MainPID --value 2>/dev/null || echo '0'
systemctl show nginx --property=MainPID --value 2>/dev/null || echo '0'
systemctl list-units --type=service --state=running | wc -l
systemctl list-units --type=service --state=failed --no-pager --no-legend | wc -l
systemctl list-units --type=service --state=failed --no-pager --no-legend | head -3 | awk '{print \$1}' | tr '\n' ','
ss -s | grep 'estab' | head -1
ss -tlnp | grep LISTEN | awk '{print \$4}' | cut -d: -f2 | sort -u | head -10 | tr '\n' ' '
w -h | wc -l
uptime -s 2>/dev/null || stat -c %y /proc/1 | cut -d. -f1
cat /proc/sys/kernel/hostname
" 60 | tr -d '\r')

    # MEGA BATCH 2: Network & Security (34 single-line commands)
    MEGA2=$(ssh_prod "
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -5 | tr '\n' ','
ip route show default | head -1
cat /etc/resolv.conf | grep nameserver | head -3 | awk '{print \$2}' | tr '\n' ','
ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1 && echo yes || echo no
ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1 && echo yes || echo no
curl -sL -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 5 https://www.google.com 2>/dev/null || echo '000'
ss -tunap 2>/dev/null | wc -l || echo '0'
iptables -L -n 2>/dev/null | grep -c '^Chain' || echo '0'
iptables -L INPUT -n 2>/dev/null | grep -c ACCEPT || echo '0'
iptables -L INPUT -n 2>/dev/null | grep -c DROP || echo '0'
ufw status 2>/dev/null | head -1 || echo 'not_installed'
fail2ban-client status 2>/dev/null | grep 'Number of jail' || echo 'not_installed'
fail2ban-client status sshd 2>/dev/null | grep 'Currently banned' || echo 'no_sshd_jail'
test -f /etc/ssh/sshd_config && echo yes || echo no
grep -i '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | awk '{print \$2}' || echo 'unknown'
grep -i '^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null | awk '{print \$2}' || echo 'unknown'
grep -i '^Port' /etc/ssh/sshd_config 2>/dev/null | awk '{print \$2}' || echo '22'
cat /etc/timezone 2>/dev/null || timedatectl | grep 'Time zone' | awk '{print \$3}'
timedatectl 2>/dev/null | grep -q 'synchronized: yes' && echo yes || echo yes
timedatectl | grep 'NTP service' | awk '{print \$3}'
date '+%Y-%m-%d %H:%M:%S %Z'
systemctl is-active systemd-timesyncd 2>/dev/null || echo 'inactive'
ls -la /etc/ssl/certs/ 2>/dev/null | wc -l || echo '0'
openssl version 2>/dev/null | head -1 || echo 'not_installed'
ls /etc/letsencrypt/live/ 2>/dev/null | head -3 | tr '\n' ',' || echo 'no_letsencrypt'
find /etc/letsencrypt/live -name 'fullchain.pem' 2>/dev/null | wc -l || echo '0'
ss -tunap 2>/dev/null | grep ESTABLISHED | wc -l || echo '0'
ss -tunap 2>/dev/null | grep TIME_WAIT | wc -l || echo '0'
ss -tunap 2>/dev/null | grep LISTEN | wc -l || echo '0'
cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || echo '0'
cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo '0'
cat /proc/sys/fs/file-max 2>/dev/null || echo '0'
cat /proc/sys/fs/file-nr 2>/dev/null | awk '{print \$1}' || echo '0'
ulimit -n
" 60 | tr -d '\r')

    # MEGA BATCH 3: Storage & Logs (35 single-line commands)
    MEGA3=$(ssh_prod "
df -h | awk 'NR>1{printf \"%s: %s used, %s\\n\", \$6, \$3, \$5}' | head -5 | tr '\n' '|'
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null | tail -n +2 | head -10 | tr '\n' '|' || echo 'lsblk_unavailable'
du -sh /var/log 2>/dev/null | cut -f1 || echo '0'
du -sh /var/lib/docker 2>/dev/null | cut -f1 || echo '0'
du -sh /opt 2>/dev/null | cut -f1 || echo '0'
du -sh /root 2>/dev/null | cut -f1 || echo '0'
find /var/log -name '*.log' -type f 2>/dev/null | wc -l || echo '0'
find /var/log -name '*.log' -type f -mtime -1 2>/dev/null | wc -l || echo '0'
tail -100 /var/log/syslog 2>/dev/null | grep -i error | wc -l || tail -100 /var/log/messages 2>/dev/null | grep -i error | wc -l || echo '0'
tail -100 /var/log/auth.log 2>/dev/null | grep -i 'failed password' | wc -l || tail -100 /var/log/secure 2>/dev/null | grep -i 'failed password' | wc -l || echo '0'
dmesg | tail -100 | grep -i error | wc -l
docker info --format '{{.Driver}}' 2>/dev/null || echo 'docker_unavailable'
docker system df --format '{{.Type}}: {{.Size}} ({{.Reclaimable}} reclaimable)' 2>/dev/null | tr '\n' ' | ' || echo 'docker_unavailable'
test -d /opt/tovplay_backups && echo yes || echo no
find /opt/tovplay_backups -type f -mtime -1 2>/dev/null | wc -l || echo '0'
crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l || echo '0'
ls /etc/cron.d/ 2>/dev/null | wc -l || echo '0'
ls /etc/cron.daily/ 2>/dev/null | wc -l || echo '0'
ls /etc/cron.hourly/ 2>/dev/null | wc -l || echo '0'
systemctl list-timers --no-pager 2>/dev/null | tail -n +2 | wc -l || echo '0'
dpkg -l 2>/dev/null | wc -l || rpm -qa 2>/dev/null | wc -l || echo '0'
which python3 >/dev/null 2>&1 && python3 --version || echo 'not_installed'
which node >/dev/null 2>&1 && node --version || echo 'not_installed'
which npm >/dev/null 2>&1 && npm --version || echo 'not_installed'
which git >/dev/null 2>&1 && git --version || echo 'not_installed'
which curl >/dev/null 2>&1 && curl --version | head -1 || echo 'not_installed'
which nginx >/dev/null 2>&1 && nginx -v 2>&1 || echo 'not_installed'
which docker >/dev/null 2>&1 && docker --version || echo 'not_installed'
which certbot >/dev/null 2>&1 && certbot --version 2>&1 | head -1 || echo 'not_installed'
cat /proc/sys/fs/file-max 2>/dev/null || echo '0'
cat /proc/sys/fs/file-nr 2>/dev/null | awk '{print \$1}' || echo '0'
ulimit -n
who | wc -l
last -n 5 --time-format=iso | head -5 | awk '{printf \"%s %s %s | \", \$1, \$3, \$4}'
systemctl list-units --type=service --state=failed | wc -l
" 60 | tr -d '\r')

    # Parse MEGA BATCH 1
    IFS=$'\n' read -d '' -r -a L1 <<< "$MEGA1"
    HOSTNAME="${L1[0]}"
    OS_NAME="${L1[1]}"
    OS_VERSION="${L1[2]}"
    KERNEL="${L1[3]}"
    ARCH="${L1[4]}"
    UPTIME="${L1[5]}"
    LOAD="${L1[6]}"
    CPU_CORES="${L1[7]}"
    MEM_TOTAL="${L1[8]}"
    MEM_USED="${L1[9]}"
    MEM_PCT="${L1[10]}"
    MEM_TOTAL_H="${L1[11]}"
    MEM_USED_H="${L1[12]}"
    DISK_TOTAL="${L1[13]}"
    DISK_USED="${L1[14]}"
    DISK_AVAIL="${L1[15]}"
    DISK_PCT="${L1[16]}"
    INODES="${L1[17]}"
    PROCESSES="${L1[18]}"
    ZOMBIE="${L1[19]}"
    TOP_CPU="${L1[20]}"$'\n'"${L1[21]}"
    TOP_MEM="${L1[22]}"$'\n'"${L1[23]}"
    DOCKER_STATUS="${L1[24]}"
    NGINX_STATUS="${L1[25]}"
    CRON_STATUS="${L1[26]}"
    SSHD_STATUS="${L1[27]}"
    DOCKER_PID="${L1[28]}"
    NGINX_PID="${L1[29]}"
    SERVICES_RUNNING="${L1[30]}"
    SERVICES_FAILED="${L1[31]}"
    FAILED_SERVICES="${L1[32]}"
    CONNECTIONS="${L1[33]}"
    PORTS="${L1[34]}"
    USERS_LOGGED="${L1[35]}"
    BOOT_TIME="${L1[36]}"
    SYS_HOSTNAME="${L1[37]}"

    # Parse MEGA BATCH 2
    IFS=$'\n' read -d '' -r -a L2 <<< "$MEGA2"
    IPV4_ADDRS="${L2[0]}"
    DEFAULT_ROUTE="${L2[1]}"
    DNS_SERVERS="${L2[2]}"
    PING_GOOGLE="${L2[3]}"
    PING_CF="${L2[4]}"
    HTTPS_CHECK="${L2[5]}"
    TOTAL_CONNS="${L2[6]}"
    IPTABLES_CHAINS="${L2[7]}"
    IPTABLES_ACCEPT="${L2[8]}"
    IPTABLES_DROP="${L2[9]}"
    UFW_STATUS="${L2[10]}"
    FAIL2BAN="${L2[11]}"
    FAIL2BAN_SSHD="${L2[12]}"
    SSHD_CONFIG="${L2[13]}"
    ROOT_LOGIN="${L2[14]}"
    PASS_AUTH="${L2[15]}"
    SSH_PORT="${L2[16]}"
    TIMEZONE="${L2[17]}"
    TIME_SYNC="${L2[18]}"
    NTP_SERVICE="${L2[19]}"
    CURRENT_TIME="${L2[20]}"
    TIMESYNCD="${L2[21]}"
    SSL_CERTS_COUNT="${L2[22]}"
    OPENSSL_VER="${L2[23]}"
    LETSENCRYPT="${L2[24]}"
    LE_CERTS="${L2[25]}"
    ESTABLISHED="${L2[26]}"
    TIME_WAIT="${L2[27]}"
    LISTEN_SOCKETS="${L2[28]}"
    TCP_SYNCOOKIES="${L2[29]}"
    ASLR="${L2[30]}"
    FILE_MAX="${L2[31]}"
    FILE_NR="${L2[32]}"
    ULIMIT="${L2[33]}"

    # Parse MEGA BATCH 3
    IFS=$'\n' read -d '' -r -a L3 <<< "$MEGA3"
    DISKS="${L3[0]}"
    LSBLK="${L3[1]}"
    VAR_LOG_SIZE="${L3[2]}"
    DOCKER_SIZE="${L3[3]}"
    OPT_SIZE="${L3[4]}"
    ROOT_SIZE="${L3[5]}"
    LOG_FILES="${L3[6]}"
    RECENT_LOGS="${L3[7]}"
    SYSLOG_ERRORS="${L3[8]}"
    AUTH_FAILURES="${L3[9]}"
    DMESG_ERRORS="${L3[10]}"
    DOCKER_DRIVER="${L3[11]}"
    DOCKER_DF="${L3[12]}"
    BACKUP_DIR="${L3[13]}"
    RECENT_BACKUPS="${L3[14]}"
    USER_CRONS="${L3[15]}"
    CRON_D="${L3[16]}"
    CRON_DAILY="${L3[17]}"
    CRON_HOURLY="${L3[18]}"
    TIMERS_COUNT="${L3[19]}"
    PACKAGES="${L3[20]}"
    PYTHON_VER="${L3[21]}"
    NODE_VER="${L3[22]}"
    NPM_VER="${L3[23]}"
    GIT_VER="${L3[24]}"
    CURL_VER="${L3[25]}"
    NGINX_VER="${L3[26]}"
    DOCKER_VER="${L3[27]}"
    CERTBOT_VER="${L3[28]}"
    FILE_MAX_2="${L3[29]}"
    FILE_NR_2="${L3[30]}"
    ULIMIT_2="${L3[31]}"
    WHO_COUNT="${L3[32]}"
    LAST_LOGINS="${L3[33]}"
    SERVICES_FAILED_2="${L3[34]}"

    # Display results
    echo -e "${CYAN}System Information:${NC}"
    check_info "Hostname: $HOSTNAME ($SYS_HOSTNAME)"
    check_info "OS: $OS_NAME $OS_VERSION"
    check_info "Kernel: $KERNEL ($ARCH)"
    check_info "Uptime: $UPTIME (since $BOOT_TIME)"
    check_info "Timezone: $TIMEZONE | Current time: $CURRENT_TIME"

    echo -e "\n${CYAN}CPU & Load:${NC}"
    check_info "Cores: $CPU_CORES | Load: $LOAD"
    LOAD1=$(echo "$LOAD" | cut -d' ' -f1 | cut -d. -f1)
    [ "${LOAD1:-0}" -gt "$((CPU_CORES * 2))" ] 2>/dev/null && { check_warn "High load: $LOAD"; add_high "[PROD] CPU overloaded"; } || check_pass "CPU load: OK"
    echo -e "${CYAN}Top CPU:${NC}"
    echo "$TOP_CPU" | while read -r line; do [ -n "$line" ] && check_info "  $line"; done
    echo -e "${CYAN}Top Memory:${NC}"
    echo "$TOP_MEM" | while read -r line; do [ -n "$line" ] && check_info "  $line"; done

    echo -e "\n${CYAN}Memory:${NC}"
    check_info "Total: $MEM_TOTAL_H | Used: $MEM_USED_H | Usage: ${MEM_PCT}%"
    [ "${MEM_PCT:-0}" -gt 90 ] 2>/dev/null && { check_fail "Memory critical: ${MEM_PCT}%"; add_critical "[PROD] Memory >90%"; } || \
    [ "${MEM_PCT:-0}" -gt 80 ] 2>/dev/null && { check_warn "Memory high: ${MEM_PCT}%"; add_high "[PROD] Memory >80%"; } || check_pass "Memory usage: OK"

    echo -e "\n${CYAN}Disk:${NC}"
    check_info "Root: $DISK_TOTAL total, $DISK_USED used, $DISK_AVAIL available (${DISK_PCT}%)"
    check_info "Inodes: $INODES"
    [ "${DISK_PCT:-0}" -gt 95 ] 2>/dev/null && { check_fail "Disk critical: ${DISK_PCT}%"; add_critical "[PROD] Disk >95%"; } || \
    [ "${DISK_PCT:-0}" -gt 90 ] 2>/dev/null && { check_warn "Disk high: ${DISK_PCT}%"; add_medium "[PROD] Disk >90%"; } || check_pass "Disk usage: OK"

    echo -e "\n${CYAN}All Filesystems:${NC}"
    echo "$DISKS" | tr '|' '\n' | head -5 | while read -r line; do
        [ -n "$line" ] && check_info "$line"
    done

    echo -e "\n${CYAN}Block Devices:${NC}"
    echo "$LSBLK" | tr '|' '\n' | head -10 | while read -r line; do
        [ -n "$line" ] && [ "$line" != "lsblk_unavailable" ] && check_info "$line"
    done

    echo -e "\n${CYAN}Directory Sizes:${NC}"
    check_info "/var/log: $VAR_LOG_SIZE | /var/lib/docker: $DOCKER_SIZE"
    check_info "/opt: $OPT_SIZE | /root: $ROOT_SIZE"

    echo -e "\n${CYAN}Processes:${NC}"
    check_info "Running: $PROCESSES | Zombie: $ZOMBIE"
    [ "${ZOMBIE:-0}" -gt 5 ] 2>/dev/null && { check_warn "Zombie processes: $ZOMBIE"; add_low "[PROD] Zombie processes"; } || check_pass "No zombie processes"

    echo -e "\n${CYAN}Services:${NC}"
    [ "$DOCKER_STATUS" = "active" ] && check_pass "Docker: active (PID: $DOCKER_PID)" || { check_fail "Docker: $DOCKER_STATUS"; add_critical "[PROD] Docker down"; }
    [ "$NGINX_STATUS" = "active" ] && check_pass "Nginx: active (PID: $NGINX_PID)" || { check_fail "Nginx: $NGINX_STATUS"; add_critical "[PROD] Nginx down"; }
    [ "$CRON_STATUS" = "active" ] && check_pass "Cron: active" || check_warn "Cron: $CRON_STATUS"
    [ "$SSHD_STATUS" = "active" ] && check_pass "SSH: active" || check_warn "SSH: $SSHD_STATUS"
    check_info "Running services: $SERVICES_RUNNING | Failed: $SERVICES_FAILED"
    if [ "${SERVICES_FAILED:-0}" -gt 0 ] 2>/dev/null; then
        check_warn "Failed services: $FAILED_SERVICES"
        add_high "[PROD] Failed services"
    fi

    echo -e "\n${CYAN}Network:${NC}"
    check_info "IPv4 addresses: $(echo $IPV4_ADDRS | tr ',' ' ')"
    check_info "Default route: $DEFAULT_ROUTE"
    check_info "DNS servers: $(echo $DNS_SERVERS | tr ',' ' ')"
    check_info "Open ports: $PORTS"
    check_info "$CONNECTIONS"
    check_info "Connection states: EST: $ESTABLISHED, TIME_WAIT: $TIME_WAIT, LISTEN: $LISTEN_SOCKETS"
    [ "$PING_GOOGLE" = "yes" ] && check_pass "Internet: reachable (8.8.8.8)" || check_warn "Cannot reach 8.8.8.8"
    [ "$PING_CF" = "yes" ] && check_pass "Internet: reachable (1.1.1.1)" || check_warn "Cannot reach 1.1.1.1"
    [ "$HTTPS_CHECK" = "200" ] && check_pass "HTTPS: working" || check_warn "HTTPS check failed"

    echo -e "\n${CYAN}Security:${NC}"
    [ "$SSHD_CONFIG" = "yes" ] && check_pass "SSH config: exists" || check_warn "SSH config missing"
    [ "$ROOT_LOGIN" != "yes" ] && check_pass "Root login: disabled ($ROOT_LOGIN)" || { check_warn "Root login: enabled"; add_medium "[PROD] Disable root SSH"; }
    [ "$PASS_AUTH" != "yes" ] && check_info "Password auth: disabled" || check_info "Password auth: enabled"
    check_info "SSH port: $SSH_PORT"
    [ "${IPTABLES_CHAINS:-0}" -gt 0 ] 2>/dev/null && check_info "iptables: $IPTABLES_CHAINS chains ($IPTABLES_ACCEPT accept, $IPTABLES_DROP drop)" || check_info "iptables: not configured"
    [ "$UFW_STATUS" != "not_installed" ] && check_info "UFW: $UFW_STATUS" || check_info "UFW: not installed"
    [ "$FAIL2BAN" != "not_installed" ] && check_pass "fail2ban: installed" || check_info "fail2ban: not installed"
    [ "$TCP_SYNCOOKIES" = "1" ] && check_pass "SYN cookies: enabled" || check_info "SYN cookies: disabled"
    [ "$ASLR" = "2" ] && check_pass "ASLR: full randomization" || check_info "ASLR: $ASLR"
    [ "${AUTH_FAILURES:-0}" -gt 10 ] 2>/dev/null && { check_warn "Failed SSH logins: $AUTH_FAILURES"; add_low "[PROD] Many failed logins"; } || check_pass "Failed SSH logins: ${AUTH_FAILURES:-0}"

    echo -e "\n${CYAN}SSL/TLS:${NC}"
    check_info "SSL certificates: $SSL_CERTS_COUNT"
    [ "$OPENSSL_VER" != "not_installed" ] && check_pass "OpenSSL: $OPENSSL_VER" || check_warn "OpenSSL not installed"
    check_info "Letsencrypt: $(echo $LETSENCRYPT | tr ',' ' ')"
    [ "${LE_CERTS:-0}" -gt 0 ] 2>/dev/null && check_pass "Letsencrypt certs: $LE_CERTS" || check_info "No Letsencrypt certs"

    echo -e "\n${CYAN}Time Synchronization:${NC}"
    # Direct check to avoid array parsing issues
    TIME_SYNC_DIRECT=$(ssh_prod 'timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo unknown' 5 | tr -d '\r')
    [ "$TIME_SYNC_DIRECT" = "yes" ] && check_pass "Time sync: active" || { check_warn "Time not synchronized"; add_medium "[PROD] Time not synced"; }
    [ "$TIMESYNCD" = "active" ] && check_pass "systemd-timesyncd: active" || check_info "systemd-timesyncd: $TIMESYNCD"
    check_info "NTP service: $NTP_SERVICE"

    echo -e "\n${CYAN}Logs & Errors:${NC}"
    check_info "Log files: $LOG_FILES | Modified (24h): $RECENT_LOGS"
    check_info "/var/log size: $VAR_LOG_SIZE"
    [ "${SYSLOG_ERRORS:-0}" -gt 20 ] 2>/dev/null && { check_warn "Syslog errors: $SYSLOG_ERRORS"; add_low "[PROD] Many syslog errors"; } || check_pass "Syslog errors: ${SYSLOG_ERRORS:-0}"
    [ "${DMESG_ERRORS:-0}" -gt 10 ] 2>/dev/null && { check_warn "Kernel errors: $DMESG_ERRORS"; add_medium "[PROD] Kernel errors"; } || check_pass "Kernel errors: ${DMESG_ERRORS:-0}"

    echo -e "\n${CYAN}Docker:${NC}"
    [ "$DOCKER_DRIVER" != "docker_unavailable" ] && check_pass "Docker driver: $DOCKER_DRIVER" || check_info "Docker unavailable"
    check_info "Docker disk: $(echo $DOCKER_DF | sed 's/|/, /g')"

    echo -e "\n${CYAN}Backups:${NC}"
    [ "$BACKUP_DIR" = "yes" ] && check_pass "Backup directory: exists (/opt/tovplay_backups)" || check_info "No backup directory"
    [ "${RECENT_BACKUPS:-0}" -gt 0 ] 2>/dev/null && check_pass "Recent backups: $RECENT_BACKUPS files (24h)" || check_info "No recent backups"

    echo -e "\n${CYAN}Scheduled Tasks:${NC}"
    [ "${USER_CRONS:-0}" -gt 0 ] 2>/dev/null && check_info "User crontab: $USER_CRONS lines" || check_info "No user crontab"
    check_info "Cron directories: daily=$CRON_DAILY, hourly=$CRON_HOURLY, d=$CRON_D"
    [ "${TIMERS_COUNT:-0}" -gt 0 ] 2>/dev/null && check_info "Systemd timers: $TIMERS_COUNT" || check_info "No systemd timers"

    echo -e "\n${CYAN}Installed Software:${NC}"
    check_info "Packages: $PACKAGES"
    [ "$PYTHON_VER" != "not_installed" ] && check_pass "Python: $PYTHON_VER" || check_info "Python: not installed"
    [ "$NODE_VER" != "not_installed" ] && check_pass "Node: $NODE_VER" || check_info "Node: not installed"
    [ "$NPM_VER" != "not_installed" ] && check_pass "npm: $NPM_VER" || check_info "npm: not installed"
    [ "$GIT_VER" != "not_installed" ] && check_pass "Git: $GIT_VER" || check_info "Git: not installed"
    [ "$CURL_VER" != "not_installed" ] && check_pass "curl: $(echo $CURL_VER | head -c 60)" || check_info "curl: not installed"
    [ "$NGINX_VER" != "not_installed" ] && check_pass "Nginx: $NGINX_VER" || check_info "Nginx: not installed"
    [ "$DOCKER_VER" != "not_installed" ] && check_pass "Docker: $DOCKER_VER" || check_info "Docker: not installed"
    [ "$CERTBOT_VER" != "not_installed" ] && check_pass "Certbot: $CERTBOT_VER" || check_info "Certbot: not installed"

    echo -e "\n${CYAN}System Limits:${NC}"
    check_info "Max open files: $FILE_MAX | Current: $FILE_NR"
    check_info "ulimit -n: $ULIMIT"
    [ "${FILE_NR:-0}" -gt "$((FILE_MAX * 80 / 100))" ] 2>/dev/null && { check_warn "File descriptors high: $FILE_NR / $FILE_MAX"; add_medium "[PROD] File descriptors"; }

    echo -e "\n${CYAN}Users & Sessions:${NC}"
    check_info "Logged in users: $WHO_COUNT"
    [ "${USERS_LOGGED:-0}" -gt 5 ] 2>/dev/null && check_warn "Many sessions: $USERS_LOGGED" || check_pass "Active sessions: $USERS_LOGGED"
    check_info "Recent logins: $(echo $LAST_LOGINS | sed 's/|/, /g')"
fi

section "61-80" "STAGING INFRASTRUCTURE [MEGA BATCH]"
if [ "$STAGING_CONN" = true ]; then
    MEGA_STG=$(ssh_staging "
hostname
uname -r
uptime -p
cat /proc/loadavg | cut -d' ' -f1-3
free | awk '/Mem:/{printf \"%.0f\", \$3/\$2*100}'
free -h | awk '/Mem:/{print \$2,\$3}'
df -h / | awk 'NR==2{print \$5}' | tr -d '%'
df -h / | awk 'NR==2{print \$2,\$3,\$4}'
systemctl is-active docker
systemctl is-active nginx
ss -s | grep 'estab' | head -1
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -3 | tr '\n' ','
ps aux | wc -l
systemctl list-units --type=service --state=running | wc -l
systemctl list-units --type=service --state=failed | wc -l
" 60 | tr -d '\r')

    IFS=$'\n' read -d '' -r -a STG <<< "$MEGA_STG"
    STG_HOST="${STG[0]}"
    STG_KERNEL="${STG[1]}"
    STG_UPTIME="${STG[2]}"
    STG_LOAD="${STG[3]}"
    STG_MEM_PCT="${STG[4]}"
    STG_MEM="${STG[5]}"
    STG_DISK_PCT="${STG[6]}"
    STG_DISK="${STG[7]}"
    STG_DOCKER="${STG[8]}"
    STG_NGINX="${STG[9]}"
    STG_CONNS="${STG[10]}"
    STG_IPS="${STG[11]}"
    STG_PROCS="${STG[12]}"
    STG_SERVICES="${STG[13]}"
    STG_FAILED="${STG[14]}"

    check_info "Hostname: $STG_HOST"
    check_info "Kernel: $STG_KERNEL | Uptime: $STG_UPTIME"
    check_info "Load: $STG_LOAD"
    check_info "Memory: $STG_MEM (${STG_MEM_PCT}%)"
    [ "${STG_MEM_PCT:-0}" -gt 90 ] 2>/dev/null && check_warn "Memory high: ${STG_MEM_PCT}%" || check_pass "Memory OK: ${STG_MEM_PCT}%"
    check_info "Disk: $STG_DISK (${STG_DISK_PCT}%)"
    [ "${STG_DISK_PCT:-0}" -gt 90 ] 2>/dev/null && check_warn "Disk high: ${STG_DISK_PCT}%" || check_pass "Disk OK: ${STG_DISK_PCT}%"
    [ "$STG_DOCKER" = "active" ] && check_pass "Docker: active" || check_warn "Docker: $STG_DOCKER"
    [ "$STG_NGINX" = "active" ] && check_pass "Nginx: active" || check_warn "Nginx: $STG_NGINX"
    check_info "Processes: $STG_PROCS"
    check_info "Services: $STG_SERVICES running, $STG_FAILED failed"
    check_info "$STG_CONNS"
    check_info "IP addresses: $(echo $STG_IPS | tr ',' ' ')"
fi

section "81-90" "COMPARISON"
echo -e "  ${BOLD}Metric              Production         Staging${NC}"
echo -e "  ──────────────────────────────────────────────────────"
printf "  %-18s %-18s %s\n" "Memory" "${MEM_PCT:-?}%" "${STG_MEM_PCT:-?}%"
printf "  %-18s %-18s %s\n" "Disk" "${DISK_PCT:-?}%" "${STG_DISK_PCT:-?}%"
printf "  %-18s %-18s %s\n" "Docker" "${DOCKER_STATUS:-?}" "${STG_DOCKER:-?}"
printf "  %-18s %-18s %s\n" "Nginx" "${NGINX_STATUS:-?}" "${STG_NGINX:-?}"
printf "  %-18s %-18s %s\n" "Services" "${SERVICES_RUNNING:-?}" "${STG_SERVICES:-?}"

print_summary
