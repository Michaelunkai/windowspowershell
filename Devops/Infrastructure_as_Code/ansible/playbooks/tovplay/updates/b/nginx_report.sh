#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# NGINX AUDIT v5.1 [3X SPEED OPTIMIZED] - SSH Batching Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'; DIM='\033[2m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
SCORE=100

SSH_CTRL="/tmp/tovplay_nginx_$$"
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
echo -e "${BOLD}${MAGENTA}║     🌐 NGINX AUDIT v5.1 [3X SPEED OPTIMIZED] - $(date '+%Y-%m-%d %H:%M:%S')    ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

init_connections

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 3); STAGING_OK=$(ssh_staging "echo OK" 3)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { STAGING_CONN=false; }

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 1: NGINX SERVICE, CONFIG, VHOSTS, SSL
# ═══════════════════════════════════════════════════════════════════════════════
section "2-10. NGINX SERVICE & CONFIGURATION"
if [ "$PROD_CONN" = true ]; then
    BATCH1=$(ssh_prod 'echo ":::NGINX_STATUS:::"; systemctl is-active nginx
echo ":::NGINX_VERSION:::"; nginx -v 2>&1 | grep -oP "\\d+\\.\\d+\\.\\d+"
echo ":::CONFIG_TEST:::"; nginx -t 2>&1 | tail -1
echo ":::WORKER_PROCESSES:::"; grep "worker_processes" /etc/nginx/nginx.conf 2>/dev/null | head -1
echo ":::WORKER_CONNECTIONS:::"; grep "worker_connections" /etc/nginx/nginx.conf 2>/dev/null | head -1
echo ":::GZIP:::"; grep -r "gzip on" /etc/nginx/ 2>/dev/null | head -1
echo ":::SSL_PROTOCOLS:::"; grep -r "ssl_protocols" /etc/nginx/ 2>/dev/null | head -1
echo ":::SITES_ENABLED:::"; ls /etc/nginx/sites-enabled/ 2>/dev/null | head -5
echo ":::VHOSTS_COUNT:::"; ls /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
echo ":::HTTP2:::"; grep -r "http2" /etc/nginx/sites-enabled/ 2>/dev/null | head -1
echo ":::SECURITY_HEADERS:::"; grep -rE "X-Frame-Options|X-Content-Type|X-XSS" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
echo ":::CACHE_CONTROL:::"; grep -r "add_header.*Cache-Control" /etc/nginx/sites-enabled/ 2>/dev/null | head -1
echo ":::ERROR_LOG_SIZE:::"; du -sh /var/log/nginx/error.log 2>/dev/null | cut -f1
echo ":::ACCESS_LOG_SIZE:::"; du -sh /var/log/nginx/access.log 2>/dev/null | cut -f1
echo ":::RECENT_ERRORS:::"; tail -10 /var/log/nginx/error.log 2>/dev/null | grep -i error | tail -3
echo ":::404_COUNT:::"; grep -c " 404 " /var/log/nginx/access.log 2>/dev/null
echo ":::500_COUNT:::"; grep -c " 500 " /var/log/nginx/access.log 2>/dev/null
echo ":::SSL_CERT:::"; ls -la /etc/letsencrypt/live/app.tovplay.org/ 2>/dev/null | head -3
echo ":::CERTBOT_TIMER:::"; systemctl is-active certbot.timer 2>/dev/null' 15)

    NGINX_STATUS=$(echo "$BATCH1" | sed -n '/:::NGINX_STATUS:::/,/:::NGINX_VERSION:::/p' | tail -1)
    NGINX_VER=$(echo "$BATCH1" | sed -n '/:::NGINX_VERSION:::/,/:::CONFIG_TEST:::/p' | tail -1)
    CONFIG_TEST=$(echo "$BATCH1" | sed -n '/:::CONFIG_TEST:::/,/:::WORKER_PROCESSES:::/p' | tail -1)
    WORKER_PROC=$(echo "$BATCH1" | sed -n '/:::WORKER_PROCESSES:::/,/:::WORKER_CONNECTIONS:::/p' | tail -1)
    WORKER_CONN=$(echo "$BATCH1" | sed -n '/:::WORKER_CONNECTIONS:::/,/:::GZIP:::/p' | tail -1)
    GZIP=$(echo "$BATCH1" | sed -n '/:::GZIP:::/,/:::SSL_PROTOCOLS:::/p' | tail -1)
    SSL_PROTO=$(echo "$BATCH1" | sed -n '/:::SSL_PROTOCOLS:::/,/:::SITES_ENABLED:::/p' | tail -1)
    SITES=$(echo "$BATCH1" | sed -n '/:::SITES_ENABLED:::/,/:::VHOSTS_COUNT:::/p' | grep -v ':::')
    VHOSTS_COUNT=$(echo "$BATCH1" | sed -n '/:::VHOSTS_COUNT:::/,/:::HTTP2:::/p' | tail -1)
    HTTP2=$(echo "$BATCH1" | sed -n '/:::HTTP2:::/,/:::SECURITY_HEADERS:::/p' | tail -1)
    SEC_HEADERS=$(echo "$BATCH1" | sed -n '/:::SECURITY_HEADERS:::/,/:::CACHE_CONTROL:::/p' | tail -1)
    CACHE=$(echo "$BATCH1" | sed -n '/:::CACHE_CONTROL:::/,/:::ERROR_LOG_SIZE:::/p' | tail -1)
    ERR_SIZE=$(echo "$BATCH1" | sed -n '/:::ERROR_LOG_SIZE:::/,/:::ACCESS_LOG_SIZE:::/p' | tail -1)
    ACC_SIZE=$(echo "$BATCH1" | sed -n '/:::ACCESS_LOG_SIZE:::/,/:::RECENT_ERRORS:::/p' | tail -1)
    RECENT_ERRORS=$(echo "$BATCH1" | sed -n '/:::RECENT_ERRORS:::/,/:::404_COUNT:::/p' | grep -v ':::')
    COUNT_404=$(echo "$BATCH1" | sed -n '/:::404_COUNT:::/,/:::500_COUNT:::/p' | tail -1)
    COUNT_500=$(echo "$BATCH1" | sed -n '/:::500_COUNT:::/,/:::SSL_CERT:::/p' | tail -1)
    CERTBOT=$(echo "$BATCH1" | sed -n '/:::CERTBOT_TIMER:::/,$p' | tail -1)

    echo -e "${CYAN}Service:${NC}"
    [ "$NGINX_STATUS" = "active" ] && check_pass "Nginx: active (v$NGINX_VER)" || { check_fail "Nginx: $NGINX_STATUS"; add_critical "Nginx not running"; }
    echo "$CONFIG_TEST" | grep -qi "successful" && check_pass "Config test: passed" || { check_warn "Config test: $CONFIG_TEST"; add_high "Nginx config error"; }

    echo -e "\n${CYAN}Configuration:${NC}"
    check_info "Worker processes: $WORKER_PROC"
    check_info "Worker connections: $WORKER_CONN"
    [ -n "$GZIP" ] && check_pass "Gzip: enabled" || { check_warn "Gzip: not enabled"; add_medium "Enable gzip"; }

    echo -e "\n${CYAN}Virtual Hosts ($VHOSTS_COUNT):${NC}"
    echo "$SITES" | while read -r site; do [ -n "$site" ] && check_info "$site"; done

    echo -e "\n${CYAN}SSL/TLS:${NC}"
    [ -n "$SSL_PROTO" ] && check_info "SSL: $SSL_PROTO"
    [ -n "$HTTP2" ] && check_pass "HTTP/2: enabled" || check_info "HTTP/2: not detected"
    [ "$CERTBOT" = "active" ] && check_pass "Certbot timer: active" || check_info "Certbot: $CERTBOT"

    echo -e "\n${CYAN}Security Headers:${NC}"
    [ "${SEC_HEADERS:-0}" -ge 2 ] 2>/dev/null && check_pass "Security headers: $SEC_HEADERS configured" || { check_warn "Security headers: $SEC_HEADERS"; add_medium "Add security headers"; }
    [ -n "$CACHE" ] && check_pass "Cache-Control: configured" || check_info "Cache-Control: not found"

    echo -e "\n${CYAN}Logs:${NC}"
    check_info "Error log: $ERR_SIZE | Access log: $ACC_SIZE"
    [ "${COUNT_404:-0}" -gt 500 ] 2>/dev/null && { check_warn "404 errors: $COUNT_404"; add_low "Many 404 errors"; } || check_pass "404 errors: ${COUNT_404:-0}"
    [ "${COUNT_500:-0}" -gt 10 ] 2>/dev/null && { check_warn "500 errors: $COUNT_500"; add_high "Server errors detected"; } || check_pass "500 errors: ${COUNT_500:-0}"

    if [ -n "$RECENT_ERRORS" ]; then
        check_warn "Recent errors:"
        echo "$RECENT_ERRORS" | head -2 | while read -r line; do echo "    $line"; done
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STAGING NGINX
# ═══════════════════════════════════════════════════════════════════════════════
section "11-13. STAGING NGINX"
if [ "$STAGING_CONN" = true ]; then
    BATCH2=$(ssh_staging 'echo ":::STATUS:::"; systemctl is-active nginx
echo ":::VERSION:::"; nginx -v 2>&1 | grep -oP "\\d+\\.\\d+\\.\\d+"
echo ":::CONFIG:::"; nginx -t 2>&1 | tail -1
echo ":::VHOSTS:::"; ls /etc/nginx/sites-enabled/ 2>/dev/null | wc -l' 10)

    STG_STATUS=$(echo "$BATCH2" | sed -n '/:::STATUS:::/,/:::VERSION:::/p' | tail -1)
    STG_VER=$(echo "$BATCH2" | sed -n '/:::VERSION:::/,/:::CONFIG:::/p' | tail -1)
    STG_CONFIG=$(echo "$BATCH2" | sed -n '/:::CONFIG:::/,/:::VHOSTS:::/p' | tail -1)
    STG_VHOSTS=$(echo "$BATCH2" | sed -n '/:::VHOSTS:::/,$p' | tail -1)

    [ "$STG_STATUS" = "active" ] && check_pass "Staging Nginx: active (v$STG_VER)" || check_warn "Staging Nginx: $STG_STATUS"
    echo "$STG_CONFIG" | grep -qi "successful" && check_pass "Staging config: passed" || check_warn "Staging config: $STG_CONFIG"
    check_info "Staging vhosts: $STG_VHOSTS"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# COMPARISON
# ═══════════════════════════════════════════════════════════════════════════════
section "14. COMPARISON"
echo -e "  ${BOLD}Metric              Production    Staging${NC}"
echo -e "  ─────────────────────────────────────────────"
printf "  %-18s %-13s %s\n" "Status" "${NGINX_STATUS:-?}" "${STG_STATUS:-?}"
printf "  %-18s %-13s %s\n" "Version" "${NGINX_VER:-?}" "${STG_VER:-?}"
printf "  %-18s %-13s %s\n" "Vhosts" "${VHOSTS_COUNT:-?}" "${STG_VHOSTS:-?}"

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
section "FINAL SUMMARY"
DUR=$(($(date +%s) - SCRIPT_START))
[[ $SCORE -lt 0 ]] && SCORE=0

if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 ]]; then
    echo -e "\n${RED}Issues:${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${YELLOW}🟠 HIGH: $issue${NC}"; done
fi

if [[ $SCORE -ge 90 ]]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [[ $SCORE -ge 75 ]]; then RATING="GOOD"; COLOR="$GREEN"
elif [[ $SCORE -ge 60 ]]; then RATING="FAIR"; COLOR="$YELLOW"
else RATING="NEEDS WORK"; COLOR="$YELLOW"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  NGINX_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds     ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "NGINX_SCORE:$SCORE"
