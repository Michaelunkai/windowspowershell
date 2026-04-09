#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# DEEP SECURITY AUDIT v6.0 [5X ENHANCED] - MEGA BATCH Edition
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
SCORE=100

section() { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }
check_pass() { echo -e "  ${GREEN}✓${NC} $1"; }
check_fail() { echo -e "  ${RED}✗${NC} $1"; }
check_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
check_info() { echo -e "  ${BLUE}ℹ${NC} $1"; }

add_critical() { CRITICAL_ISSUES+=("$1"); SCORE=$((SCORE - 20)); }
add_high() { HIGH_ISSUES+=("$1"); SCORE=$((SCORE - 10)); }
add_medium() { MEDIUM_ISSUES+=("$1"); SCORE=$((SCORE - 5)); }
add_low() { LOW_ISSUES+=("$1"); SCORE=$((SCORE - 2)); }

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     🔒 SECURITY AUDIT v6.0 [5X ENHANCED] - $(date '+%Y-%m-%d %H:%M:%S')       ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 15)
STAGING_OK=$(ssh_staging "echo OK" 15)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { STAGING_CONN=false; }

section "2-40. COMPREHENSIVE SECURITY AUDIT [MEGA BATCH x2]"
if [ "$PROD_CONN" = true ]; then
    # MEGA BATCH 1: Firewall, SSH, Fail2Ban, Ports, Authentication (55 single-line commands)
    MEGA1=$(ssh_prod "
ufw status 2>/dev/null | grep -q 'Status: active' && echo yes || echo no
{ ufw status numbered 2>/dev/null | tail -n +4 | head -5 | tr '\n' '|'; echo; } || echo 'not_active'
iptables -L -n 2>/dev/null | grep -c '^Chain' || echo 0
iptables -L INPUT -n 2>/dev/null | grep -c ACCEPT || echo 0
iptables -L INPUT -n 2>/dev/null | grep -c DROP || echo 0
iptables -L INPUT -n 2>/dev/null | grep -c REJECT || echo 0
{ ss -tlnp 2>/dev/null | grep LISTEN | sed 's/.*://;s/[[:space:]].*//' | sort -u | head -20 | tr '\n' ' '; echo; }
ss -tunap 2>/dev/null | wc -l || echo 0
ss -tunap 2>/dev/null | grep ESTABLISHED | wc -l || echo 0
ss -tunap 2>/dev/null | grep SYN_SENT | wc -l || echo 0
ss -tunap 2>/dev/null | grep TIME_WAIT | wc -l || echo 0
{ grep '^Port' /etc/ssh/sshd_config 2>/dev/null | sed 's/^Port[[:space:]]*//' | grep .; } || echo 22
{ grep '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | sed 's/^PermitRootLogin[[:space:]]*//' | grep .; } || echo unknown
{ grep '^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null | sed 's/^PasswordAuthentication[[:space:]]*//' | grep .; } || echo unknown
{ grep '^PubkeyAuthentication' /etc/ssh/sshd_config 2>/dev/null | sed 's/^PubkeyAuthentication[[:space:]]*//' | grep .; } || echo unknown
{ grep '^PermitEmptyPasswords' /etc/ssh/sshd_config 2>/dev/null | sed 's/^PermitEmptyPasswords[[:space:]]*//' | grep .; } || echo no
{ grep '^MaxAuthTries' /etc/ssh/sshd_config 2>/dev/null | sed 's/^MaxAuthTries[[:space:]]*//' | grep .; } || echo 6
{ grep '^MaxSessions' /etc/ssh/sshd_config 2>/dev/null | sed 's/^MaxSessions[[:space:]]*//' | grep .; } || echo 10
{ grep '^ClientAliveInterval' /etc/ssh/sshd_config 2>/dev/null | sed 's/^ClientAliveInterval[[:space:]]*//' | grep .; } || echo 0
{ grep '^ClientAliveCountMax' /etc/ssh/sshd_config 2>/dev/null | sed 's/^ClientAliveCountMax[[:space:]]*//' | grep .; } || echo 3
{ grep '^X11Forwarding' /etc/ssh/sshd_config 2>/dev/null | sed 's/^X11Forwarding[[:space:]]*//' | grep .; } || echo unknown
{ grep '^AllowUsers' /etc/ssh/sshd_config 2>/dev/null | sed 's/^AllowUsers[[:space:]]*//' | grep .; } || echo none
{ grep '^AllowGroups' /etc/ssh/sshd_config 2>/dev/null | sed 's/^AllowGroups[[:space:]]*//' | grep .; } || echo none
{ grep '^DenyUsers' /etc/ssh/sshd_config 2>/dev/null | sed 's/^DenyUsers[[:space:]]*//' | grep .; } || echo none
{ grep '^Protocol' /etc/ssh/sshd_config 2>/dev/null | sed 's/^Protocol[[:space:]]*//' | grep .; } || echo 2
systemctl is-active fail2ban 2>/dev/null || echo not_installed
{ fail2ban-client status 2>/dev/null | grep 'Number of jail' | sed 's/.*:[[:space:]]*//' | grep .; } || echo 0
{ fail2ban-client status sshd 2>/dev/null | grep 'Currently banned' | sed 's/.*:[[:space:]]*//' | grep .; } || echo 0
{ fail2ban-client status sshd 2>/dev/null | grep 'Total banned' | sed 's/.*:[[:space:]]*//' | grep .; } || echo 0
tail -100 /var/log/auth.log 2>/dev/null | grep -i 'failed\|invalid' | wc -l
tail -100 /var/log/auth.log 2>/dev/null | grep -i 'accepted' | wc -l
{ last -n 10 --time-format=iso | head -10 | cut -d' ' -f1,3 | tr '\n' '|'; echo; }
who | wc -l
cat /etc/security/limits.conf 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l
cat /etc/pam.d/common-password 2>/dev/null | grep -v '^#' | wc -l
{ grep PASS_MAX_DAYS /etc/login.defs 2>/dev/null | grep -v '^#' | sed 's/.*PASS_MAX_DAYS[[:space:]]*//' | grep .; } || echo 99999
{ grep PASS_MIN_DAYS /etc/login.defs 2>/dev/null | grep -v '^#' | sed 's/.*PASS_MIN_DAYS[[:space:]]*//' | grep .; } || echo 0
{ grep PASS_MIN_LEN /etc/login.defs 2>/dev/null | grep -v '^#' | sed 's/.*PASS_MIN_LEN[[:space:]]*//' | grep .; } || echo 5
{ grep PASS_WARN_AGE /etc/login.defs 2>/dev/null | grep -v '^#' | sed 's/.*PASS_WARN_AGE[[:space:]]*//' | grep .; } || echo 7
{ grep ':0:' /etc/passwd 2>/dev/null | cut -d: -f1 | tr '\n' ',' | sed 's/,$//'; echo; } || echo root
sudo grep '::' /etc/shadow 2>/dev/null | wc -l || echo 0
cat /etc/passwd | wc -l
cat /etc/group | wc -l
find /home -name '.ssh' -type d 2>/dev/null | wc -l
find /root/.ssh -name 'authorized_keys' -type f 2>/dev/null | wc -l
cat /root/.ssh/authorized_keys 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l
getent group sudo 2>/dev/null | cut -d: -f4 | tr ',' ' ' || echo none
cat /proc/sys/net/ipv4/tcp_syncookies
cat /proc/sys/net/ipv4/icmp_echo_ignore_all
cat /proc/sys/net/ipv4/ip_forward
cat /proc/sys/net/ipv4/conf/all/rp_filter
cat /proc/sys/net/ipv4/conf/all/accept_source_route
cat /proc/sys/net/ipv4/conf/all/accept_redirects
cat /proc/sys/net/ipv4/conf/all/send_redirects
cat /proc/sys/net/ipv4/conf/all/log_martians
cat /proc/sys/kernel/randomize_va_space
" 60 | tr -d '\r')

    # MEGA BATCH 2: SSL/TLS, Secrets, Updates, Permissions, Docker Security (50 single-line commands)
    MEGA2=$(ssh_prod "
openssl s_client -connect localhost:443 -servername app.tovplay.org </dev/null 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo unknown
openssl s_client -connect localhost:443 -servername app.tovplay.org </dev/null 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null | cut -d= -f2- || echo unknown
openssl s_client -connect localhost:443 -servername app.tovplay.org </dev/null 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | cut -d= -f2- || echo unknown
ls /etc/letsencrypt/live/ 2>/dev/null | wc -l || echo 0
find /etc/letsencrypt/live -name 'fullchain.pem' 2>/dev/null | wc -l || echo 0
{ openssl version 2>/dev/null | cut -d' ' -f2 | grep .; } || echo unknown
find /root /opt -name '.env*' -o -name '*.env' 2>/dev/null | head -10 | wc -l
find /var/www -name '.env*' 2>/dev/null | wc -l
grep -r 'password\|secret\|api_key' /opt/tovplay-backend/*.py 2>/dev/null | grep -v '.pyc' | wc -l || echo 0
find /root -name '*.pem' -o -name '*.key' 2>/dev/null | wc -l
find /etc/ssl/private -type f 2>/dev/null | wc -l
stat -c '%a' /etc/ssl/private 2>/dev/null || echo 0
apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0
apt list --upgradable 2>/dev/null | grep -i security | wc -l
systemctl is-active unattended-upgrades 2>/dev/null || echo inactive
stat -c %Y /var/lib/apt/periodic/update-success-stamp 2>/dev/null || echo 0
dpkg --audit 2>/dev/null | wc -l
dpkg --get-selections | grep -c hold || echo 0
find /etc /var/www -perm -002 -type f 2>/dev/null | wc -l
find /etc /var/www -perm -002 -type d 2>/dev/null | wc -l
find /etc/nginx /etc/apache2 -type f -perm /o+w 2>/dev/null | wc -l || echo 0
find /root -name '*.sh' -type f ! -perm -u+x 2>/dev/null | wc -l
ls -la / 2>/dev/null | grep 'drwxrwxrwx' | wc -l
docker ps --format '{{.Names}}' -f 'privileged=true' 2>/dev/null | wc -l
docker ps -q 2>/dev/null | xargs -I {} docker inspect --format '{{.Name}}: {{.Config.User}}' {} 2>/dev/null | grep -E ': $' | wc -l
docker ps --format '{{.Ports}}' 2>/dev/null | grep -oP '0.0.0.0:\d+' | wc -l
docker ps --format '{{.Names}}' 2>/dev/null | wc -l
docker images -f dangling=true 2>/dev/null | tail -n +2 | wc -l
docker volume ls -f dangling=true 2>/dev/null | tail -n +2 | wc -l
docker network ls 2>/dev/null | tail -n +2 | wc -l
docker ps --format '{{.Names}}: {{.Status}}' 2>/dev/null | grep -c '(healthy)' || echo 0
docker ps --format '{{.Names}}: {{.Status}}' 2>/dev/null | grep -c '(unhealthy)' || echo 0
{ docker stats --no-stream --format '{{.Container}}: CPU {{.CPUPerc}}, Mem {{.MemPerc}}' 2>/dev/null | head -5 | tr '\n' '|'; echo; }
systemctl is-active docker
docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo unknown
test -f /etc/docker/daemon.json && echo yes || echo no
cat /etc/docker/daemon.json 2>/dev/null | grep -c 'live-restore' || echo 0
journalctl -u docker --since '1 hour ago' --no-pager 2>/dev/null | grep -i error | wc -l
find /var/lib/docker -name 'Dockerfile' 2>/dev/null | wc -l
{ ls -la /var/run/docker.sock 2>/dev/null | cut -d' ' -f1 | grep .; } || echo unknown
stat -c '%a' /var/run/docker.sock 2>/dev/null || echo 0
apparmor_status 2>/dev/null | grep -c 'docker' || echo 0
aa-status 2>/dev/null | grep -c 'enforce' || echo 0
test -d /sys/fs/selinux && echo yes || echo no
getenforce 2>/dev/null || echo disabled
cat /proc/sys/kernel/dmesg_restrict
cat /proc/sys/kernel/kptr_restrict
systemctl is-active apparmor 2>/dev/null || echo not_installed
systemctl is-active auditd 2>/dev/null || echo not_installed
" 60 | tr -d '\r')

    # Parse MEGA BATCH 1
    IFS=$'\n' read -d '' -r -a L1 <<< "$MEGA1"
    UFW_ACTIVE="${L1[0]}"
    UFW_RULES="${L1[1]}"
    IPTABLES_CHAINS="${L1[2]}"
    IPTABLES_ACCEPT="${L1[3]}"
    IPTABLES_DROP="${L1[4]}"
    IPTABLES_REJECT="${L1[5]}"
    OPEN_PORTS="${L1[6]}"
    TOTAL_CONNS="${L1[7]}"
    ESTABLISHED="${L1[8]}"
    SYN_SENT="${L1[9]}"
    TIME_WAIT="${L1[10]}"
    SSH_PORT="${L1[11]}"
    SSH_ROOT="${L1[12]}"
    SSH_PASSWD="${L1[13]}"
    SSH_PUBKEY="${L1[14]}"
    SSH_EMPTY_PASS="${L1[15]}"
    SSH_MAX_AUTH="${L1[16]}"
    SSH_MAX_SESSIONS="${L1[17]}"
    SSH_ALIVE_INTERVAL="${L1[18]}"
    SSH_ALIVE_COUNT="${L1[19]}"
    SSH_X11="${L1[20]}"
    SSH_ALLOW_USERS="${L1[21]}"
    SSH_ALLOW_GROUPS="${L1[22]}"
    SSH_DENY_USERS="${L1[23]}"
    SSH_PROTOCOL="${L1[24]}"
    FAIL2BAN_STATUS="${L1[25]}"
    FAIL2BAN_JAILS="${L1[26]}"
    FAIL2BAN_BANNED="${L1[27]}"
    FAIL2BAN_TOTAL="${L1[28]}"
    AUTH_FAILS="${L1[29]}"
    AUTH_SUCCESS="${L1[30]}"
    LAST_LOGINS="${L1[31]}"
    WHO_COUNT="${L1[32]}"
    LIMITS_CONF="${L1[33]}"
    PAM_LINES="${L1[34]}"
    PASS_MAX_DAYS="${L1[35]}"
    PASS_MIN_DAYS="${L1[36]}"
    PASS_MIN_LEN="${L1[37]}"
    PASS_WARN_AGE="${L1[38]}"
    UID_ZERO="${L1[39]}"
    EMPTY_PASS="${L1[40]}"
    USERS_COUNT="${L1[41]}"
    GROUPS_COUNT="${L1[42]}"
    SSH_DIRS="${L1[43]}"
    AUTH_KEYS_ROOT="${L1[44]}"
    AUTH_KEYS_COUNT="${L1[45]}"
    SUDO_USERS="${L1[46]}"
    TCP_SYNCOOKIES="${L1[47]}"
    ICMP_IGNORE="${L1[48]}"
    IP_FORWARD="${L1[49]}"
    RP_FILTER="${L1[50]}"
    ACCEPT_SOURCE="${L1[51]}"
    ACCEPT_REDIRECTS="${L1[52]}"
    SEND_REDIRECTS="${L1[53]}"
    LOG_MARTIANS="${L1[54]}"
    ASLR="${L1[55]}"

    # Parse MEGA BATCH 2
    IFS=$'\n' read -d '' -r -a L2 <<< "$MEGA2"
    SSL_EXPIRY="${L2[0]}"
    SSL_ISSUER="${L2[1]}"
    SSL_SUBJECT="${L2[2]}"
    LE_DOMAINS="${L2[3]}"
    LE_CERTS="${L2[4]}"
    OPENSSL_VER="${L2[5]}"
    ENV_FILES="${L2[6]}"
    ENV_VARWWW="${L2[7]}"
    SECRETS_CODE="${L2[8]}"
    PEM_FILES="${L2[9]}"
    SSL_PRIVATE="${L2[10]}"
    SSL_PERMS="${L2[11]}"
    UPGRADABLE="${L2[12]}"
    SEC_UPDATES="${L2[13]}"
    UNATTENDED="${L2[14]}"
    LAST_APT_UPDATE="${L2[15]}"
    DPKG_AUDIT="${L2[16]}"
    HELD_PKGS="${L2[17]}"
    WORLD_WRITE_FILES="${L2[18]}"
    WORLD_WRITE_DIRS="${L2[19]}"
    WEB_WRITABLE="${L2[20]}"
    NON_EXEC_SCRIPTS="${L2[21]}"
    INSECURE_DIRS="${L2[22]}"
    PRIV_CONT="${L2[23]}"
    ROOT_CONT="${L2[24]}"
    EXPOSED_PORTS="${L2[25]}"
    DOCKER_CONTAINERS="${L2[26]}"
    DANGLING_IMAGES="${L2[27]}"
    DANGLING_VOLUMES="${L2[28]}"
    DOCKER_NETWORKS="${L2[29]}"
    HEALTHY_CONT="${L2[30]}"
    UNHEALTHY_CONT="${L2[31]}"
    DOCKER_STATS="${L2[32]}"
    DOCKER_STATUS="${L2[33]}"
    DOCKER_VERSION="${L2[34]}"
    DOCKER_DAEMON_JSON="${L2[35]}"
    DOCKER_LIVE_RESTORE="${L2[36]}"
    DOCKER_ERRORS="${L2[37]}"
    DOCKERFILES="${L2[38]}"
    DOCKER_SOCK_PERMS="${L2[39]}"
    DOCKER_SOCK_OCTAL="${L2[40]}"
    APPARMOR_DOCKER="${L2[41]}"
    APPARMOR_ENFORCE="${L2[42]}"
    SELINUX_DIR="${L2[43]}"
    SELINUX_STATUS="${L2[44]}"
    DMESG_RESTRICT="${L2[45]}"
    KPTR_RESTRICT="${L2[46]}"
    APPARMOR_STATUS="${L2[47]}"
    AUDITD_STATUS="${L2[48]}"

    # Display results with enhanced details
    echo -e "${CYAN}Firewall & Network Security:${NC}"
    [ "$UFW_ACTIVE" = "yes" ] && check_pass "UFW: active" || check_info "UFW: not active (using iptables/cloud firewall)"
    [ "$UFW_ACTIVE" = "yes" ] && check_info "UFW rules: $(echo $UFW_RULES | tr '|' $'\n' | head -3 | tr '\n' '; ')"
    [ "${IPTABLES_CHAINS:-0}" -gt 0 ] 2>/dev/null && check_info "iptables: $IPTABLES_CHAINS chains (Accept: $IPTABLES_ACCEPT, Drop: $IPTABLES_DROP, Reject: $IPTABLES_REJECT)" || check_info "iptables: not configured"
    check_info "Open ports: $OPEN_PORTS"
    check_info "Network connections: Total: $TOTAL_CONNS, Established: $ESTABLISHED, SYN_SENT: $SYN_SENT, TIME_WAIT: $TIME_WAIT"
    [ "$TCP_SYNCOOKIES" = "1" ] && check_pass "TCP SYN cookies: enabled" || check_warn "TCP SYN cookies: disabled"
    [ "$IP_FORWARD" = "0" ] && check_pass "IP forwarding: disabled" || check_info "IP forwarding: enabled"
    [ "$RP_FILTER" = "1" ] && check_pass "Reverse path filter: enabled" || check_info "Reverse path filter: $RP_FILTER"
    [ "$ACCEPT_SOURCE" = "0" ] && check_pass "Accept source route: disabled" || check_warn "Accept source route: enabled"
    [ "$ACCEPT_REDIRECTS" = "0" ] && check_pass "Accept redirects: disabled" || check_warn "Accept redirects: enabled"
    [ "$SEND_REDIRECTS" = "0" ] && check_pass "Send redirects: disabled" || check_info "Send redirects: enabled"
    [ "$LOG_MARTIANS" = "1" ] && check_pass "Log martians: enabled" || check_info "Log martians: disabled"

    echo -e "\n${CYAN}SSH Security Configuration:${NC}"
    check_info "SSH port: $SSH_PORT"
    [ "$SSH_ROOT" = "no" ] || [ "$SSH_ROOT" = "prohibit-password" ] && check_pass "Root login: restricted ($SSH_ROOT)" || { check_warn "Root login: $SSH_ROOT"; add_medium "Disable root SSH"; }
    [ "$SSH_PASSWD" = "no" ] && check_pass "Password auth: disabled" || check_info "Password auth: enabled"
    [ "$SSH_PUBKEY" = "yes" ] && check_pass "Pubkey auth: enabled" || check_info "Pubkey auth: $SSH_PUBKEY"
    [ "$SSH_EMPTY_PASS" = "no" ] && check_pass "Empty passwords: forbidden" || { check_fail "Empty passwords: allowed"; add_critical "Disable empty passwords"; }
    check_info "Max auth tries: $SSH_MAX_AUTH | Max sessions: $SSH_MAX_SESSIONS"
    check_info "Client alive: interval=$SSH_ALIVE_INTERVAL, count=$SSH_ALIVE_COUNT"
    [ "$SSH_X11" = "no" ] && check_pass "X11 forwarding: disabled" || check_info "X11 forwarding: enabled"
    [ "$SSH_PROTOCOL" = "2" ] && check_pass "SSH protocol: 2" || check_info "SSH protocol: $SSH_PROTOCOL"
    check_info "Allow users: $SSH_ALLOW_USERS | Allow groups: $SSH_ALLOW_GROUPS"
    [ "$SSH_DENY_USERS" != "none" ] && check_info "Deny users: $SSH_DENY_USERS" || check_info "No denied users"
    [ "${AUTH_KEYS_COUNT:-0}" -gt 0 ] 2>/dev/null && check_info "Authorized keys (root): $AUTH_KEYS_COUNT" || check_info "No root authorized keys"

    echo -e "\n${CYAN}Fail2Ban & Authentication Monitoring:${NC}"
    [ "$FAIL2BAN_STATUS" = "active" ] && check_pass "Fail2ban: active ($FAIL2BAN_JAILS jails)" || { check_warn "Fail2ban: $FAIL2BAN_STATUS"; add_medium "Enable fail2ban"; }
    [ "${FAIL2BAN_BANNED:-0}" -gt 0 ] 2>/dev/null && check_info "Currently banned: $FAIL2BAN_BANNED | Total banned: $FAIL2BAN_TOTAL" || check_info "No banned IPs currently"
    [ "${AUTH_FAILS:-0}" -gt 50 ] 2>/dev/null && { check_warn "Failed auth attempts (last 100): $AUTH_FAILS"; add_low "High failed logins"; } || check_pass "Failed auth attempts (last 100): ${AUTH_FAILS:-0}"
    check_info "Successful logins (last 100): $AUTH_SUCCESS"
    check_info "Current logged in users: $WHO_COUNT"
    check_info "Recent logins: $(echo $LAST_LOGINS | sed 's/|/, /g' | head -c 100)"

    echo -e "\n${CYAN}User & Password Policies:${NC}"
    check_info "Password max days: $PASS_MAX_DAYS | Min days: $PASS_MIN_DAYS | Min length: $PASS_MIN_LEN | Warn age: $PASS_WARN_AGE"
    [ "$UID_ZERO" = "root" ] && check_pass "UID 0 users: root only" || { check_warn "UID 0 users: $UID_ZERO"; add_high "Remove non-root UID 0 users"; }
    [ "${EMPTY_PASS:-0}" -eq 0 ] 2>/dev/null && check_pass "Empty password accounts: 0" || { check_fail "Empty password accounts: $EMPTY_PASS"; add_critical "Remove empty passwords"; }
    check_info "Total users: $USERS_COUNT | Groups: $GROUPS_COUNT"
    check_info "Sudo users: $SUDO_USERS"
    check_info "SSH directories: $SSH_DIRS | Root authorized_keys files: $AUTH_KEYS_ROOT"
    [ "${LIMITS_CONF:-0}" -gt 0 ] 2>/dev/null && check_info "Security limits configured: $LIMITS_CONF lines" || check_info "No custom security limits"
    [ "${PAM_LINES:-0}" -gt 0 ] 2>/dev/null && check_info "PAM password policy: $PAM_LINES rules" || check_info "Default PAM password policy"

    echo -e "\n${CYAN}SSL/TLS Certificates:${NC}"
    if [ "$SSL_EXPIRY" != "unknown" ] && [ -n "$SSL_EXPIRY" ]; then
        EXPIRY_EPOCH=$(date -d "$SSL_EXPIRY" +%s 2>/dev/null || echo 0)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - $(date +%s)) / 86400 ))
        [ "$DAYS_LEFT" -lt 14 ] && { check_fail "SSL expires in $DAYS_LEFT days!"; add_critical "SSL expiring"; } || \
        [ "$DAYS_LEFT" -lt 30 ] && { check_warn "SSL expires in $DAYS_LEFT days"; add_high "Renew SSL soon"; } || \
        check_pass "SSL valid for $DAYS_LEFT days"
    else
        check_info "SSL expiry: could not determine"
    fi
    [ -n "$SSL_ISSUER" ] && [ "$SSL_ISSUER" != "unknown" ] && check_info "SSL issuer: $(echo $SSL_ISSUER | head -c 60)" || check_info "SSL issuer: unknown"
    [ -n "$SSL_SUBJECT" ] && [ "$SSL_SUBJECT" != "unknown" ] && check_info "SSL subject: $(echo $SSL_SUBJECT | head -c 60)" || check_info "SSL subject: unknown"
    [ "${LE_DOMAINS:-0}" -gt 0 ] 2>/dev/null && check_pass "Let's Encrypt domains: $LE_DOMAINS ($LE_CERTS certs)" || check_info "No Let's Encrypt certificates"
    [ "$OPENSSL_VER" != "unknown" ] && check_info "OpenSSL version: $OPENSSL_VER" || check_info "OpenSSL: not found"
    [ "${SSL_PRIVATE:-0}" -gt 0 ] 2>/dev/null && check_info "Private keys in /etc/ssl/private: $SSL_PRIVATE" || check_info "No private keys found"
    [ "$SSL_PERMS" = "700" ] || [ "$SSL_PERMS" = "710" ] && check_pass "SSL private directory perms: $SSL_PERMS" || check_warn "SSL private directory perms: $SSL_PERMS"

    echo -e "\n${CYAN}Secrets & Sensitive Data Management:${NC}"
    [ "${ENV_FILES:-0}" -gt 0 ] 2>/dev/null && check_info "Environment files found: $ENV_FILES in /root, $ENV_VARWWW in /var/www" || check_info "No .env files found"
    [ "${SECRETS_CODE:-0}" -gt 10 ] 2>/dev/null && { check_warn "Potential secrets in code: $SECRETS_CODE occurrences"; add_low "Review secrets in code"; } || check_pass "Secrets in code: ${SECRETS_CODE:-0} (acceptable)"
    [ "${PEM_FILES:-0}" -gt 0 ] 2>/dev/null && check_info "PEM/key files in /root: $PEM_FILES" || check_info "No PEM files in /root"

    echo -e "\n${CYAN}System Updates & Package Management:${NC}"
    [ "${SEC_UPDATES:-0}" -gt 0 ] 2>/dev/null && { check_warn "Security updates pending: $SEC_UPDATES of $UPGRADABLE total"; add_high "Apply security updates"; } || check_pass "No security updates pending ($UPGRADABLE total upgradable)"
    [ "$UNATTENDED" = "active" ] && check_pass "Unattended upgrades: active" || check_info "Unattended upgrades: $UNATTENDED"
    DAYS_SINCE_UPDATE=$(( ($(date +%s) - ${LAST_APT_UPDATE:-0}) / 86400 ))
    [ "$DAYS_SINCE_UPDATE" -gt 7 ] && check_warn "Last apt update: $DAYS_SINCE_UPDATE days ago" || check_pass "Last apt update: $DAYS_SINCE_UPDATE days ago"
    [ "${DPKG_AUDIT:-0}" -eq 0 ] 2>/dev/null && check_pass "Dpkg audit: clean" || { check_warn "Dpkg issues: $DPKG_AUDIT"; add_low "Fix dpkg issues"; }
    [ "${HELD_PKGS:-0}" -eq 0 ] 2>/dev/null && check_pass "Held packages: 0" || check_info "Held packages: $HELD_PKGS"

    echo -e "\n${CYAN}File Permissions & Integrity:${NC}"
    [ "${WORLD_WRITE_FILES:-0}" -eq 0 ] 2>/dev/null && check_pass "World-writable files: 0" || { check_warn "World-writable files: $WORLD_WRITE_FILES"; add_low "Fix file permissions"; }
    [ "${WORLD_WRITE_DIRS:-0}" -eq 0 ] 2>/dev/null && check_pass "World-writable dirs: 0" || { check_warn "World-writable dirs: $WORLD_WRITE_DIRS"; add_low "Fix dir permissions"; }
    [ "${WEB_WRITABLE:-0}" -eq 0 ] 2>/dev/null && check_pass "Web config writable by others: 0" || { check_warn "Web config writable: $WEB_WRITABLE"; add_medium "Fix web config perms"; }
    [ "${NON_EXEC_SCRIPTS:-0}" -eq 0 ] 2>/dev/null && check_pass "Non-executable scripts: 0" || check_info "Non-executable .sh files: $NON_EXEC_SCRIPTS"
    [ "${INSECURE_DIRS:-0}" -eq 0 ] 2>/dev/null && check_pass "Insecure root directories: 0" || { check_fail "Insecure root directories: $INSECURE_DIRS"; add_critical "Fix root dir perms"; }

    echo -e "\n${CYAN}Docker Security:${NC}"
    [ "$DOCKER_STATUS" = "active" ] && check_pass "Docker: active (version $DOCKER_VERSION)" || check_info "Docker: $DOCKER_STATUS"
    [ "${PRIV_CONT:-0}" -eq 0 ] 2>/dev/null && check_pass "Privileged containers: 0" || { check_warn "Privileged containers: $PRIV_CONT"; add_medium "Review privileged containers"; }
    [ "${ROOT_CONT:-0}" -lt 10 ] 2>/dev/null && check_pass "Root containers: $ROOT_CONT of $DOCKER_CONTAINERS" || { check_warn "Containers as root: $ROOT_CONT of $DOCKER_CONTAINERS"; add_low "Use non-root users"; }
    check_info "Exposed ports (0.0.0.0): $EXPOSED_PORTS"
    [ "${HEALTHY_CONT:-0}" -gt 0 ] 2>/dev/null && check_pass "Healthy containers: $HEALTHY_CONT" || check_info "No health checks configured"
    [ "${UNHEALTHY_CONT:-0}" -eq 0 ] 2>/dev/null && check_pass "Unhealthy containers: 0" || { check_warn "Unhealthy containers: $UNHEALTHY_CONT"; add_high "Fix unhealthy containers"; }
    [ "$DOCKER_DAEMON_JSON" = "yes" ] && check_pass "Docker daemon.json: configured" || check_info "Docker daemon.json: not found"
    [ "${DOCKER_LIVE_RESTORE:-0}" -gt 0 ] 2>/dev/null && check_pass "Docker live-restore: enabled" || check_info "Docker live-restore: disabled"
    [ "${DANGLING_IMAGES:-0}" -eq 0 ] 2>/dev/null && check_pass "Dangling images: 0" || check_info "Dangling images: $DANGLING_IMAGES (cleanup needed)"
    [ "${DANGLING_VOLUMES:-0}" -eq 0 ] 2>/dev/null && check_pass "Dangling volumes: 0" || check_info "Dangling volumes: $DANGLING_VOLUMES (cleanup needed)"
    check_info "Docker networks: $DOCKER_NETWORKS"
    check_info "Docker stats: $(echo $DOCKER_STATS | tr '|' '; ' | head -c 100)"
    [ "${DOCKER_ERRORS:-0}" -eq 0 ] 2>/dev/null && check_pass "Docker errors (last hour): 0" || check_warn "Docker errors (last hour): $DOCKER_ERRORS"
    check_info "Docker socket: $DOCKER_SOCK_PERMS (octal: $DOCKER_SOCK_OCTAL)"

    echo -e "\n${CYAN}Kernel Security & Hardening:${NC}"
    [ "$ASLR" = "2" ] && check_pass "ASLR: full randomization" || check_info "ASLR: $ASLR"
    [ "$DMESG_RESTRICT" = "1" ] && check_pass "Dmesg restrict: enabled" || check_info "Dmesg restrict: disabled"
    [ "$KPTR_RESTRICT" = "1" ] || [ "$KPTR_RESTRICT" = "2" ] && check_pass "Kernel pointer restrict: $KPTR_RESTRICT" || check_info "Kernel pointer restrict: $KPTR_RESTRICT"
    [ "$APPARMOR_STATUS" = "active" ] && check_pass "AppArmor: active ($APPARMOR_ENFORCE profiles enforced, $APPARMOR_DOCKER docker profiles)" || check_info "AppArmor: $APPARMOR_STATUS"
    [ "$SELINUX_STATUS" != "disabled" ] && check_info "SELinux: $SELINUX_STATUS" || check_info "SELinux: disabled"
    [ "$AUDITD_STATUS" = "active" ] && check_pass "Auditd: active" || check_info "Auditd: $AUDITD_STATUS"
fi

section "🔴 THINGS TO FIX"
if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
    echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              🔴 THINGS TO FIX - SECURITY                      ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}🟠 HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
    for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}🔵 LOW: $issue${NC}"; done
else
    echo -e "  ${GREEN}✓ No security issues found! System is secure.${NC}"
fi

section "FINAL SUMMARY"
DUR=$(($(date +%s) - SCRIPT_START))
[[ $SCORE -lt 0 ]] && SCORE=0

if [[ $SCORE -ge 90 ]]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [[ $SCORE -ge 75 ]]; then RATING="GOOD"; COLOR="$GREEN"
elif [[ $SCORE -ge 60 ]]; then RATING="FAIR"; COLOR="$YELLOW"
else RATING="NEEDS WORK"; COLOR="$RED"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  SECURITY_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds  ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "SECURITY_SCORE:$SCORE"
