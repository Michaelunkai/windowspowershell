#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# NGINX AUDIT v6.0 [5X ENHANCED] - MEGA BATCH Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
SCORE=100

ssh_prod() {
    local timeout_val="${2:-60}"
    local retries=2
    local result="" rc=1
    for i in $(seq 1 $retries); do
        result=$(sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout="$timeout_val" -o ServerAliveInterval=15 -o ServerAliveCountMax=5 \
            -o LogLevel=ERROR \
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
            -o LogLevel=ERROR \
            "$STAGING_USER@$STAGING_HOST" "$1" 2>/dev/null) && rc=0 && break
        sleep 1
    done
    [ $rc -eq 0 ] && echo "$result"
}

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
echo -e "${BOLD}${MAGENTA}║     🌐 NGINX AUDIT v6.0 [5X ENHANCED] - $(date '+%Y-%m-%d %H:%M:%S')          ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 15)
STAGING_OK=$(ssh_staging "echo OK" 15)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { STAGING_CONN=false; }

section "2-60. COMPREHENSIVE NGINX AUDIT [MEGA BATCH x2]"
if [ "$PROD_CONN" = true ]; then
    # ═══════════════════════════════════════════════════════════════════════════════
    # MEGA BATCH 1: PRODUCTION NGINX - 68 COMMANDS
    # ═══════════════════════════════════════════════════════════════════════════════
    MEGA1=$(ssh_prod "
systemctl is-active nginx
nginx -v 2>&1 | grep -oP '\\d+\\.\\d+\\.\\d+' || echo unknown
sudo nginx -t 2>&1 | tail -1
grep 'worker_processes' /etc/nginx/nginx.conf 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo auto
grep 'worker_connections' /etc/nginx/nginx.conf 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo 512
grep -r 'gzip on' /etc/nginx/ 2>/dev/null | head -1 | cut -d: -f1 || echo not_found
grep -r 'ssl_protocols' /etc/nginx/ 2>/dev/null | head -1 | awk '{for(i=2;i<=NF;i++) printf \$i\" \";}' || echo not_found
ls /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
ls /etc/nginx/sites-enabled/ 2>/dev/null | head -5 | tr '\\n' ',' || echo none
grep -r 'http2' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -rE 'X-Frame-Options|X-Content-Type|X-XSS' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -r 'add_header.*Cache-Control' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
du -sh /var/log/nginx/error.log 2>/dev/null | cut -f1 || echo 0
du -sh /var/log/nginx/access.log 2>/dev/null | cut -f1 || echo 0
tail -10 /var/log/nginx/error.log 2>/dev/null | grep -i error | wc -l || echo 0
grep -c ' 404 ' /var/log/nginx/access.log 2>/dev/null || echo 0
grep -c ' 500 ' /var/log/nginx/access.log 2>/dev/null || echo 0
grep -c ' 502 ' /var/log/nginx/access.log 2>/dev/null || echo 0
grep -c ' 503 ' /var/log/nginx/access.log 2>/dev/null || echo 0
systemctl is-active certbot.timer 2>/dev/null || echo inactive
grep 'ssl_certificate' /etc/nginx/sites-enabled/* 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo not_found
openssl x509 -in /etc/letsencrypt/live/*/cert.pem -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2 || echo not_found
grep 'ssl_ciphers' /etc/nginx/nginx.conf /etc/nginx/sites-enabled/* 2>/dev/null | head -1 | awk '{for(i=2;i<=NF;i++) printf \$i\" \";}' || echo not_configured
grep -r 'ssl_prefer_server_ciphers' /etc/nginx/ 2>/dev/null | grep -c 'on' || echo 0
grep -r 'add_header Strict-Transport-Security' /etc/nginx/ 2>/dev/null | wc -l
grep -r 'client_max_body_size' /etc/nginx/ 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo 1m
grep -r 'client_body_buffer_size' /etc/nginx/ 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo 128k
grep -r 'client_header_buffer_size' /etc/nginx/ 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo 1k
grep -r 'keepalive_timeout' /etc/nginx/ 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo 65
grep -r 'proxy_pass' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -r 'proxy_buffer_size' /etc/nginx/ 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo 4k
grep -r 'proxy_connect_timeout' /etc/nginx/ 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo 60s
grep -r 'limit_req_zone' /etc/nginx/ 2>/dev/null | wc -l
grep -r 'limit_conn_zone' /etc/nginx/ 2>/dev/null | wc -l
grep -r 'upstream' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -r 'fastcgi_cache' /etc/nginx/ 2>/dev/null | wc -l
grep -r 'proxy_cache' /etc/nginx/ 2>/dev/null | wc -l
grep -r 'access_log.*off' /etc/nginx/ 2>/dev/null | wc -l
ps aux | grep 'nginx: worker' | grep -v grep | wc -l
ps aux | grep nginx | grep -v grep | awk '{sum+=\$3} END {printf \"%.1f\", sum}' || echo 0
ps aux | grep nginx | grep -v grep | awk '{sum+=\$4} END {printf \"%.1f\", sum}' || echo 0
netstat -an | grep -c ':80.*LISTEN' 2>/dev/null || ss -tlnp 2>/dev/null | grep -c ':80'
netstat -an | grep -c ':443.*LISTEN' 2>/dev/null || ss -tlnp 2>/dev/null | grep -c ':443'
nginx -V 2>&1 | grep -o -- '--with-[^[:space:]]*' | wc -l
nginx -V 2>&1 | grep -c 'http_ssl_module' || echo 0
nginx -V 2>&1 | grep -c 'http_v2_module' || echo 0
nginx -V 2>&1 | grep -c 'http_gzip_static_module' || echo 0
nginx -V 2>&1 | grep -c 'http_realip_module' || echo 0
grep -r 'server_tokens' /etc/nginx/ 2>/dev/null | grep -c 'off' || echo 0
grep -r 'add_header X-Frame-Options' /etc/nginx/ 2>/dev/null | wc -l
grep -r 'add_header X-Content-Type-Options' /etc/nginx/ 2>/dev/null | wc -l
grep -r 'add_header X-XSS-Protection' /etc/nginx/ 2>/dev/null | wc -l
grep -r 'add_header Content-Security-Policy' /etc/nginx/ 2>/dev/null | wc -l
find /etc/nginx -name '*.conf' -type f 2>/dev/null | wc -l
find /var/log/nginx -name '*.log' -type f 2>/dev/null | wc -l
tail -1000 /var/log/nginx/access.log 2>/dev/null | grep -c 'GET' || echo 0
tail -1000 /var/log/nginx/access.log 2>/dev/null | grep -c 'POST' || echo 0
tail -100 /var/log/nginx/error.log 2>/dev/null | grep -ic 'timeout' || echo 0
tail -100 /var/log/nginx/error.log 2>/dev/null | grep -ic 'refused' || echo 0
systemctl show nginx --property=ActiveEnterTimestamp --value 2>/dev/null | cut -d' ' -f1-2 || echo unknown
systemctl show nginx --property=MemoryCurrent --value 2>/dev/null | awk '{printf \"%.1fM\", \$1/1024/1024}' || echo 0
systemctl status nginx 2>/dev/null | grep -c 'active (running)' || echo 0
grep -r 'error_log' /etc/nginx/nginx.conf 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo /var/log/nginx/error.log
grep -r 'access_log' /etc/nginx/nginx.conf 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo /var/log/nginx/access.log
df -h /var/log/nginx 2>/dev/null | tail -1 | awk '{print \$5}' || echo 0%
du -sh /etc/nginx 2>/dev/null | cut -f1 || echo 0
ls -ld /etc/nginx 2>/dev/null | awk '{print \$1}' || echo unknown
ls -ld /var/log/nginx 2>/dev/null | awk '{print \$1}' || echo unknown
" 60 | tr -d '\r')

    IFS=$'\n' read -d '' -r -a L1 <<< "$MEGA1"

    NGINX_STATUS="${L1[0]}"
    NGINX_VER="${L1[1]}"
    CONFIG_TEST="${L1[2]}"
    WORKER_PROC="${L1[3]}"
    WORKER_CONN="${L1[4]}"
    GZIP_CONF="${L1[5]}"
    SSL_PROTO="${L1[6]}"
    VHOSTS_COUNT="${L1[7]}"
    SITES_LIST="${L1[8]}"
    HTTP2_COUNT="${L1[9]}"
    SEC_HEADERS="${L1[10]}"
    CACHE_HEADERS="${L1[11]}"
    ERR_SIZE="${L1[12]}"
    ACC_SIZE="${L1[13]}"
    ERR_COUNT="${L1[14]}"
    COUNT_404="${L1[15]}"
    COUNT_500="${L1[16]}"
    COUNT_502="${L1[17]}"
    COUNT_503="${L1[18]}"
    CERTBOT="${L1[19]}"
    SSL_CERT_PATH="${L1[20]}"
    SSL_EXPIRY="${L1[21]}"
    SSL_CIPHERS="${L1[22]}"
    SSL_PREFER="${L1[23]}"
    HSTS_COUNT="${L1[24]}"
    MAX_BODY_SIZE="${L1[25]}"
    BODY_BUFFER="${L1[26]}"
    HEADER_BUFFER="${L1[27]}"
    KEEPALIVE="${L1[28]}"
    PROXY_COUNT="${L1[29]}"
    PROXY_BUFFER="${L1[30]}"
    PROXY_TIMEOUT="${L1[31]}"
    RATE_LIMIT="${L1[32]}"
    CONN_LIMIT="${L1[33]}"
    UPSTREAM_COUNT="${L1[34]}"
    FASTCGI_CACHE="${L1[35]}"
    PROXY_CACHE="${L1[36]}"
    ACCESS_LOG_OFF="${L1[37]}"
    WORKER_PROCS="${L1[38]}"
    NGINX_CPU="${L1[39]}"
    NGINX_MEM="${L1[40]}"
    PORT_80="${L1[41]}"
    PORT_443="${L1[42]}"
    MODULES_COUNT="${L1[43]}"
    MOD_SSL="${L1[44]}"
    MOD_HTTP2="${L1[45]}"
    MOD_GZIP="${L1[46]}"
    MOD_REALIP="${L1[47]}"
    SERVER_TOKENS="${L1[48]}"
    XFRAME="${L1[49]}"
    XCONTENT="${L1[50]}"
    XXSS="${L1[51]}"
    CSP="${L1[52]}"
    CONF_FILES="${L1[53]}"
    LOG_FILES="${L1[54]}"
    GET_REQUESTS="${L1[55]}"
    POST_REQUESTS="${L1[56]}"
    TIMEOUT_ERRORS="${L1[57]}"
    REFUSED_ERRORS="${L1[58]}"
    START_TIME="${L1[59]}"
    MEM_USAGE="${L1[60]}"
    SERVICE_STATUS="${L1[61]}"
    ERROR_LOG_PATH="${L1[62]}"
    ACCESS_LOG_PATH="${L1[63]}"
    LOG_DISK_USAGE="${L1[64]}"
    CONF_SIZE="${L1[65]}"
    CONF_PERMS="${L1[66]}"
    LOG_PERMS="${L1[67]}"

    # ═══════════════════════════════════════════════════════════════════════════════
    # DISPLAY PRODUCTION RESULTS
    # ═══════════════════════════════════════════════════════════════════════════════

    echo -e "${CYAN}Service & Version:${NC}"
    [ "$NGINX_STATUS" = "active" ] && check_pass "Nginx: active (v$NGINX_VER)" || { check_fail "Nginx: $NGINX_STATUS"; add_critical "Nginx not running"; }
    echo "$CONFIG_TEST" | grep -qi "successful" && check_pass "Config test: passed" || { check_warn "Config test: failed"; add_high "Nginx config error"; }
    [ "$SERVICE_STATUS" = "1" ] && check_pass "Service: running" || check_warn "Service status check failed"
    check_info "Started: $START_TIME | Memory: $MEM_USAGE | CPU: ${NGINX_CPU}% | RAM: ${NGINX_MEM}%"

    echo -e "\n${CYAN}Core Configuration:${NC}"
    check_info "Worker processes: $WORKER_PROC ($WORKER_PROCS active) | Connections: $WORKER_CONN"
    [ "${WORKER_PROCS:-0}" -ge 1 ] 2>/dev/null && check_pass "Active workers: $WORKER_PROCS" || { check_warn "No workers found"; add_high "Nginx workers missing"; }
    check_info "Keepalive timeout: $KEEPALIVE | Body size: $MAX_BODY_SIZE"
    check_info "Buffers: Body=$BODY_BUFFER, Header=$HEADER_BUFFER"

    echo -e "\n${CYAN}Compression & Caching:${NC}"
    [ "$GZIP_CONF" != "not_found" ] && check_pass "Gzip: enabled" || { check_warn "Gzip: disabled"; add_medium "Enable gzip compression"; }
    [ "${FASTCGI_CACHE:-0}" -gt 0 ] 2>/dev/null && check_pass "FastCGI cache: $FASTCGI_CACHE configured" || check_info "FastCGI cache: not configured"
    [ "${PROXY_CACHE:-0}" -gt 0 ] 2>/dev/null && check_pass "Proxy cache: $PROXY_CACHE configured" || check_info "Proxy cache: not configured"
    [ "${CACHE_HEADERS:-0}" -gt 0 ] 2>/dev/null && check_pass "Cache-Control headers: $CACHE_HEADERS found" || check_info "Cache-Control: not configured"

    echo -e "\n${CYAN}Virtual Hosts & Proxy:${NC}"
    check_info "Virtual hosts: $VHOSTS_COUNT configured"
    [ -n "$SITES_LIST" ] && check_info "Sites: $SITES_LIST"
    [ "${PROXY_COUNT:-0}" -gt 0 ] 2>/dev/null && check_pass "Reverse proxy: $PROXY_COUNT configs" || check_info "No proxy configs found"
    [ "${UPSTREAM_COUNT:-0}" -gt 0 ] 2>/dev/null && check_pass "Upstreams: $UPSTREAM_COUNT defined" || check_info "No upstream blocks"
    [ -n "$PROXY_BUFFER" ] && check_info "Proxy buffer: $PROXY_BUFFER | Timeout: $PROXY_TIMEOUT"

    echo -e "\n${CYAN}SSL/TLS Configuration:${NC}"
    [ -n "$SSL_PROTO" ] && [ "$SSL_PROTO" != "not_found" ] && check_pass "SSL protocols: $SSL_PROTO" || { check_warn "SSL protocols: not configured"; add_medium "Configure SSL protocols"; }
    [ "$SSL_PREFER" = "1" ] && check_pass "Server ciphers: preferred" || check_info "Server cipher preference: not set"
    [ "$HSTS_COUNT" -gt 0 ] 2>/dev/null && check_pass "HSTS: enabled ($HSTS_COUNT)" || { check_warn "HSTS: not enabled"; add_medium "Enable HSTS"; }
    [ "$CERTBOT" = "active" ] && check_pass "Certbot timer: active" || { check_warn "Certbot: $CERTBOT"; add_low "Certbot timer inactive"; }
    [ -n "$SSL_EXPIRY" ] && [ "$SSL_EXPIRY" != "not_found" ] && check_info "SSL expiry: $SSL_EXPIRY" || check_info "SSL certificate: not found"
    [ "${HTTP2_COUNT:-0}" -gt 0 ] 2>/dev/null && check_pass "HTTP/2: enabled ($HTTP2_COUNT sites)" || check_info "HTTP/2: not detected"

    echo -e "\n${CYAN}Security Headers:${NC}"
    [ "${SEC_HEADERS:-0}" -ge 3 ] 2>/dev/null && check_pass "Security headers: $SEC_HEADERS configured" || { check_warn "Security headers: ${SEC_HEADERS:-0}"; add_medium "Add security headers"; }
    [ "${XFRAME:-0}" -gt 0 ] 2>/dev/null && check_pass "X-Frame-Options: configured" || { check_warn "X-Frame-Options: missing"; add_medium "Add X-Frame-Options"; }
    [ "${XCONTENT:-0}" -gt 0 ] 2>/dev/null && check_pass "X-Content-Type-Options: configured" || check_warn "X-Content-Type-Options: missing"
    [ "${XXSS:-0}" -gt 0 ] 2>/dev/null && check_pass "X-XSS-Protection: configured" || check_warn "X-XSS-Protection: missing"
    [ "${CSP:-0}" -gt 0 ] 2>/dev/null && check_pass "Content-Security-Policy: configured" || check_info "CSP: not configured"
    [ "$SERVER_TOKENS" = "1" ] && check_pass "Server tokens: hidden" || { check_warn "Server tokens: exposed"; add_low "Hide server tokens"; }

    echo -e "\n${CYAN}Rate Limiting & Protection:${NC}"
    [ "${RATE_LIMIT:-0}" -gt 0 ] 2>/dev/null && check_pass "Rate limiting: $RATE_LIMIT zones" || { check_info "Rate limiting: not configured"; }
    [ "${CONN_LIMIT:-0}" -gt 0 ] 2>/dev/null && check_pass "Connection limiting: $CONN_LIMIT zones" || check_info "Connection limiting: not configured"

    echo -e "\n${CYAN}Listening Ports:${NC}"
    [ "${PORT_80:-0}" -gt 0 ] 2>/dev/null && check_pass "Port 80 (HTTP): listening" || check_warn "Port 80: not listening"
    [ "${PORT_443:-0}" -gt 0 ] 2>/dev/null && check_pass "Port 443 (HTTPS): listening" || { check_warn "Port 443: not listening"; add_high "HTTPS not configured"; }

    echo -e "\n${CYAN}Compiled Modules:${NC}"
    [ "${MODULES_COUNT:-0}" -gt 10 ] 2>/dev/null && check_pass "Modules: $MODULES_COUNT compiled" || check_info "Modules: $MODULES_COUNT"
    [ "$MOD_SSL" = "1" ] && check_pass "SSL module: compiled" || check_warn "SSL module: missing"
    [ "$MOD_HTTP2" = "1" ] && check_pass "HTTP/2 module: compiled" || check_info "HTTP/2 module: not compiled"
    [ "$MOD_GZIP" = "1" ] && check_pass "Gzip static module: compiled" || check_info "Gzip static module: not compiled"
    [ "$MOD_REALIP" = "1" ] && check_pass "Real IP module: compiled" || check_info "Real IP module: not compiled"

    echo -e "\n${CYAN}Logs & Monitoring:${NC}"
    check_info "Error log: $ERR_SIZE ($ERR_COUNT recent errors) | Access log: $ACC_SIZE"
    check_info "Log paths: Error=$ERROR_LOG_PATH, Access=$ACCESS_LOG_PATH"
    check_info "Recent requests: GET=$GET_REQUESTS, POST=$POST_REQUESTS (last 1000)"
    [ "${COUNT_404:-0}" -gt 500 ] 2>/dev/null && { check_warn "404 errors: $COUNT_404"; add_low "Many 404 errors"; } || check_pass "404 errors: ${COUNT_404:-0}"
    [ "${COUNT_500:-0}" -gt 10 ] 2>/dev/null && { check_warn "500 errors: $COUNT_500"; add_high "Server errors detected"; } || check_pass "500 errors: ${COUNT_500:-0}"
    [ "${COUNT_502:-0}" -gt 10 ] 2>/dev/null && { check_warn "502 errors: $COUNT_502"; add_high "Bad gateway errors"; } || check_pass "502 errors: ${COUNT_502:-0}"
    [ "${COUNT_503:-0}" -gt 10 ] 2>/dev/null && { check_warn "503 errors: $COUNT_503"; add_high "Service unavailable"; } || check_pass "503 errors: ${COUNT_503:-0}"
    [ "${TIMEOUT_ERRORS:-0}" -gt 5 ] 2>/dev/null && { check_warn "Timeout errors: $TIMEOUT_ERRORS"; add_medium "Investigate timeouts"; } || check_pass "Timeout errors: ${TIMEOUT_ERRORS:-0}"
    [ "${REFUSED_ERRORS:-0}" -gt 5 ] 2>/dev/null && { check_warn "Connection refused: $REFUSED_ERRORS"; add_medium "Check upstream health"; } || check_pass "Connection refused: ${REFUSED_ERRORS:-0}"
    [ "${ACCESS_LOG_OFF:-0}" -gt 0 ] 2>/dev/null && check_info "Access logging disabled: $ACCESS_LOG_OFF locations"

    echo -e "\n${CYAN}Files & Permissions:${NC}"
    check_info "Config files: $CONF_FILES | Size: $CONF_SIZE"
    check_info "Log files: $LOG_FILES | Disk usage: $LOG_DISK_USAGE"
    check_info "Permissions: Config=$CONF_PERMS, Logs=$LOG_PERMS"
fi

section "61-70. STAGING NGINX [MEGA BATCH]"
if [ "$STAGING_CONN" = true ]; then
    # ═══════════════════════════════════════════════════════════════════════════════
    # MEGA BATCH 2: STAGING NGINX - 30 COMMANDS
    # ═══════════════════════════════════════════════════════════════════════════════
    MEGA2=$(ssh_staging "
systemctl is-active nginx
nginx -v 2>&1 | grep -oP '\\d+\\.\\d+\\.\\d+' || echo unknown
sudo nginx -t 2>&1 | tail -1
ls /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep 'worker_processes' /etc/nginx/nginx.conf 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo auto
grep -r 'ssl_protocols' /etc/nginx/ 2>/dev/null | head -1 | awk '{for(i=2;i<=NF;i++) printf \$i\" \";}' || echo not_found
grep -r 'http2' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -rE 'X-Frame-Options|X-Content-Type|X-XSS' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -c ' 404 ' /var/log/nginx/access.log 2>/dev/null || echo 0
grep -c ' 500 ' /var/log/nginx/access.log 2>/dev/null || echo 0
du -sh /var/log/nginx/error.log 2>/dev/null | cut -f1 || echo 0
du -sh /var/log/nginx/access.log 2>/dev/null | cut -f1 || echo 0
ps aux | grep 'nginx: worker' | grep -v grep | wc -l
ps aux | grep nginx | grep -v grep | awk '{sum+=\$3} END {printf \"%.1f\", sum}' || echo 0
netstat -an | grep -c ':443.*LISTEN' 2>/dev/null || ss -tlnp 2>/dev/null | grep -c ':443'
grep -r 'add_header Strict-Transport-Security' /etc/nginx/ 2>/dev/null | wc -l
grep -r 'upstream' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
grep -r 'proxy_pass' /etc/nginx/sites-enabled/ 2>/dev/null | wc -l
systemctl is-active certbot.timer 2>/dev/null || echo inactive
ls /etc/nginx/sites-enabled/ 2>/dev/null | head -3 | tr '\\n' ',' || echo none
grep -r 'gzip on' /etc/nginx/ 2>/dev/null | wc -l
grep 'worker_connections' /etc/nginx/nginx.conf 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo 512
systemctl show nginx --property=MemoryCurrent --value 2>/dev/null | awk '{printf \"%.1fM\", \$1/1024/1024}' || echo 0
find /etc/nginx -name '*.conf' -type f 2>/dev/null | wc -l
tail -100 /var/log/nginx/error.log 2>/dev/null | grep -i error | wc -l || echo 0
nginx -V 2>&1 | grep -c 'http_ssl_module' || echo 0
nginx -V 2>&1 | grep -c 'http_v2_module' || echo 0
grep -r 'server_tokens' /etc/nginx/ 2>/dev/null | grep -c 'off' || echo 0
grep -r 'limit_req_zone' /etc/nginx/ 2>/dev/null | wc -l
grep -r 'client_max_body_size' /etc/nginx/ 2>/dev/null | head -1 | awk '{print \$2}' | tr -d ';' || echo 1m
" 60 | tr -d '\r')

    IFS=$'\n' read -d '' -r -a L2 <<< "$MEGA2"

    STG_STATUS="${L2[0]}"
    STG_VER="${L2[1]}"
    STG_CONFIG="${L2[2]}"
    STG_VHOSTS="${L2[3]}"
    STG_WORKERS="${L2[4]}"
    STG_SSL_PROTO="${L2[5]}"
    STG_HTTP2="${L2[6]}"
    STG_SEC_HEADERS="${L2[7]}"
    STG_404="${L2[8]}"
    STG_500="${L2[9]}"
    STG_ERR_SIZE="${L2[10]}"
    STG_ACC_SIZE="${L2[11]}"
    STG_WORKER_PROCS="${L2[12]}"
    STG_CPU="${L2[13]}"
    STG_PORT_443="${L2[14]}"
    STG_HSTS="${L2[15]}"
    STG_UPSTREAM="${L2[16]}"
    STG_PROXY="${L2[17]}"
    STG_CERTBOT="${L2[18]}"
    STG_SITES="${L2[19]}"
    STG_GZIP="${L2[20]}"
    STG_WORKER_CONN="${L2[21]}"
    STG_MEM="${L2[22]}"
    STG_CONF_FILES="${L2[23]}"
    STG_ERR_COUNT="${L2[24]}"
    STG_MOD_SSL="${L2[25]}"
    STG_MOD_HTTP2="${L2[26]}"
    STG_SERVER_TOKENS="${L2[27]}"
    STG_RATE_LIMIT="${L2[28]}"
    STG_MAX_BODY="${L2[29]}"

    echo -e "${CYAN}Staging Service:${NC}"
    [ "$STG_STATUS" = "active" ] && check_pass "Nginx: active (v$STG_VER)" || check_warn "Nginx: $STG_STATUS"
    echo "$STG_CONFIG" | grep -qi "successful" && check_pass "Config test: passed" || check_warn "Config test: failed"
    check_info "Workers: $STG_WORKERS ($STG_WORKER_PROCS active) | Connections: $STG_WORKER_CONN"
    check_info "CPU: ${STG_CPU}% | Memory: $STG_MEM"

    echo -e "\n${CYAN}Staging Configuration:${NC}"
    check_info "Virtual hosts: $STG_VHOSTS | Sites: $STG_SITES"
    [ "${STG_GZIP:-0}" -gt 0 ] 2>/dev/null && check_pass "Gzip: enabled" || check_warn "Gzip: disabled"
    [ "${STG_HTTP2:-0}" -gt 0 ] 2>/dev/null && check_pass "HTTP/2: enabled ($STG_HTTP2)" || check_info "HTTP/2: not enabled"
    [ "${STG_PORT_443:-0}" -gt 0 ] 2>/dev/null && check_pass "HTTPS: listening" || check_warn "HTTPS: not configured"

    echo -e "\n${CYAN}Staging Security:${NC}"
    [ -n "$STG_SSL_PROTO" ] && [ "$STG_SSL_PROTO" != "not_found" ] && check_pass "SSL: $STG_SSL_PROTO" || check_warn "SSL: not configured"
    [ "${STG_SEC_HEADERS:-0}" -ge 2 ] 2>/dev/null && check_pass "Security headers: $STG_SEC_HEADERS" || check_warn "Security headers: ${STG_SEC_HEADERS:-0}"
    [ "${STG_HSTS:-0}" -gt 0 ] 2>/dev/null && check_pass "HSTS: enabled" || check_warn "HSTS: not enabled"
    [ "$STG_CERTBOT" = "active" ] && check_pass "Certbot: active" || check_warn "Certbot: $STG_CERTBOT"
    [ "$STG_SERVER_TOKENS" = "1" ] && check_pass "Server tokens: hidden" || check_warn "Server tokens: exposed"

    echo -e "\n${CYAN}Staging Performance:${NC}"
    [ "${STG_UPSTREAM:-0}" -gt 0 ] 2>/dev/null && check_pass "Upstreams: $STG_UPSTREAM" || check_info "No upstreams"
    [ "${STG_PROXY:-0}" -gt 0 ] 2>/dev/null && check_pass "Proxy configs: $STG_PROXY" || check_info "No proxies"
    [ "${STG_RATE_LIMIT:-0}" -gt 0 ] 2>/dev/null && check_pass "Rate limiting: $STG_RATE_LIMIT zones" || check_info "No rate limiting"
    check_info "Max body size: $STG_MAX_BODY | Config files: $STG_CONF_FILES"

    echo -e "\n${CYAN}Staging Logs:${NC}"
    check_info "Error log: $STG_ERR_SIZE ($STG_ERR_COUNT errors) | Access: $STG_ACC_SIZE"
    [ "${STG_404:-0}" -gt 500 ] 2>/dev/null && check_warn "404 errors: $STG_404" || check_pass "404 errors: ${STG_404:-0}"
    [ "${STG_500:-0}" -gt 10 ] 2>/dev/null && check_warn "500 errors: $STG_500" || check_pass "500 errors: ${STG_500:-0}"

    echo -e "\n${CYAN}Staging Modules:${NC}"
    [ "$STG_MOD_SSL" = "1" ] && check_pass "SSL module: compiled" || check_warn "SSL module: missing"
    [ "$STG_MOD_HTTP2" = "1" ] && check_pass "HTTP/2 module: compiled" || check_info "HTTP/2 module: not compiled"
fi

section "71. PRODUCTION vs STAGING COMPARISON"
if [[ "$PROD_CONN" = true && "$STAGING_CONN" = true ]]; then
    echo -e "  ${BOLD}Metric                  Production         Staging${NC}"
    echo -e "  ──────────────────────────────────────────────────────────"
    printf "  %-22s %-18s %s\n" "Status" "${NGINX_STATUS:-?}" "${STG_STATUS:-?}"
    printf "  %-22s %-18s %s\n" "Version" "${NGINX_VER:-?}" "${STG_VER:-?}"
    printf "  %-22s %-18s %s\n" "Vhosts" "${VHOSTS_COUNT:-?}" "${STG_VHOSTS:-?}"
    printf "  %-22s %-18s %s\n" "Workers" "${WORKER_PROCS:-?}" "${STG_WORKER_PROCS:-?}"
    printf "  %-22s %-18s %s\n" "SSL/TLS" "${SSL_PROTO:-?}" "${STG_SSL_PROTO:-?}"
    printf "  %-22s %-18s %s\n" "HTTP/2" "${HTTP2_COUNT:-?}" "${STG_HTTP2:-?}"
    printf "  %-22s %-18s %s\n" "Security Headers" "${SEC_HEADERS:-?}" "${STG_SEC_HEADERS:-?}"
    printf "  %-22s %-18s %s\n" "CPU Usage" "${NGINX_CPU:-?}%" "${STG_CPU:-?}%"
    printf "  %-22s %-18s %s\n" "Memory" "${MEM_USAGE:-?}" "${STG_MEM:-?}"
fi

section "🔴 THINGS TO FIX"
if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
    echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              🔴 THINGS TO FIX - NGINX                         ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}🟠 HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
    for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}🔵 LOW: $issue${NC}"; done
else
    echo -e "  ${GREEN}✓ No issues found! Nginx is healthy.${NC}"
fi

section "FINAL SUMMARY"
DUR=$(($(date +%s) - SCRIPT_START))
[[ $SCORE -lt 0 ]] && SCORE=0

if [[ $SCORE -ge 90 ]]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [[ $SCORE -ge 75 ]]; then RATING="GOOD"; COLOR="$GREEN"
elif [[ $SCORE -ge 60 ]]; then RATING="FAIR"; COLOR="$YELLOW"
else RATING="NEEDS WORK"; COLOR="$YELLOW"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  NGINX_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds  ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "NGINX_SCORE:$SCORE"
