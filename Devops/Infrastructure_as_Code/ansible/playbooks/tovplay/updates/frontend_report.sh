#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
# TovPlay Frontend AUDIT v7.0 - MARKER-BASED PARSING (Bulletproof)
# ═════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

# Source ultra-fast SSH helpers
SCRIPT_DIR_ABS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR_ABS/fast_ssh_helpers.sh" 2>/dev/null || true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'; BOLD='\033[1m'

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"
PROD_URL="https://app.tovplay.org"; STAGING_URL="https://staging.tovplay.org"

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

# Extract value from marker-based output
extract_value() {
    local data="$1"
    local marker="$2"
    echo "$data" | grep "^${marker}:" | head -1 | cut -d: -f2-
}

print_summary() {
    local dur=$(($(date +%s) - SCRIPT_START))
    local penalty=$(( ${#CRITICAL_ISSUES[@]}*20 + ${#HIGH_ISSUES[@]}*10 + ${#MEDIUM_ISSUES[@]}*5 + ${#LOW_ISSUES[@]}*2 ))
    local score=$((100 - penalty)); [ $score -lt 0 ] && score=0

    echo -e "\n${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              🔴 THINGS TO FIX - FRONTEND                      ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
        for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
        for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}🟠 HIGH: $issue${NC}"; done
        for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
        for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}🔵 LOW: $issue${NC}"; done
    else
        echo -e "  ${GREEN}✓ No issues found! Frontend is healthy.${NC}"
    fi

    local stars rating
    [ $score -ge 90 ] && { stars="★★★★★"; rating="EXCELLENT"; } || \
    [ $score -ge 80 ] && { stars="★★★★☆"; rating="GOOD"; } || \
    [ $score -ge 70 ] && { stars="★★★☆☆"; rating="FAIR"; } || \
    [ $score -ge 60 ] && { stars="★★☆☆☆"; rating="NEEDS WORK"; } || \
    { stars="★☆☆☆☆"; rating="CRITICAL"; }

    echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  $stars $rating - Score: $score/100${NC}"
    echo -e "${BOLD}║  Time: ${dur}s | Checks: $TOTAL_CHECKS | Passed: $PASSED_CHECKS${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo "FRONTEND_SCORE:$score"
}

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     🌐 FRONTEND AUDIT v7.0 [MARKER-BASED] - $(date '+%Y-%m-%d %H:%M:%S')   ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"

section "1" "CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 15)
STAGING_OK=$(ssh_staging "echo OK" 15)
[ "$PROD_OK" = "OK" ] && { check_pass "Production SSH: connected"; PROD_CONN=true; } || { check_fail "Production SSH: failed"; add_critical "[PROD] SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging SSH: connected"; STAGING_CONN=true; } || { check_fail "Staging SSH: failed"; STAGING_CONN=false; }

section "2-40" "PRODUCTION FRONTEND [MARKER-BASED MEGA BATCH]"
if [ "$PROD_CONN" = true ]; then
    # MEGA BATCH: All production checks with markers
    MEGA=$(ssh_prod '
echo "NGINX_STATUS:$(systemctl is-active nginx)"
echo "NGINX_VER:$(nginx -v 2>&1 | sed -n "s/.*nginx\/\([0-9.]*\).*/\1/p")"
echo "FRONTEND_EXISTS:$(test -d /var/www/tovplay && echo yes || echo no)"
echo "FRONTEND_SIZE:$(du -sh /var/www/tovplay 2>/dev/null | cut -f1)"
echo "FILE_COUNT:$(find /var/www/tovplay -type f 2>/dev/null | wc -l)"
echo "INDEX_EXISTS:$(test -f /var/www/tovplay/index.html && echo yes || echo no)"
echo "JS_FILES:$(find /var/www/tovplay -name "*.js" 2>/dev/null | wc -l)"
echo "CSS_FILES:$(find /var/www/tovplay -name "*.css" 2>/dev/null | wc -l)"
echo "HTML_FILES:$(find /var/www/tovplay -name "*.html" 2>/dev/null | wc -l)"
echo "MAP_FILES:$(find /var/www/tovplay -name "*.map" 2>/dev/null | wc -l)"
echo "PERMISSIONS:$(stat -c "%a" /var/www/tovplay 2>/dev/null)"
echo "OWNER:$(stat -c "%U:%G" /var/www/tovplay 2>/dev/null)"
echo "LAST_MODIFIED:$(stat -c "%y" /var/www/tovplay/index.html 2>/dev/null | cut -d. -f1)"
echo "VHOST_EXISTS:$(test -f /etc/nginx/sites-enabled/tovplay.conf && echo yes || echo no)"
echo "ROBOTS_EXISTS:$(test -f /var/www/tovplay/robots.txt && echo yes || echo no)"
echo "SITEMAP_EXISTS:$(test -f /var/www/tovplay/sitemap.xml && echo yes || echo no)"
echo "FAVICON_EXISTS:$(test -f /var/www/tovplay/favicon.ico && echo yes || echo no)"
echo "ENV_EXISTS:$(test -f /var/www/tovplay/.env && echo yes || echo no)"
echo "DISK_USAGE:$(df -h /var/www | tail -1 | awk "{print \$5}")"
echo "GZIP_ENABLED:$(grep -rq "gzip on" /etc/nginx/nginx.conf /etc/nginx/sites-enabled/ 2>/dev/null && echo yes || echo no)"
echo "SSL_ENABLED:$(grep -rq "ssl_certificate" /etc/nginx/sites-enabled/ 2>/dev/null && echo yes || echo no)"
echo "CACHE_CONTROL:$(grep -rq "add_header.*Cache-Control" /etc/nginx/sites-enabled/ 2>/dev/null && echo yes || echo no)"
echo "SEC_XFRAME:$(grep -r "X-Frame-Options" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "SEC_CONTENT_TYPE:$(grep -r "X-Content-Type" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "SEC_XSS:$(grep -r "X-XSS-Protection" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "SEC_CSP:$(grep -r "Content-Security-Policy" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "SEC_HSTS:$(grep -r "Strict-Transport-Security" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "HTTP2:$(grep -rq "http2" /etc/nginx/sites-enabled/ 2>/dev/null && echo yes || echo no)"
echo "HTTP3:$(grep -rq "http3" /etc/nginx/sites-enabled/ 2>/dev/null && echo yes || echo no)"
echo "BROTLI:$(grep -rq "brotli" /etc/nginx/sites-enabled/ 2>/dev/null && echo yes || echo no)"
echo "NGINX_TEST:$(sudo nginx -t 2>&1 | grep -c "successful")"
echo "NGINX_ACTIVE:$(systemctl show nginx --property=ActiveState --value)"
echo "NGINX_PID:$(systemctl show nginx --property=MainPID --value)"
echo "NGINX_PROCESSES:$(ps aux | grep nginx | grep -v grep | wc -l)"
echo "SSL_LISTENERS:$(grep -r "listen.*443" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "ACCESS_COUNT:$(sudo wc -l /var/log/nginx/access.log 2>/dev/null | cut -d" " -f1)"
echo "COUNT_404:$(sudo tail -10000 /var/log/nginx/access.log 2>/dev/null | grep -c " 404 ")"
echo "COUNT_500:$(sudo tail -10000 /var/log/nginx/access.log 2>/dev/null | grep -c " 500 ")"
echo "COUNT_502:$(sudo tail -10000 /var/log/nginx/access.log 2>/dev/null | grep -c " 502 ")"
echo "ERROR_COUNT:$(sudo tail -100 /var/log/nginx/error.log 2>/dev/null | grep -i error | grep -v "/logs/" | wc -l)"
' 90 | tr -d '\r')

    # Parse with markers - bulletproof extraction
    NGINX_STATUS=$(extract_value "$MEGA" "NGINX_STATUS")
    NGINX_VER=$(extract_value "$MEGA" "NGINX_VER")
    FRONTEND_EXISTS=$(extract_value "$MEGA" "FRONTEND_EXISTS")
    FRONTEND_SIZE=$(extract_value "$MEGA" "FRONTEND_SIZE")
    FILE_COUNT=$(extract_value "$MEGA" "FILE_COUNT")
    INDEX_EXISTS=$(extract_value "$MEGA" "INDEX_EXISTS")
    JS_FILES=$(extract_value "$MEGA" "JS_FILES")
    CSS_FILES=$(extract_value "$MEGA" "CSS_FILES")
    HTML_FILES=$(extract_value "$MEGA" "HTML_FILES")
    MAP_FILES=$(extract_value "$MEGA" "MAP_FILES")
    PERMISSIONS=$(extract_value "$MEGA" "PERMISSIONS")
    OWNER=$(extract_value "$MEGA" "OWNER")
    LAST_MODIFIED=$(extract_value "$MEGA" "LAST_MODIFIED")
    VHOST_EXISTS=$(extract_value "$MEGA" "VHOST_EXISTS")
    ROBOTS_EXISTS=$(extract_value "$MEGA" "ROBOTS_EXISTS")
    SITEMAP_EXISTS=$(extract_value "$MEGA" "SITEMAP_EXISTS")
    FAVICON_EXISTS=$(extract_value "$MEGA" "FAVICON_EXISTS")
    ENV_EXISTS=$(extract_value "$MEGA" "ENV_EXISTS")
    DISK_USAGE=$(extract_value "$MEGA" "DISK_USAGE")
    GZIP_ENABLED=$(extract_value "$MEGA" "GZIP_ENABLED")
    SSL_ENABLED=$(extract_value "$MEGA" "SSL_ENABLED")
    CACHE_CONTROL=$(extract_value "$MEGA" "CACHE_CONTROL")
    SEC_XFRAME=$(extract_value "$MEGA" "SEC_XFRAME")
    SEC_CONTENT_TYPE=$(extract_value "$MEGA" "SEC_CONTENT_TYPE")
    SEC_XSS=$(extract_value "$MEGA" "SEC_XSS")
    SEC_CSP=$(extract_value "$MEGA" "SEC_CSP")
    SEC_HSTS=$(extract_value "$MEGA" "SEC_HSTS")
    HTTP2=$(extract_value "$MEGA" "HTTP2")
    HTTP3=$(extract_value "$MEGA" "HTTP3")
    BROTLI=$(extract_value "$MEGA" "BROTLI")
    NGINX_TEST=$(extract_value "$MEGA" "NGINX_TEST")
    NGINX_ACTIVE=$(extract_value "$MEGA" "NGINX_ACTIVE")
    NGINX_PID=$(extract_value "$MEGA" "NGINX_PID")
    NGINX_PROCESSES=$(extract_value "$MEGA" "NGINX_PROCESSES")
    SSL_LISTENERS=$(extract_value "$MEGA" "SSL_LISTENERS")
    ACCESS_COUNT=$(extract_value "$MEGA" "ACCESS_COUNT")
    COUNT_404=$(extract_value "$MEGA" "COUNT_404")
    COUNT_500=$(extract_value "$MEGA" "COUNT_500")
    COUNT_502=$(extract_value "$MEGA" "COUNT_502")
    ERROR_COUNT=$(extract_value "$MEGA" "ERROR_COUNT")

    # Display results
    echo -e "${CYAN}Nginx Service:${NC}"
    [ "$NGINX_STATUS" = "active" ] && check_pass "Nginx: active (v$NGINX_VER)" || { check_fail "Nginx: $NGINX_STATUS"; add_critical "[PROD] Nginx down"; }
    check_info "State: $NGINX_ACTIVE (PID: $NGINX_PID, Processes: $NGINX_PROCESSES)"
    [ "$NGINX_TEST" = "1" ] && check_pass "Nginx config: valid" || { check_warn "Nginx config: has warnings"; add_low "[PROD] Nginx config warnings"; }

    echo -e "\n${CYAN}Frontend Deployment:${NC}"
    [ "$FRONTEND_EXISTS" = "yes" ] && check_pass "Frontend dir: exists" || { check_fail "Frontend dir missing"; add_critical "[PROD] No frontend"; }
    [ "$INDEX_EXISTS" = "yes" ] && check_pass "index.html: exists" || { check_fail "index.html missing"; add_critical "[PROD] No index.html"; }
    check_info "Size: $FRONTEND_SIZE | Files: $FILE_COUNT (JS: $JS_FILES, CSS: $CSS_FILES, HTML: $HTML_FILES)"
    check_info "Last modified: $LAST_MODIFIED | Permissions: $PERMISSIONS | Owner: $OWNER"

    echo -e "\n${CYAN}Build Artifacts:${NC}"
    [ "$ROBOTS_EXISTS" = "yes" ] && check_pass "robots.txt: exists" || { check_warn "robots.txt: missing"; add_low "[PROD] Add robots.txt"; }
    [ "$SITEMAP_EXISTS" = "yes" ] && check_pass "sitemap.xml: exists" || { check_warn "sitemap.xml: missing"; add_low "[PROD] Add sitemap.xml"; }
    [ "$FAVICON_EXISTS" = "yes" ] && check_pass "favicon.ico: exists" || { check_warn "favicon.ico: missing"; add_low "[PROD] Add favicon"; }
    [ "$ENV_EXISTS" = "yes" ] && { check_warn ".env file exposed!"; add_high "[PROD] Remove .env from public"; } || check_pass ".env: not exposed"
    [ "${MAP_FILES:-0}" -gt 0 ] 2>/dev/null && { check_warn "Source maps exposed: $MAP_FILES files"; add_medium "[PROD] Remove source maps"; } || check_pass "Source maps: not exposed"

    echo -e "\n${CYAN}Nginx Configuration:${NC}"
    [ "$GZIP_ENABLED" = "yes" ] && check_pass "Gzip: enabled" || { check_warn "Gzip not enabled"; add_medium "[PROD] Enable gzip"; }
    [ "$BROTLI" = "yes" ] && check_pass "Brotli: enabled" || check_info "Brotli: not detected"
    [ "$SSL_ENABLED" = "yes" ] && check_pass "SSL: configured" || { check_fail "SSL not configured"; add_critical "[PROD] No SSL"; }
    [ "${SSL_LISTENERS:-0}" -gt 0 ] 2>/dev/null && check_pass "SSL listeners: $SSL_LISTENERS" || check_warn "SSL listeners: not found"
    [ "$HTTP2" = "yes" ] && check_pass "HTTP/2: enabled" || { check_warn "HTTP/2: not enabled"; add_low "[PROD] Enable HTTP/2"; }
    [ "$HTTP3" = "yes" ] && check_pass "HTTP/3: enabled" || check_info "HTTP/3: not detected"
    [ "$CACHE_CONTROL" = "yes" ] && check_pass "Cache headers: configured" || { check_warn "No cache headers"; add_low "[PROD] Add cache headers"; }
    [ "$VHOST_EXISTS" = "yes" ] && check_pass "Vhost config: exists" || check_info "Vhost: checking alternative location"

    echo -e "\n${CYAN}Security Headers:${NC}"
    SEC_TOTAL=$(( ${SEC_XFRAME:-0} + ${SEC_CONTENT_TYPE:-0} + ${SEC_XSS:-0} + ${SEC_CSP:-0} + ${SEC_HSTS:-0} ))
    [ "${SEC_XFRAME:-0}" -gt 0 ] 2>/dev/null && check_pass "X-Frame-Options: configured" || { check_warn "X-Frame-Options: missing"; add_medium "[PROD] Add X-Frame-Options"; }
    [ "${SEC_CONTENT_TYPE:-0}" -gt 0 ] 2>/dev/null && check_pass "X-Content-Type-Options: configured" || { check_warn "X-Content-Type-Options: missing"; add_medium "[PROD] Add X-Content-Type-Options"; }
    [ "${SEC_XSS:-0}" -gt 0 ] 2>/dev/null && check_pass "X-XSS-Protection: configured" || { check_warn "X-XSS-Protection: missing"; add_medium "[PROD] Add X-XSS-Protection"; }
    [ "${SEC_CSP:-0}" -gt 0 ] 2>/dev/null && check_pass "Content-Security-Policy: configured" || { check_warn "CSP: missing"; add_high "[PROD] Add CSP"; }
    [ "${SEC_HSTS:-0}" -gt 0 ] 2>/dev/null && check_pass "HSTS: configured" || { check_warn "HSTS: missing"; add_high "[PROD] Add HSTS"; }
    check_info "Total security headers: $SEC_TOTAL/5"

    echo -e "\n${CYAN}Access Logs & Traffic:${NC}"
    check_info "Total access log entries: ${ACCESS_COUNT:-0}"
    [ "${COUNT_404:-0}" -gt 1000 ] 2>/dev/null && { check_warn "404 errors: $COUNT_404"; add_low "[PROD] Many 404s"; } || check_pass "404 errors: ${COUNT_404:-0}"
    [ "${COUNT_500:-0}" -gt 100 ] 2>/dev/null && { check_warn "500 errors: $COUNT_500"; add_medium "[PROD] Server errors"; } || check_info "500 errors: ${COUNT_500:-0}"
    [ "${COUNT_502:-0}" -gt 100 ] 2>/dev/null && { check_warn "502 errors: $COUNT_502"; add_medium "[PROD] Bad gateway"; } || check_info "502 errors: ${COUNT_502:-0}"
    [ "${ERROR_COUNT:-0}" -gt 10 ] 2>/dev/null && { check_warn "Recent nginx errors: $ERROR_COUNT"; add_medium "[PROD] Check error log"; } || check_pass "Recent errors: ${ERROR_COUNT:-0}"

    DISK_PCT=${DISK_USAGE%%%}
    [ "${DISK_PCT:-0}" -gt 90 ] 2>/dev/null && { check_fail "Disk usage: $DISK_USAGE"; add_high "[PROD] Disk critical"; } || check_pass "Disk usage: $DISK_USAGE"
fi

section "41-50" "STAGING FRONTEND"
if [ "$STAGING_CONN" = true ]; then
    MEGA_STG=$(ssh_staging '
echo "STG_NGINX:$(systemctl is-active nginx)"
echo "STG_FRONTEND:$(test -d /var/www/tovplay-staging && echo yes || echo no)"
echo "STG_INDEX:$(test -f /var/www/tovplay-staging/index.html && echo yes || echo no)"
echo "STG_SIZE:$(du -sh /var/www/tovplay-staging 2>/dev/null | cut -f1)"
echo "STG_FILES:$(find /var/www/tovplay-staging -type f 2>/dev/null | wc -l)"
echo "STG_MODIFIED:$(stat -c "%y" /var/www/tovplay-staging/index.html 2>/dev/null | cut -d. -f1)"
echo "STG_NGINX_VER:$(nginx -v 2>&1 | sed -n "s/.*nginx\/\([0-9.]*\).*/\1/p")"
echo "STG_NGINX_PID:$(systemctl show nginx --property=MainPID --value)"
echo "STG_GZIP:$(grep -c "gzip on" /etc/nginx/nginx.conf 2>/dev/null)"
' 60 | tr -d '\r')

    STG_NGINX=$(extract_value "$MEGA_STG" "STG_NGINX")
    STG_FRONTEND=$(extract_value "$MEGA_STG" "STG_FRONTEND")
    STG_INDEX=$(extract_value "$MEGA_STG" "STG_INDEX")
    STG_SIZE=$(extract_value "$MEGA_STG" "STG_SIZE")
    STG_FILES=$(extract_value "$MEGA_STG" "STG_FILES")
    STG_MODIFIED=$(extract_value "$MEGA_STG" "STG_MODIFIED")
    STG_NGINX_VER=$(extract_value "$MEGA_STG" "STG_NGINX_VER")
    STG_NGINX_PID=$(extract_value "$MEGA_STG" "STG_NGINX_PID")
    STG_GZIP=$(extract_value "$MEGA_STG" "STG_GZIP")

    [ "$STG_NGINX" = "active" ] && check_pass "Staging Nginx: active (v$STG_NGINX_VER, PID: $STG_NGINX_PID)" || check_warn "Staging Nginx: $STG_NGINX"
    [ "$STG_FRONTEND" = "yes" ] && check_pass "Staging frontend: exists" || check_info "Staging frontend: not found"
    [ "$STG_INDEX" = "yes" ] && check_pass "Staging index.html: exists" || check_info "Staging index: not found"
    check_info "Size: $STG_SIZE | Files: $STG_FILES"
    check_info "Last modified: $STG_MODIFIED"
    [ "${STG_GZIP:-0}" -gt 0 ] 2>/dev/null && check_pass "Gzip: configured" || check_info "Gzip: not detected"
fi

section "51-60" "URL ACCESSIBILITY"
PROD_HTTP=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$PROD_URL" 2>/dev/null)
PROD_TIME=$(curl -sL -o /dev/null -w "%{time_total}" --connect-timeout 5 --max-time 10 "$PROD_URL" 2>/dev/null)
STG_HTTP=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$STAGING_URL" 2>/dev/null)
STG_TIME=$(curl -sL -o /dev/null -w "%{time_total}" --connect-timeout 5 --max-time 10 "$STAGING_URL" 2>/dev/null)

[ "$PROD_HTTP" = "200" ] && check_pass "Production URL ($PROD_URL): HTTP $PROD_HTTP" || { check_fail "Production URL: HTTP $PROD_HTTP"; add_critical "[PROD] Site not accessible"; }
[ -n "$PROD_TIME" ] && check_info "Response time: ${PROD_TIME}s"
[ "$STG_HTTP" = "200" ] && check_pass "Staging URL ($STAGING_URL): HTTP $STG_HTTP" || check_warn "Staging URL: HTTP $STG_HTTP"
[ -n "$STG_TIME" ] && check_info "Staging response time: ${STG_TIME}s"

section "61-70" "ENVIRONMENT COMPARISON"
echo -e "  ${BOLD}Metric              Production    Staging${NC}"
echo -e "  ─────────────────────────────────────────────"
printf "  %-18s %-13s %s\n" "Nginx" "${NGINX_STATUS:-?}" "${STG_NGINX:-?}"
printf "  %-18s %-13s %s\n" "Frontend" "${FRONTEND_EXISTS:-?}" "${STG_FRONTEND:-?}"
printf "  %-18s %-13s %s\n" "Size" "${FRONTEND_SIZE:-?}" "${STG_SIZE:-?}"
printf "  %-18s %-13s %s\n" "Files" "${FILE_COUNT:-?}" "${STG_FILES:-?}"
printf "  %-18s %-13s %s\n" "HTTP Status" "${PROD_HTTP:-?}" "${STG_HTTP:-?}"
printf "  %-18s %-13s %s\n" "Response Time" "${PROD_TIME:-?}s" "${STG_TIME:-?}s"

section "71-80" "RECOMMENDATIONS"
echo -e "${CYAN}Performance:${NC}"
[ "$BROTLI" != "yes" ] && echo "  • Enable Brotli compression for 15-25% better compression than gzip"
[ "$HTTP2" != "yes" ] && echo "  • Enable HTTP/2 for multiplexing and header compression"
[ "$HTTP3" != "yes" ] && echo "  • Consider HTTP/3 (QUIC) for improved performance"
echo -e "\n${CYAN}Security:${NC}"
[ "${SEC_CSP:-0}" -eq 0 ] 2>/dev/null && echo "  • Add Content-Security-Policy header to prevent XSS"
[ "${SEC_HSTS:-0}" -eq 0 ] 2>/dev/null && echo "  • Add Strict-Transport-Security header to enforce HTTPS"
echo -e "\n${CYAN}SEO:${NC}"
[ "$ROBOTS_EXISTS" != "yes" ] && echo "  • Add robots.txt for search engine crawlers"
[ "$SITEMAP_EXISTS" != "yes" ] && echo "  • Add sitemap.xml for better search engine indexing"

print_summary
