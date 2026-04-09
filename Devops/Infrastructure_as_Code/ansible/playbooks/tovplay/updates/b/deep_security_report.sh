#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# DEEP SECURITY AUDIT v5.1 [3X SPEED OPTIMIZED] - SSH Batching Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

# Servers
PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'; DIM='\033[2m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
SCORE=100

# SSH ControlMaster
SSH_CTRL="/tmp/tovplay_security_$$"
mkdir -p "$SSH_CTRL"
cleanup() {
    ssh -S "$SSH_CTRL/prod" -O exit $PROD_USER@$PROD_HOST 2>/dev/null
    ssh -S "$SSH_CTRL/stag" -O exit $STAGING_USER@$STAGING_HOST 2>/dev/null
    rm -rf "$SSH_CTRL"
}
trap cleanup EXIT

init_connections() {
    sshpass -p "$PROD_PASS" ssh -fNM -S "$SSH_CTRL/prod" -o ControlPersist=90 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
        $PROD_USER@$PROD_HOST 2>/dev/null &
    sshpass -p "$STAGING_PASS" ssh -fNM -S "$SSH_CTRL/stag" -o ControlPersist=90 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
        $STAGING_USER@$STAGING_HOST 2>/dev/null &
    wait
}

ssh_prod() { timeout ${2:-5}s ssh -S "$SSH_CTRL/prod" -o StrictHostKeyChecking=no $PROD_USER@$PROD_HOST "$1" 2>/dev/null; }
ssh_staging() { timeout ${2:-5}s ssh -S "$SSH_CTRL/stag" -o StrictHostKeyChecking=no $STAGING_USER@$STAGING_HOST "$1" 2>/dev/null; }

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
echo -e "${BOLD}${MAGENTA}║     🔒 SECURITY AUDIT v5.1 [3X SPEED OPTIMIZED] - $(date '+%Y-%m-%d %H:%M:%S')  ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

init_connections

# ═══════════════════════════════════════════════════════════════════════════════
# CONNECTIVITY
# ═══════════════════════════════════════════════════════════════════════════════
section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 3); STAGING_OK=$(ssh_staging "echo OK" 3)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "Prod SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { STAGING_CONN=false; }

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 1: FIREWALL, PORTS, SSH SECURITY
# ═══════════════════════════════════════════════════════════════════════════════
section "2-6. FIREWALL, PORTS, SSH SECURITY"
if [ "$PROD_CONN" = true ]; then
    BATCH1=$(ssh_prod 'echo ":::UFW_STATUS:::"; ufw status 2>/dev/null | head -5
echo ":::UFW_ACTIVE:::"; ufw status 2>/dev/null | grep -q "Status: active" && echo yes || echo no
echo ":::IPTABLES_COUNT:::"; iptables -L 2>/dev/null | wc -l
echo ":::OPEN_PORTS:::"; ss -tlnp 2>/dev/null | grep LISTEN | awk "{print \$4}" | cut -d: -f2 | sort -u | head -15
echo ":::SSH_PORT:::"; grep "^Port" /etc/ssh/sshd_config 2>/dev/null || echo "Port 22"
echo ":::SSH_ROOT:::"; grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "PermitRootLogin not set"
echo ":::SSH_PASSWD:::"; grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "PasswordAuthentication not set"
echo ":::FAIL2BAN:::"; systemctl is-active fail2ban 2>/dev/null || echo "not installed"
echo ":::FAIL2BAN_JAILS:::"; fail2ban-client status 2>/dev/null | grep "Jail list" || echo "no jails"
echo ":::BANNED_IPS:::"; fail2ban-client status sshd 2>/dev/null | grep "Currently banned" || echo "0"
echo ":::AUTH_LOG:::"; tail -20 /var/log/auth.log 2>/dev/null | grep -i "failed\|invalid" | wc -l
echo ":::SUDOERS:::"; cat /etc/sudoers.d/* 2>/dev/null | grep -v "^#" | head -5
echo ":::ROOT_SHELLS:::"; grep ":0:" /etc/passwd 2>/dev/null | head -3' 15)

    UFW_ACTIVE=$(echo "$BATCH1" | sed -n '/:::UFW_ACTIVE:::/,/:::IPTABLES_COUNT:::/p' | tail -1)
    OPEN_PORTS=$(echo "$BATCH1" | sed -n '/:::OPEN_PORTS:::/,/:::SSH_PORT:::/p' | grep -v ':::' | tr '\n' ' ')
    SSH_PORT=$(echo "$BATCH1" | sed -n '/:::SSH_PORT:::/,/:::SSH_ROOT:::/p' | tail -1)
    SSH_ROOT=$(echo "$BATCH1" | sed -n '/:::SSH_ROOT:::/,/:::SSH_PASSWD:::/p' | tail -1)
    SSH_PASSWD=$(echo "$BATCH1" | sed -n '/:::SSH_PASSWD:::/,/:::FAIL2BAN:::/p' | tail -1)
    FAIL2BAN=$(echo "$BATCH1" | sed -n '/:::FAIL2BAN:::/,/:::FAIL2BAN_JAILS:::/p' | tail -1)
    AUTH_FAILS=$(echo "$BATCH1" | sed -n '/:::AUTH_LOG:::/,/:::SUDOERS:::/p' | tail -1)

    echo -e "${CYAN}Firewall:${NC}"
    [ "$UFW_ACTIVE" = "yes" ] && check_pass "UFW: active" || { check_warn "UFW: not active"; add_medium "Enable firewall"; }
    check_info "Open ports: $OPEN_PORTS"

    echo -e "\n${CYAN}SSH Security:${NC}"
    check_info "$SSH_PORT"
    echo "$SSH_ROOT" | grep -qi "yes" && { check_warn "Root login: permitted"; add_medium "Disable root SSH"; } || check_pass "Root login: restricted"
    echo "$SSH_PASSWD" | grep -qi "no" && check_pass "Password auth: disabled" || check_info "Password auth: enabled"

    echo -e "\n${CYAN}Fail2Ban:${NC}"
    [ "$FAIL2BAN" = "active" ] && check_pass "Fail2ban: active" || { check_warn "Fail2ban: $FAIL2BAN"; add_medium "Enable fail2ban"; }
    [ "${AUTH_FAILS:-0}" -gt 50 ] 2>/dev/null && { check_warn "Failed auth attempts: $AUTH_FAILS"; add_low "High failed logins"; } || check_pass "Failed auth attempts: ${AUTH_FAILS:-0}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 2: SSL, SECRETS, UPDATES
# ═══════════════════════════════════════════════════════════════════════════════
section "7-12. SSL, SECRETS, UPDATES"
if [ "$PROD_CONN" = true ]; then
    BATCH2=$(ssh_prod 'echo ":::SSL_EXPIRY:::"; openssl s_client -connect localhost:443 -servername app.tovplay.org </dev/null 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null
echo ":::SSL_GRADE:::"; openssl s_client -connect localhost:443 </dev/null 2>/dev/null | openssl x509 -noout -text 2>/dev/null | grep "Signature Algorithm" | head -1
echo ":::ENV_FILES:::"; find /root -name ".env*" -o -name "*.env" 2>/dev/null | head -5
echo ":::SECRETS_IN_CODE:::"; grep -r "password\|secret\|api_key" /root/tovplay-backend/*.py 2>/dev/null | grep -v ".pyc" | wc -l
echo ":::DOCKER_SECRETS:::"; docker secret ls 2>/dev/null | wc -l
echo ":::SECURITY_UPDATES:::"; apt list --upgradable 2>/dev/null | grep -i security | wc -l
echo ":::UNATTENDED:::"; systemctl is-active unattended-upgrades 2>/dev/null || echo "not active"
echo ":::WORLD_WRITABLE:::"; find /etc /var/www -perm -002 -type f 2>/dev/null | wc -l
echo ":::SUID_FILES:::"; find /usr -perm -4000 -type f 2>/dev/null | wc -l' 15)

    SSL_EXPIRY=$(echo "$BATCH2" | sed -n '/:::SSL_EXPIRY:::/,/:::SSL_GRADE:::/p' | grep notAfter | cut -d= -f2)
    ENV_FILES=$(echo "$BATCH2" | sed -n '/:::ENV_FILES:::/,/:::SECRETS_IN_CODE:::/p' | grep -v ':::' | wc -l)
    SECRETS_CODE=$(echo "$BATCH2" | sed -n '/:::SECRETS_IN_CODE:::/,/:::DOCKER_SECRETS:::/p' | tail -1)
    SEC_UPDATES=$(echo "$BATCH2" | sed -n '/:::SECURITY_UPDATES:::/,/:::UNATTENDED:::/p' | tail -1)
    UNATTENDED=$(echo "$BATCH2" | sed -n '/:::UNATTENDED:::/,/:::WORLD_WRITABLE:::/p' | tail -1)
    WORLD_WRITE=$(echo "$BATCH2" | sed -n '/:::WORLD_WRITABLE:::/,/:::SUID_FILES:::/p' | tail -1)

    echo -e "${CYAN}SSL/TLS:${NC}"
    if [ -n "$SSL_EXPIRY" ]; then
        EXPIRY_EPOCH=$(date -d "$SSL_EXPIRY" +%s 2>/dev/null || echo 0)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - $(date +%s)) / 86400 ))
        [ "$DAYS_LEFT" -lt 14 ] && { check_fail "SSL expires in $DAYS_LEFT days!"; add_critical "SSL expiring"; } || check_pass "SSL valid for $DAYS_LEFT days"
    else
        check_info "SSL expiry: could not determine"
    fi

    echo -e "\n${CYAN}Secrets Management:${NC}"
    check_info "Environment files: $ENV_FILES"
    [ "${SECRETS_CODE:-0}" -gt 10 ] 2>/dev/null && { check_warn "Potential secrets in code: $SECRETS_CODE"; add_low "Review secrets in code"; } || check_pass "Secrets in code: ${SECRETS_CODE:-0}"

    echo -e "\n${CYAN}System Updates:${NC}"
    [ "${SEC_UPDATES:-0}" -gt 0 ] 2>/dev/null && { check_warn "Security updates pending: $SEC_UPDATES"; add_high "Apply security updates"; } || check_pass "No security updates pending"
    [ "$UNATTENDED" = "active" ] && check_pass "Unattended upgrades: active" || check_info "Unattended upgrades: $UNATTENDED"

    echo -e "\n${CYAN}File Permissions:${NC}"
    [ "${WORLD_WRITE:-0}" -gt 5 ] 2>/dev/null && { check_warn "World-writable files: $WORLD_WRITE"; add_low "Fix file permissions"; } || check_pass "World-writable files: ${WORLD_WRITE:-0}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 3: DOCKER SECURITY
# ═══════════════════════════════════════════════════════════════════════════════
section "13-15. DOCKER SECURITY"
if [ "$PROD_CONN" = true ]; then
    BATCH3=$(ssh_prod 'echo ":::PRIV_CONTAINERS:::"; docker ps --format "{{.Names}}" -f "privileged=true" 2>/dev/null | wc -l
echo ":::ROOT_CONTAINERS:::"; docker ps -q 2>/dev/null | xargs -I {} docker inspect --format "{{.Name}}: {{.Config.User}}" {} 2>/dev/null | grep -E ": $" | wc -l
echo ":::EXPOSED_PORTS:::"; docker ps --format "{{.Ports}}" 2>/dev/null | grep -oP "0.0.0.0:\\d+" | wc -l
echo ":::DOCKER_SOCKET:::"; ls -la /var/run/docker.sock 2>/dev/null' 10)

    PRIV_CONT=$(echo "$BATCH3" | sed -n '/:::PRIV_CONTAINERS:::/,/:::ROOT_CONTAINERS:::/p' | tail -1)
    ROOT_CONT=$(echo "$BATCH3" | sed -n '/:::ROOT_CONTAINERS:::/,/:::EXPOSED_PORTS:::/p' | tail -1)
    EXPOSED=$(echo "$BATCH3" | sed -n '/:::EXPOSED_PORTS:::/,/:::DOCKER_SOCKET:::/p' | tail -1)

    [ "${PRIV_CONT:-0}" -eq 0 ] 2>/dev/null && check_pass "Privileged containers: 0" || { check_warn "Privileged containers: $PRIV_CONT"; add_medium "Review privileged containers"; }
    [ "${ROOT_CONT:-0}" -lt 3 ] 2>/dev/null && check_pass "Root containers: $ROOT_CONT" || { check_warn "Containers as root: $ROOT_CONT"; add_low "Use non-root users"; }
    check_info "Exposed ports: $EXPOSED"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
section "FINAL SUMMARY"
DUR=$(($(date +%s) - SCRIPT_START))
[[ $SCORE -lt 0 ]] && SCORE=0

if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 ]]; then
    echo -e "\n${RED}Security Issues:${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${YELLOW}🟠 HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
fi

if [[ $SCORE -ge 90 ]]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [[ $SCORE -ge 75 ]]; then RATING="GOOD"; COLOR="$GREEN"
elif [[ $SCORE -ge 60 ]]; then RATING="FAIR"; COLOR="$YELLOW"
else RATING="NEEDS WORK"; COLOR="$RED"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  SECURITY_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds  ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "SECURITY_SCORE:$SCORE"
