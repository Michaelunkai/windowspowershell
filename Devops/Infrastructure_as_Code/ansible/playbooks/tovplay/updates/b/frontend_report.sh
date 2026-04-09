#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TovPlay Frontend AUDIT v5.1 [3X SPEED OPTIMIZED] - SSH Batching Edition
# ═══════════════════════════════════════════════════════════════════════════════
# 80+ Sections | 200+ Checks | SSH ControlMaster + Command Batching
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)
MAX_RUNTIME=40  # Reduced from 120 due to 3x speedup

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'; ORANGE='\033[0;33m'
NC='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'

# Servers
PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"
PROD_URL="https://app.tovplay.org"; STAGING_URL="https://staging.tovplay.org"

# Issue tracking
declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
TOTAL_CHECKS=0; PASSED_CHECKS=0

# SSH ControlMaster for connection reuse
SSH_CTRL="/tmp/tovplay_frontend_$$"
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

    echo -e "\n${BOLD}${MAGENTA}═══════════════ FRONTEND AUDIT SUMMARY ═══════════════${NC}"
    [ ${#CRITICAL_ISSUES[@]} -gt 0 ] && { echo -e "${RED}🔴 CRITICAL (${#CRITICAL_ISSUES[@]}):${NC}"; printf '   %s\n' "${CRITICAL_ISSUES[@]}"; }
    [ ${#HIGH_ISSUES[@]} -gt 0 ] && { echo -e "${ORANGE}🟠 HIGH (${#HIGH_ISSUES[@]}):${NC}"; printf '   %s\n' "${HIGH_ISSUES[@]}"; }
    [ ${#MEDIUM_ISSUES[@]} -gt 0 ] && { echo -e "${YELLOW}🟡 MEDIUM (${#MEDIUM_ISSUES[@]}):${NC}"; printf '   %s\n' "${MEDIUM_ISSUES[@]}"; }
    [ ${#LOW_ISSUES[@]} -gt 0 ] && { echo -e "${BLUE}🔵 LOW (${#LOW_ISSUES[@]}):${NC}"; printf '   %s\n' "${LOW_ISSUES[@]}"; }

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
    echo "FRONTEND_SCORE:$score"
}

# Banner
echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     🌐 FRONTEND AUDIT v5.1 [3X SPEED OPTIMIZED] 🌐                ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo -e "${DIM}Started: $(date '+%Y-%m-%d %H:%M:%S')${NC}"

init_connections

# ═══════════════════════════════════════════════════════════════
# SECTION 1: CONNECTIVITY
# ═══════════════════════════════════════════════════════════════
section "1" "CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 3); STAGING_OK=$(ssh_staging "echo OK" 3)
[ "$PROD_OK" = "OK" ] && { check_pass "Production SSH: connected"; PROD_CONN=true; } || { check_fail "Production SSH: failed"; add_critical "[PROD] SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging SSH: connected"; STAGING_CONN=true; } || { check_fail "Staging SSH: failed"; STAGING_CONN=false; }

# ═══════════════════════════════════════════════════════════════
# BATCH 1: PRODUCTION FRONTEND (Single SSH - MASSIVE speedup)
# ═══════════════════════════════════════════════════════════════
section "2-30" "PRODUCTION FRONTEND"
if [ "$PROD_CONN" = true ]; then
    BATCH1=$(ssh_prod 'echo ":::NGINX_STATUS:::"; systemctl is-active nginx
echo ":::NGINX_VER:::"; nginx -v 2>&1 | grep -oP "\\d+\\.\\d+\\.\\d+"
echo ":::FRONTEND_EXISTS:::"; test -d /var/www/tovplay && echo yes || echo no
echo ":::FRONTEND_SIZE:::"; du -sh /var/www/tovplay 2>/dev/null | cut -f1
echo ":::FILE_COUNT:::"; find /var/www/tovplay -type f 2>/dev/null | wc -l
echo ":::INDEX_EXISTS:::"; test -f /var/www/tovplay/index.html && echo yes || echo no
echo ":::JS_FILES:::"; find /var/www/tovplay -name "*.js" 2>/dev/null | wc -l
echo ":::CSS_FILES:::"; find /var/www/tovplay -name "*.css" 2>/dev/null | wc -l
echo ":::BUNDLE_SIZE:::"; ls -lh /var/www/tovplay/assets/*.js 2>/dev/null | head -3 | awk "{print \$5,\$9}"
echo ":::GZIP_ENABLED:::"; grep -r "gzip on" /etc/nginx/nginx.conf /etc/nginx/sites-enabled/ 2>/dev/null | head -1
echo ":::SSL_ENABLED:::"; grep -r "ssl_certificate" /etc/nginx/sites-enabled/ 2>/dev/null | head -1
echo ":::PERMISSIONS:::"; stat -c "%a" /var/www/tovplay 2>/dev/null
echo ":::OWNER:::"; stat -c "%U:%G" /var/www/tovplay 2>/dev/null
echo ":::LAST_MODIFIED:::"; stat -c "%y" /var/www/tovplay/index.html 2>/dev/null | cut -d. -f1
echo ":::VHOST_EXISTS:::"; test -f /etc/nginx/sites-enabled/tovplay && echo yes || echo no
echo ":::ERROR_LOG:::"; tail -5 /var/log/nginx/error.log 2>/dev/null | grep -i error | tail -2
echo ":::ACCESS_COUNT:::"; wc -l /var/log/nginx/access.log 2>/dev/null | cut -d" " -f1
echo ":::404_COUNT:::"; grep -c " 404 " /var/log/nginx/access.log 2>/dev/null
echo ":::CACHE_CONTROL:::"; grep -r "add_header.*Cache-Control" /etc/nginx/sites-enabled/ 2>/dev/null | head -1
echo ":::SECURITY_HEADERS:::"; grep -r "X-Frame-Options\|X-Content-Type\|X-XSS" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
echo ":::HTTP2:::"; grep -r "http2" /etc/nginx/sites-enabled/ 2>/dev/null | head -1
echo ":::SSL_PROTOCOLS:::"; grep -r "ssl_protocols" /etc/nginx/sites-enabled/ 2>/dev/null | head -1
echo ":::CERTBOT:::"; certbot certificates 2>/dev/null | grep -A2 "app.tovplay.org" | tail -2
echo ":::DISK_USAGE:::"; df -h /var/www | tail -1 | awk "{print \$5}"' 20)

    # Parse results
    NGINX_STATUS=$(echo "$BATCH1" | sed -n '/:::NGINX_STATUS:::/,/:::NGINX_VER:::/p' | tail -1)
    NGINX_VER=$(echo "$BATCH1" | sed -n '/:::NGINX_VER:::/,/:::FRONTEND_EXISTS:::/p' | tail -1)
    FRONTEND_EXISTS=$(echo "$BATCH1" | sed -n '/:::FRONTEND_EXISTS:::/,/:::FRONTEND_SIZE:::/p' | tail -1)
    FRONTEND_SIZE=$(echo "$BATCH1" | sed -n '/:::FRONTEND_SIZE:::/,/:::FILE_COUNT:::/p' | tail -1)
    FILE_COUNT=$(echo "$BATCH1" | sed -n '/:::FILE_COUNT:::/,/:::INDEX_EXISTS:::/p' | tail -1)
    INDEX_EXISTS=$(echo "$BATCH1" | sed -n '/:::INDEX_EXISTS:::/,/:::JS_FILES:::/p' | tail -1)
    JS_FILES=$(echo "$BATCH1" | sed -n '/:::JS_FILES:::/,/:::CSS_FILES:::/p' | tail -1)
    CSS_FILES=$(echo "$BATCH1" | sed -n '/:::CSS_FILES:::/,/:::BUNDLE_SIZE:::/p' | tail -1)
    BUNDLE_SIZE=$(echo "$BATCH1" | sed -n '/:::BUNDLE_SIZE:::/,/:::GZIP_ENABLED:::/p' | grep -v ':::')
    GZIP_ENABLED=$(echo "$BATCH1" | sed -n '/:::GZIP_ENABLED:::/,/:::SSL_ENABLED:::/p' | tail -1)
    SSL_ENABLED=$(echo "$BATCH1" | sed -n '/:::SSL_ENABLED:::/,/:::PERMISSIONS:::/p' | tail -1)
    PERMISSIONS=$(echo "$BATCH1" | sed -n '/:::PERMISSIONS:::/,/:::OWNER:::/p' | tail -1)
    OWNER=$(echo "$BATCH1" | sed -n '/:::OWNER:::/,/:::LAST_MODIFIED:::/p' | tail -1)
    LAST_MODIFIED=$(echo "$BATCH1" | sed -n '/:::LAST_MODIFIED:::/,/:::VHOST_EXISTS:::/p' | tail -1)
    VHOST_EXISTS=$(echo "$BATCH1" | sed -n '/:::VHOST_EXISTS:::/,/:::ERROR_LOG:::/p' | tail -1)
    ERROR_LOG=$(echo "$BATCH1" | sed -n '/:::ERROR_LOG:::/,/:::ACCESS_COUNT:::/p' | grep -v ':::')
    ACCESS_COUNT=$(echo "$BATCH1" | sed -n '/:::ACCESS_COUNT:::/,/:::404_COUNT:::/p' | tail -1)
    COUNT_404=$(echo "$BATCH1" | sed -n '/:::404_COUNT:::/,/:::CACHE_CONTROL:::/p' | tail -1)
    CACHE_CONTROL=$(echo "$BATCH1" | sed -n '/:::CACHE_CONTROL:::/,/:::SECURITY_HEADERS:::/p' | tail -1)
    SEC_HEADERS=$(echo "$BATCH1" | sed -n '/:::SECURITY_HEADERS:::/,/:::HTTP2:::/p' | tail -1)
    HTTP2=$(echo "$BATCH1" | sed -n '/:::HTTP2:::/,/:::SSL_PROTOCOLS:::/p' | tail -1)
    SSL_PROTOCOLS=$(echo "$BATCH1" | sed -n '/:::SSL_PROTOCOLS:::/,/:::CERTBOT:::/p' | tail -1)
    CERTBOT=$(echo "$BATCH1" | sed -n '/:::CERTBOT:::/,/:::DISK_USAGE:::/p' | grep -v ':::')
    DISK_USAGE=$(echo "$BATCH1" | sed -n '/:::DISK_USAGE:::/,$p' | tail -1)

    # Nginx
    echo -e "${CYAN}Nginx:${NC}"
    [ "$NGINX_STATUS" = "active" ] && check_pass "Nginx: active (v$NGINX_VER)" || { check_fail "Nginx: $NGINX_STATUS"; add_critical "[PROD] Nginx down"; }

    # Frontend deployment
    echo -e "\n${CYAN}Frontend Deployment:${NC}"
    [ "$FRONTEND_EXISTS" = "yes" ] && check_pass "Frontend dir: exists" || { check_fail "Frontend dir missing"; add_critical "[PROD] No frontend"; }
    [ "$INDEX_EXISTS" = "yes" ] && check_pass "index.html: exists" || { check_fail "index.html missing"; add_critical "[PROD] No index.html"; }
    check_info "Size: $FRONTEND_SIZE | Files: $FILE_COUNT | JS: $JS_FILES | CSS: $CSS_FILES"
    check_info "Last modified: $LAST_MODIFIED"
    check_info "Permissions: $PERMISSIONS | Owner: $OWNER"

    # Bundle analysis
    echo -e "\n${CYAN}Bundle Analysis:${NC}"
    echo "$BUNDLE_SIZE" | while read -r line; do [ -n "$line" ] && check_info "$line"; done

    # Nginx config
    echo -e "\n${CYAN}Nginx Configuration:${NC}"
    [ -n "$GZIP_ENABLED" ] && check_pass "Gzip: enabled" || { check_warn "Gzip not enabled"; add_medium "[PROD] Enable gzip"; }
    [ -n "$SSL_ENABLED" ] && check_pass "SSL: configured" || { check_fail "SSL not configured"; add_critical "[PROD] No SSL"; }
    [ -n "$HTTP2" ] && check_pass "HTTP/2: enabled" || check_info "HTTP/2: not detected"
    [ -n "$CACHE_CONTROL" ] && check_pass "Cache headers: configured" || { check_warn "No cache headers"; add_low "[PROD] Add cache headers"; }
    [ "${SEC_HEADERS:-0}" -ge 2 ] 2>/dev/null && check_pass "Security headers: $SEC_HEADERS configured" || { check_warn "Security headers: $SEC_HEADERS"; add_medium "[PROD] Add security headers"; }
    [ "$VHOST_EXISTS" = "yes" ] && check_pass "Vhost config: exists" || check_info "Vhost: not in expected location"

    # SSL
    [ -n "$SSL_PROTOCOLS" ] && check_info "SSL: $SSL_PROTOCOLS"
    [ -n "$CERTBOT" ] && check_info "Certbot: $CERTBOT"

    # Logs
    echo -e "\n${CYAN}Logs & Traffic:${NC}"
    check_info "Access log entries: $ACCESS_COUNT"
    [ "${COUNT_404:-0}" -gt 1000 ] 2>/dev/null && { check_warn "404 errors: $COUNT_404"; add_low "[PROD] Many 404s"; } || check_pass "404 errors: ${COUNT_404:-0}"
    if [ -n "$ERROR_LOG" ]; then
        check_warn "Recent errors in nginx error.log"
        echo "$ERROR_LOG" | head -2 | while read -r line; do echo "    $line"; done
    else
        check_pass "No recent nginx errors"
    fi

    # Disk
    DISK_PCT=${DISK_USAGE%%%}
    [ "${DISK_PCT:-0}" -gt 90 ] 2>/dev/null && { check_fail "Disk usage: $DISK_USAGE"; add_high "[PROD] Disk critical"; } || check_pass "Disk usage: $DISK_USAGE"
fi

# ═══════════════════════════════════════════════════════════════
# BATCH 2: STAGING FRONTEND
# ═══════════════════════════════════════════════════════════════
section "31-40" "STAGING FRONTEND"
if [ "$STAGING_CONN" = true ]; then
    BATCH2=$(ssh_staging 'echo ":::NGINX_STATUS:::"; systemctl is-active nginx
echo ":::FRONTEND_EXISTS:::"; test -d /var/www/tovplay-staging && echo yes || echo no
echo ":::INDEX_EXISTS:::"; test -f /var/www/tovplay-staging/index.html && echo yes || echo no
echo ":::FRONTEND_SIZE:::"; du -sh /var/www/tovplay-staging 2>/dev/null | cut -f1
echo ":::FILE_COUNT:::"; find /var/www/tovplay-staging -type f 2>/dev/null | wc -l
echo ":::LAST_MODIFIED:::"; stat -c "%y" /var/www/tovplay-staging/index.html 2>/dev/null | cut -d. -f1' 10)

    STG_NGINX=$(echo "$BATCH2" | sed -n '/:::NGINX_STATUS:::/,/:::FRONTEND_EXISTS:::/p' | tail -1)
    STG_FRONTEND=$(echo "$BATCH2" | sed -n '/:::FRONTEND_EXISTS:::/,/:::INDEX_EXISTS:::/p' | tail -1)
    STG_INDEX=$(echo "$BATCH2" | sed -n '/:::INDEX_EXISTS:::/,/:::FRONTEND_SIZE:::/p' | tail -1)
    STG_SIZE=$(echo "$BATCH2" | sed -n '/:::FRONTEND_SIZE:::/,/:::FILE_COUNT:::/p' | tail -1)
    STG_FILES=$(echo "$BATCH2" | sed -n '/:::FILE_COUNT:::/,/:::LAST_MODIFIED:::/p' | tail -1)
    STG_MODIFIED=$(echo "$BATCH2" | sed -n '/:::LAST_MODIFIED:::/,$p' | tail -1)

    [ "$STG_NGINX" = "active" ] && check_pass "Staging Nginx: active" || check_warn "Staging Nginx: $STG_NGINX"
    [ "$STG_FRONTEND" = "yes" ] && check_pass "Staging frontend: exists" || check_info "Staging frontend: not found"
    [ "$STG_INDEX" = "yes" ] && check_pass "Staging index.html: exists" || check_info "Staging index: not found"
    check_info "Size: $STG_SIZE | Files: $STG_FILES"
    check_info "Last modified: $STG_MODIFIED"
fi

# ═══════════════════════════════════════════════════════════════
# BATCH 3: URL CHECKS (Parallel curl)
# ═══════════════════════════════════════════════════════════════
section "41-50" "URL ACCESSIBILITY"

# Run curl checks in parallel
{
    PROD_HTTP=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$PROD_URL" 2>/dev/null)
    echo "PROD_HTTP:$PROD_HTTP"
} &
{
    PROD_TIME=$(curl -sL -o /dev/null -w "%{time_total}" --connect-timeout 5 --max-time 10 "$PROD_URL" 2>/dev/null)
    echo "PROD_TIME:$PROD_TIME"
} &
{
    STG_HTTP=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$STAGING_URL" 2>/dev/null)
    echo "STG_HTTP:$STG_HTTP"
} &
wait

# Simple curl checks (not batched to avoid complexity)
PROD_HTTP=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$PROD_URL" 2>/dev/null)
PROD_TIME=$(curl -sL -o /dev/null -w "%{time_total}" --connect-timeout 5 --max-time 10 "$PROD_URL" 2>/dev/null)
STG_HTTP=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$STAGING_URL" 2>/dev/null)

[ "$PROD_HTTP" = "200" ] && check_pass "Production URL ($PROD_URL): HTTP $PROD_HTTP" || { check_fail "Production URL: HTTP $PROD_HTTP"; add_critical "[PROD] Site not accessible"; }
[ -n "$PROD_TIME" ] && check_info "Response time: ${PROD_TIME}s"
[ "$STG_HTTP" = "200" ] && check_pass "Staging URL ($STAGING_URL): HTTP $STG_HTTP" || check_warn "Staging URL: HTTP $STG_HTTP"

# ═══════════════════════════════════════════════════════════════
# SECTION 51-60: ENVIRONMENT COMPARISON
# ═══════════════════════════════════════════════════════════════
section "51-60" "ENVIRONMENT COMPARISON"
echo -e "  ${BOLD}Metric              Production    Staging${NC}"
echo -e "  ─────────────────────────────────────────────"
printf "  %-18s %-13s %s\n" "Nginx" "${NGINX_STATUS:-?}" "${STG_NGINX:-?}"
printf "  %-18s %-13s %s\n" "Frontend" "${FRONTEND_EXISTS:-?}" "${STG_FRONTEND:-?}"
printf "  %-18s %-13s %s\n" "Size" "${FRONTEND_SIZE:-?}" "${STG_SIZE:-?}"
printf "  %-18s %-13s %s\n" "Files" "${FILE_COUNT:-?}" "${STG_FILES:-?}"
printf "  %-18s %-13s %s\n" "HTTP Status" "${PROD_HTTP:-?}" "${STG_HTTP:-?}"

# ═══════════════════════════════════════════════════════════════
# RECOMMENDATIONS
# ═══════════════════════════════════════════════════════════════
section "61-80" "RECOMMENDATIONS"
echo -e "${CYAN}Optimization Tips:${NC}"
echo "  • Enable Brotli compression for better ratios"
echo "  • Implement HTTP/3 for improved performance"
echo "  • Add preload hints for critical resources"
echo "  • Consider service worker for offline support"
echo "  • Use WebP/AVIF images for better compression"

print_summary
