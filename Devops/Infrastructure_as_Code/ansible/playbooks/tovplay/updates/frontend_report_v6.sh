#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
# TovPlay Frontend AUDIT v6.0 [5X ENHANCED] - MEGA BATCH Edition
# ═════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; ORANGE='\033[0;33m'
NC='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"
PROD_URL="https://app.tovplay.org"; STAGING_URL="https://staging.tovplay.org"

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
TOTAL_CHECKS=0; PASSED_CHECKS=0

ssh_prod() {
    local timeout_val="${2:-60}"
    local retries=2
    local result="" rc=1
    for i in $(seq 1 $retries); do
        result=$(sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout="$timeout_val" -o ServerAliveInterval=15 -o ServerAliveCountMax=5 \
             \
            "$PROD_USER@$PROD_HOST" "$1" 2>/dev/null) && rc=0 && break
        sleep 1
    done
    [ $rc -eq 0 ] && echo "$result"
}

ssh_staging() {
    local timeout_val="${2:-60}"
    local retries=2
    local result="" rc=1
    for i in $(seq 1 $retries); do
        result=$(sshpass -p "$STAGING_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout="$timeout_val" -o ServerAliveInterval=15 -o ServerAliveCountMax=5 \
             \
            "$STAGING_USER@$STAGING_HOST" "$1" 2>/dev/null) && rc=0 && break
        sleep 1
    done
    [ $rc -eq 0 ] && echo "$result"
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

    echo -e "\n${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  $stars $rating - Score: $score/100${NC}"
    echo -e "${BOLD}║  Time: ${dur}s | Checks: $TOTAL_CHECKS | Passed: $PASSED_CHECKS${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo "FRONTEND_SCORE:$score"
}

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     🌐 FRONTEND AUDIT v6.0 [5X ENHANCED] - $(date '+%Y-%m-%d %H:%M:%S')   ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"

section "1" "CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 15)
STAGING_OK=$(ssh_staging "echo OK" 15)
[ "$PROD_OK" = "OK" ] && { check_pass "Production SSH: connected"; PROD_CONN=true; } || { check_fail "Production SSH: failed"; add_critical "[PROD] SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging SSH: connected"; STAGING_CONN=true; } || { check_fail "Staging SSH: failed"; STAGING_CONN=false; }

section "2-40" "PRODUCTION FRONTEND [MEGA BATCH x2]"
if [ "$PROD_CONN" = true ]; then
    # MEGA BATCH 1: Nginx + Frontend basics (30 commands)
    MEGA1=$(ssh_prod "
systemctl is-active nginx
nginx -v 2>&1 | grep -oP '\\d+\\.\\d+\\.\\d+'
test -d /var/www/tovplay && echo yes || echo no
du -sh /var/www/tovplay 2>/dev/null | cut -f1
find /var/www/tovplay -type f 2>/dev/null | wc -l
test -f /var/www/tovplay/index.html && echo yes || echo no
find /var/www/tovplay -name '*.js' 2>/dev/null | wc -l
find /var/www/tovplay -name '*.css' 2>/dev/null | wc -l
find /var/www/tovplay -name '*.html' 2>/dev/null | wc -l
find /var/www/tovplay -name '*.json' 2>/dev/null | wc -l
find /var/www/tovplay -name '*.map' 2>/dev/null | wc -l
find /var/www/tovplay -name '*.gz' 2>/dev/null | wc -l
find /var/www/tovplay -name '*.svg' 2>/dev/null | wc -l
find /var/www/tovplay -name '*.png' 2>/dev/null | wc -l
find /var/www/tovplay -name '*.jpg' -o -name '*.jpeg' 2>/dev/null | wc -l
ls -lh /var/www/tovplay/assets/*.js 2>/dev/null | head -5 | awk '{print \$5,\$9}'
ls -lh /var/www/tovplay/assets/*.css 2>/dev/null | head -3 | awk '{print \$5,\$9}'
stat -c '%a' /var/www/tovplay 2>/dev/null
stat -c '%U:%G' /var/www/tovplay 2>/dev/null
stat -c '%y' /var/www/tovplay/index.html 2>/dev/null | cut -d. -f1
test -f /etc/nginx/sites-enabled/tovplay && echo yes || echo no
test -f /var/www/tovplay/robots.txt && echo yes || echo no
test -f /var/www/tovplay/sitemap.xml && echo yes || echo no
test -f /var/www/tovplay/favicon.ico && echo yes || echo no
test -f /var/www/tovplay/.env && echo yes || echo no
cat /var/www/tovplay/.env 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l || echo '0'
df -h /var/www | tail -1 | awk '{print \$5}'
find /var/www/tovplay -type f -mtime -1 2>/dev/null | wc -l
find /var/www/tovplay -type f -mtime -7 2>/dev/null | wc -l
du -sh /var/www/tovplay/assets 2>/dev/null | cut -f1 || echo '0'
" 60 | tr -d '\r')

    # MEGA BATCH 2: Nginx config + logs + SSL (40 commands)
    MEGA2=$(ssh_prod "
grep -r 'gzip on' /etc/nginx/nginx.conf /etc/nginx/sites-enabled/ 2>/dev/null | head -1
grep -r 'ssl_certificate' /etc/nginx/sites-enabled/ 2>/dev/null | head -1
grep -r 'add_header.*Cache-Control' /etc/nginx/sites-enabled/ 2>/dev/null | head -1
grep -r 'X-Frame-Options' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -r 'X-Content-Type' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -r 'X-XSS-Protection' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -r 'Content-Security-Policy' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -r 'Strict-Transport-Security' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -r 'http2' /etc/nginx/sites-enabled/ 2>/dev/null | head -1
grep -r 'http3' /etc/nginx/sites-enabled/ 2>/dev/null | head -1
grep -r 'brotli' /etc/nginx/sites-enabled/ 2>/dev/null | head -1
grep -r 'ssl_protocols' /etc/nginx/sites-enabled/ 2>/dev/null | head -1
grep -r 'ssl_ciphers' /etc/nginx/sites-enabled/ 2>/dev/null | head -1
grep -r 'listen.*443' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -r 'server_name.*tovplay' /etc/nginx/sites-enabled/ 2>/dev/null | head -1
grep -r 'proxy_pass' /etc/nginx/sites-enabled/tovplay 2>/dev/null | wc -l
wc -l /var/log/nginx/access.log 2>/dev/null | cut -d' ' -f1
grep -c ' 404 ' /var/log/nginx/access.log 2>/dev/null
grep -c ' 500 ' /var/log/nginx/access.log 2>/dev/null
grep -c ' 502 ' /var/log/nginx/access.log 2>/dev/null
grep -c ' 503 ' /var/log/nginx/access.log 2>/dev/null
tail -100 /var/log/nginx/error.log 2>/dev/null | grep -i error | wc -l
tail -5 /var/log/nginx/error.log 2>/dev/null | grep -i error | tail -2
tail -100 /var/log/nginx/access.log 2>/dev/null | awk '{print \$9}' | sort | uniq -c | sort -rn | head -5
certbot certificates 2>/dev/null | grep -A2 'app.tovplay.org' | grep 'Expiry Date' | awk '{print \$3,\$4}'
certbot certificates 2>/dev/null | grep -A2 'app.tovplay.org' | grep 'Certificate Path'
nginx -t 2>&1 | grep -c 'successful'
systemctl show nginx --property=ActiveState --value
systemctl show nginx --property=SubState --value
systemctl show nginx --property=MainPID --value
ps aux | grep nginx | grep -v grep | wc -l
netstat -tlnp 2>/dev/null | grep -c ':80\\|:443'
ss -tlnp 2>/dev/null | grep nginx | wc -l
stat -c '%y' /etc/nginx/sites-enabled/tovplay 2>/dev/null | cut -d. -f1
cat /var/www/tovplay/index.html 2>/dev/null | head -20 | grep -oP '(?<=<title>).*(?=</title>)' || echo 'unknown'
cat /var/www/tovplay/index.html 2>/dev/null | grep -oP '(?<=<meta name=\"description\" content=\").*(?=\")' | head -1 || echo 'none'
cat /var/www/tovplay/index.html 2>/dev/null | grep -c 'script src'
cat /var/www/tovplay/index.html 2>/dev/null | grep -c 'link.*css'
cat /var/www/tovplay/package.json 2>/dev/null | grep -oP '(?<=\"version\": \").*(?=\")' | head -1 || echo 'unknown'
cat /var/www/tovplay/package.json 2>/dev/null | grep -oP '(?<=\"react\": \").*(?=\")' | head -1 || echo 'unknown'
" 60 | tr -d '\r')

    # Parse MEGA BATCH 1
    IFS=$'\n' read -d '' -r -a L1 <<< "$MEGA1"
    NGINX_STATUS="${L1[0]}"
    NGINX_VER="${L1[1]}"
    FRONTEND_EXISTS="${L1[2]}"
    FRONTEND_SIZE="${L1[3]}"
    FILE_COUNT="${L1[4]}"
    INDEX_EXISTS="${L1[5]}"
    JS_FILES="${L1[6]}"
    CSS_FILES="${L1[7]}"
    HTML_FILES="${L1[8]}"
    JSON_FILES="${L1[9]}"
    MAP_FILES="${L1[10]}"
    GZ_FILES="${L1[11]}"
    SVG_FILES="${L1[12]}"
    PNG_FILES="${L1[13]}"
    JPG_FILES="${L1[14]}"
    # Lines 15-19: JS bundles (5 lines)
    BUNDLE_JS="${L1[15]}"$'\n'"${L1[16]}"$'\n'"${L1[17]}"$'\n'"${L1[18]}"$'\n'"${L1[19]}"
    # Lines 20-22: CSS bundles (3 lines)
    BUNDLE_CSS="${L1[20]}"$'\n'"${L1[21]}"$'\n'"${L1[22]}"
    PERMISSIONS="${L1[23]}"
    OWNER="${L1[24]}"
    LAST_MODIFIED="${L1[25]}"
    VHOST_EXISTS="${L1[26]}"
    ROBOTS_EXISTS="${L1[27]}"
    SITEMAP_EXISTS="${L1[28]}"
    FAVICON_EXISTS="${L1[29]}"
    ENV_EXISTS="${L1[30]}"
    ENV_VARS="${L1[31]}"
    DISK_USAGE="${L1[32]}"
    FILES_1DAY="${L1[33]}"
    FILES_7DAYS="${L1[34]}"
    ASSETS_SIZE="${L1[35]}"

    # Parse MEGA BATCH 2
    IFS=$'\n' read -d '' -r -a L2 <<< "$MEGA2"
    GZIP_ENABLED="${L2[0]}"
    SSL_ENABLED="${L2[1]}"
    CACHE_CONTROL="${L2[2]}"
    SEC_XFRAME="${L2[3]}"
    SEC_CONTENT_TYPE="${L2[4]}"
    SEC_XSS="${L2[5]}"
    SEC_CSP="${L2[6]}"
    SEC_HSTS="${L2[7]}"
    HTTP2="${L2[8]}"
    HTTP3="${L2[9]}"
    BROTLI="${L2[10]}"
    SSL_PROTOCOLS="${L2[11]}"
    SSL_CIPHERS="${L2[12]}"
    SSL_LISTENERS="${L2[13]}"
    SERVER_NAME="${L2[14]}"
    PROXY_PASS_COUNT="${L2[15]}"
    ACCESS_COUNT="${L2[16]}"
    COUNT_404="${L2[17]}"
    COUNT_500="${L2[18]}"
    COUNT_502="${L2[19]}"
    COUNT_503="${L2[20]}"
    ERROR_COUNT="${L2[21]}"
    ERROR_LOGS="${L2[22]}"$'\n'"${L2[23]}"
    # Lines 24-28: Status code distribution (5 lines)
    STATUS_DIST="${L2[24]}"$'\n'"${L2[25]}"$'\n'"${L2[26]}"$'\n'"${L2[27]}"$'\n'"${L2[28]}"
    SSL_EXPIRY="${L2[29]}"
    SSL_CERT_PATH="${L2[30]}"
    NGINX_TEST="${L2[31]}"
    NGINX_ACTIVE="${L2[32]}"
    NGINX_SUBSTATE="${L2[33]}"
    NGINX_PID="${L2[34]}"
    NGINX_PROCESSES="${L2[35]}"
    PORT_LISTENERS="${L2[36]}"
    NGINX_SOCKETS="${L2[37]}"
    VHOST_MODIFIED="${L2[38]}"
    PAGE_TITLE="${L2[39]}"
    PAGE_DESCRIPTION="${L2[40]}"
    SCRIPT_TAGS="${L2[41]}"
    CSS_LINKS="${L2[42]}"
    PKG_VERSION="${L2[43]}"
    REACT_VERSION="${L2[44]}"

    # Display results
    echo -e "${CYAN}Nginx Service:${NC}"
    [ "$NGINX_STATUS" = "active" ] && check_pass "Nginx: active (v$NGINX_VER)" || { check_fail "Nginx: $NGINX_STATUS"; add_critical "[PROD] Nginx down"; }
    check_info "State: $NGINX_ACTIVE / $NGINX_SUBSTATE (PID: $NGINX_PID)"
    check_info "Processes: $NGINX_PROCESSES | Sockets: $NGINX_SOCKETS | Port listeners: $PORT_LISTENERS"
    [ "$NGINX_TEST" = "1" ] && check_pass "Nginx config: valid" || { check_warn "Nginx config: has warnings"; add_low "[PROD] Nginx config warnings"; }

    echo -e "\n${CYAN}Frontend Deployment:${NC}"
    [ "$FRONTEND_EXISTS" = "yes" ] && check_pass "Frontend dir: exists" || { check_fail "Frontend dir missing"; add_critical "[PROD] No frontend"; }
    [ "$INDEX_EXISTS" = "yes" ] && check_pass "index.html: exists" || { check_fail "index.html missing"; add_critical "[PROD] No index.html"; }
    check_info "Size: $FRONTEND_SIZE | Assets: $ASSETS_SIZE"
    check_info "Files: $FILE_COUNT (JS: $JS_FILES, CSS: $CSS_FILES, HTML: $HTML_FILES)"
    check_info "Assets: JSON: $JSON_FILES, Maps: $MAP_FILES, Gzip: $GZ_FILES"
    check_info "Images: SVG: $SVG_FILES, PNG: $PNG_FILES, JPG: $JPG_FILES"
    check_info "Last modified: $LAST_MODIFIED"
    check_info "Permissions: $PERMISSIONS | Owner: $OWNER"
    check_info "Recent activity: $FILES_1DAY files (24h), $FILES_7DAYS files (7d)"

    echo -e "\n${CYAN}Application Info:${NC}"
    check_info "Title: $PAGE_TITLE"
    [ -n "$PAGE_DESCRIPTION" ] && [ "$PAGE_DESCRIPTION" != "none" ] && check_info "Description: $PAGE_DESCRIPTION"
    check_info "Scripts in HTML: $SCRIPT_TAGS | CSS links: $CSS_LINKS"
    [ "$PKG_VERSION" != "unknown" ] && check_info "Package version: $PKG_VERSION"
    [ "$REACT_VERSION" != "unknown" ] && check_info "React version: $REACT_VERSION"

    echo -e "\n${CYAN}Build Artifacts:${NC}"
    [ "$ROBOTS_EXISTS" = "yes" ] && check_pass "robots.txt: exists" || { check_warn "robots.txt: missing"; add_low "[PROD] Add robots.txt"; }
    [ "$SITEMAP_EXISTS" = "yes" ] && check_pass "sitemap.xml: exists" || { check_warn "sitemap.xml: missing"; add_low "[PROD] Add sitemap.xml"; }
    [ "$FAVICON_EXISTS" = "yes" ] && check_pass "favicon.ico: exists" || { check_warn "favicon.ico: missing"; add_low "[PROD] Add favicon"; }
    if [ "$ENV_EXISTS" = "yes" ]; then
        check_warn ".env file exposed! ($ENV_VARS vars)"
        add_high "[PROD] Remove .env from public"
    else
        check_pass ".env: not exposed"
    fi
    [ "${MAP_FILES:-0}" -gt 0 ] 2>/dev/null && { check_warn "Source maps exposed: $MAP_FILES files"; add_medium "[PROD] Remove source maps from production"; } || check_pass "Source maps: not exposed"

    echo -e "\n${CYAN}Bundle Analysis:${NC}"
    echo "$BUNDLE_JS" | while read -r line; do [ -n "$line" ] && check_info "JS: $line"; done
    echo "$BUNDLE_CSS" | while read -r line; do [ -n "$line" ] && check_info "CSS: $line"; done

    echo -e "\n${CYAN}Nginx Configuration:${NC}"
    [ -n "$GZIP_ENABLED" ] && check_pass "Gzip: enabled" || { check_warn "Gzip not enabled"; add_medium "[PROD] Enable gzip"; }
    [ -n "$BROTLI" ] && check_pass "Brotli: enabled" || check_info "Brotli: not detected"
    [ -n "$SSL_ENABLED" ] && check_pass "SSL: configured" || { check_fail "SSL not configured"; add_critical "[PROD] No SSL"; }
    [ "${SSL_LISTENERS:-0}" -gt 0 ] 2>/dev/null && check_pass "SSL listeners: $SSL_LISTENERS" || check_warn "SSL listeners: not found"
    [ -n "$HTTP2" ] && check_pass "HTTP/2: enabled" || { check_warn "HTTP/2: not enabled"; add_low "[PROD] Enable HTTP/2"; }
    [ -n "$HTTP3" ] && check_pass "HTTP/3: enabled" || check_info "HTTP/3: not detected"
    [ -n "$CACHE_CONTROL" ] && check_pass "Cache headers: configured" || { check_warn "No cache headers"; add_low "[PROD] Add cache headers"; }
    [ "$VHOST_EXISTS" = "yes" ] && check_pass "Vhost config: exists" || check_info "Vhost: not in expected location"
    [ -n "$SERVER_NAME" ] && check_info "Server name: $SERVER_NAME"
    [ "${PROXY_PASS_COUNT:-0}" -gt 0 ] 2>/dev/null && check_info "Proxy passes: $PROXY_PASS_COUNT"
    [ -n "$VHOST_MODIFIED" ] && check_info "Vhost modified: $VHOST_MODIFIED"

    echo -e "\n${CYAN}Security Headers:${NC}"
    SEC_TOTAL=$(( ${SEC_XFRAME:-0} + ${SEC_CONTENT_TYPE:-0} + ${SEC_XSS:-0} + ${SEC_CSP:-0} + ${SEC_HSTS:-0} ))
    [ "${SEC_XFRAME:-0}" -gt 0 ] 2>/dev/null && check_pass "X-Frame-Options: configured" || { check_warn "X-Frame-Options: missing"; add_medium "[PROD] Add X-Frame-Options"; }
    [ "${SEC_CONTENT_TYPE:-0}" -gt 0 ] 2>/dev/null && check_pass "X-Content-Type-Options: configured" || { check_warn "X-Content-Type-Options: missing"; add_medium "[PROD] Add X-Content-Type-Options"; }
    [ "${SEC_XSS:-0}" -gt 0 ] 2>/dev/null && check_pass "X-XSS-Protection: configured" || { check_warn "X-XSS-Protection: missing"; add_medium "[PROD] Add X-XSS-Protection"; }
    [ "${SEC_CSP:-0}" -gt 0 ] 2>/dev/null && check_pass "Content-Security-Policy: configured" || { check_warn "CSP: missing"; add_high "[PROD] Add CSP"; }
    [ "${SEC_HSTS:-0}" -gt 0 ] 2>/dev/null && check_pass "HSTS: configured" || { check_warn "HSTS: missing"; add_high "[PROD] Add HSTS"; }
    check_info "Total security headers: $SEC_TOTAL/5"

    echo -e "\n${CYAN}SSL/TLS Configuration:${NC}"
    [ -n "$SSL_PROTOCOLS" ] && check_info "Protocols: $SSL_PROTOCOLS"
    [ -n "$SSL_CIPHERS" ] && check_info "Ciphers: $(echo $SSL_CIPHERS | head -c 60)..."
    if [ -n "$SSL_EXPIRY" ]; then
        check_info "Certificate expires: $SSL_EXPIRY"
        # TODO: Add expiry date parsing and warning
    fi
    [ -n "$SSL_CERT_PATH" ] && check_info "Cert path: $SSL_CERT_PATH"

    echo -e "\n${CYAN}Access Logs & Traffic:${NC}"
    check_info "Total access log entries: $ACCESS_COUNT"
    [ "${COUNT_404:-0}" -gt 1000 ] 2>/dev/null && { check_warn "404 errors: $COUNT_404"; add_low "[PROD] Many 404s"; } || check_pass "404 errors: ${COUNT_404:-0}"
    [ "${COUNT_500:-0}" -gt 10 ] 2>/dev/null && { check_warn "500 errors: $COUNT_500"; add_high "[PROD] Server errors"; } || check_info "500 errors: ${COUNT_500:-0}"
    [ "${COUNT_502:-0}" -gt 10 ] 2>/dev/null && { check_warn "502 errors: $COUNT_502"; add_high "[PROD] Bad gateway"; } || check_info "502 errors: ${COUNT_502:-0}"
    [ "${COUNT_503:-0}" -gt 10 ] 2>/dev/null && { check_warn "503 errors: $COUNT_503"; add_high "[PROD] Service unavailable"; } || check_info "503 errors: ${COUNT_503:-0}"

    echo -e "\n${CYAN}Status Code Distribution:${NC}"
    echo "$STATUS_DIST" | head -5 | while read -r line; do
        [ -n "$line" ] && check_info "$line"
    done

    echo -e "\n${CYAN}Error Analysis:${NC}"
    [ "${ERROR_COUNT:-0}" -gt 10 ] 2>/dev/null && { check_warn "Recent nginx errors: $ERROR_COUNT"; add_medium "[PROD] Check error log"; } || check_pass "Recent errors: ${ERROR_COUNT:-0}"
    if [ -n "$ERROR_LOGS" ]; then
        echo "$ERROR_LOGS" | head -2 | while read -r line; do
            [ -n "$line" ] && echo "    $line"
        done
    fi

    DISK_PCT=${DISK_USAGE%%%}
    [ "${DISK_PCT:-0}" -gt 90 ] 2>/dev/null && { check_fail "Disk usage: $DISK_USAGE"; add_high "[PROD] Disk critical"; } || check_pass "Disk usage: $DISK_USAGE"
fi

section "41-50" "STAGING FRONTEND [MEGA BATCH]"
if [ "$STAGING_CONN" = true ]; then
    MEGA_STG=$(ssh_staging "
systemctl is-active nginx
test -d /var/www/tovplay-staging && echo yes || echo no
test -f /var/www/tovplay-staging/index.html && echo yes || echo no
du -sh /var/www/tovplay-staging 2>/dev/null | cut -f1
find /var/www/tovplay-staging -type f 2>/dev/null | wc -l
stat -c '%y' /var/www/tovplay-staging/index.html 2>/dev/null | cut -d. -f1
find /var/www/tovplay-staging -name '*.js' 2>/dev/null | wc -l
find /var/www/tovplay-staging -name '*.css' 2>/dev/null | wc -l
nginx -v 2>&1 | grep -oP '\\d+\\.\\d+\\.\\d+'
systemctl show nginx --property=MainPID --value
grep -c 'gzip on' /etc/nginx/nginx.conf 2>/dev/null
tail -100 /var/log/nginx/access.log 2>/dev/null | grep -c 'staging.tovplay.org'
" 60 | tr -d '\r')

    IFS=$'\n' read -d '' -r -a STG_LINES <<< "$MEGA_STG"
    STG_NGINX="${STG_LINES[0]}"
    STG_FRONTEND="${STG_LINES[1]}"
    STG_INDEX="${STG_LINES[2]}"
    STG_SIZE="${STG_LINES[3]}"
    STG_FILES="${STG_LINES[4]}"
    STG_MODIFIED="${STG_LINES[5]}"
    STG_JS="${STG_LINES[6]}"
    STG_CSS="${STG_LINES[7]}"
    STG_NGINX_VER="${STG_LINES[8]}"
    STG_NGINX_PID="${STG_LINES[9]}"
    STG_GZIP="${STG_LINES[10]}"
    STG_ACCESS="${STG_LINES[11]}"

    [ "$STG_NGINX" = "active" ] && check_pass "Staging Nginx: active (v$STG_NGINX_VER, PID: $STG_NGINX_PID)" || check_warn "Staging Nginx: $STG_NGINX"
    [ "$STG_FRONTEND" = "yes" ] && check_pass "Staging frontend: exists" || check_info "Staging frontend: not found"
    [ "$STG_INDEX" = "yes" ] && check_pass "Staging index.html: exists" || check_info "Staging index: not found"
    check_info "Size: $STG_SIZE | Files: $STG_FILES (JS: $STG_JS, CSS: $STG_CSS)"
    check_info "Last modified: $STG_MODIFIED"
    [ "${STG_GZIP:-0}" -gt 0 ] 2>/dev/null && check_pass "Gzip: configured" || check_info "Gzip: not detected"
    check_info "Recent staging access: $STG_ACCESS requests"
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
[ -z "$BROTLI" ] && echo "  • Enable Brotli compression for 15-25% better compression than gzip"
[ -z "$HTTP2" ] && echo "  • Enable HTTP/2 for multiplexing and header compression"
[ -z "$HTTP3" ] && echo "  • Consider HTTP/3 (QUIC) for improved performance"
echo -e "\n${CYAN}Security:${NC}"
[ "${SEC_CSP:-0}" -eq 0 ] 2>/dev/null && echo "  • Add Content-Security-Policy header to prevent XSS"
[ "${SEC_HSTS:-0}" -eq 0 ] 2>/dev/null && echo "  • Add Strict-Transport-Security header to enforce HTTPS"
echo -e "\n${CYAN}SEO:${NC}"
[ "$ROBOTS_EXISTS" != "yes" ] && echo "  • Add robots.txt for search engine crawlers"
[ "$SITEMAP_EXISTS" != "yes" ] && echo "  • Add sitemap.xml for better search engine indexing"

print_summary
