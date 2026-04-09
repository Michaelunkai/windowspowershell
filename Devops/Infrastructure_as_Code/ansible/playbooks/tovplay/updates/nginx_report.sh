#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# NGINX AUDIT v7.0 [MARKER-BASED] - Reliable Parsing Edition
# Fixed array index misalignment with marker-based extraction
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

# ═══════════════════════════════════════════════════════════════════════════════
# MARKER-BASED VALUE EXTRACTION - RELIABLE PARSING
# ═══════════════════════════════════════════════════════════════════════════════
extract_value() {
    local data="$1"
    local marker="$2"
    echo "$data" | grep "^${marker}:" | head -1 | cut -d: -f2-
}

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     🌐 NGINX AUDIT v7.0 [MARKER-BASED] - $(date '+%Y-%m-%d %H:%M:%S')          ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 15)
STAGING_OK=$(ssh_staging "echo OK" 15)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { STAGING_CONN=false; }

section "2-60. COMPREHENSIVE NGINX AUDIT [MARKER-BASED PARSING]"
if [ "$PROD_CONN" = true ]; then
    # ═══════════════════════════════════════════════════════════════════════════════
    # MEGA BATCH 1: PRODUCTION NGINX - MARKER-BASED OUTPUT
    # ═══════════════════════════════════════════════════════════════════════════════
    MEGA1=$(ssh_prod '
echo "NGINX_STATUS:$(systemctl is-active nginx)"
echo "NGINX_VER:$(nginx -v 2>&1 | grep -oP "\d+\.\d+\.\d+" || echo unknown)"
echo "CONFIG_TEST:$(sudo nginx -t 2>&1 | tail -1)"
echo "WORKER_PROC:$(grep "worker_processes" /etc/nginx/nginx.conf 2>/dev/null | head -1 | sed "s/.*worker_processes[[:space:]]*//;s/;.*//" | grep . || echo auto)"
echo "WORKER_CONN:$(grep "worker_connections" /etc/nginx/nginx.conf 2>/dev/null | head -1 | sed "s/.*worker_connections[[:space:]]*//;s/;.*//" | grep . || echo 512)"
echo "GZIP_CONF:$(grep -r "gzip on" /etc/nginx/ 2>/dev/null | head -1 | cut -d: -f1 || echo not_found)"
echo "SSL_PROTO:$(grep -r "ssl_protocols" /etc/nginx/ 2>/dev/null | head -1 | sed "s/^[^:]*:[[:space:]]*ssl_protocols[[:space:]]*//;s/;.*//" | grep . || echo not_found)"
echo "VHOSTS_COUNT:$(ls /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "SITES_LIST:$(ls /etc/nginx/sites-enabled/ 2>/dev/null | head -5 | tr "\n" "," || echo none)"
echo "HTTP2_COUNT:$(grep -r "http2" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "SEC_HEADERS:$(grep -rE "X-Frame-Options|X-Content-Type|X-XSS" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "CACHE_HEADERS:$(grep -r "add_header.*Cache-Control" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "ERR_SIZE:$(du -sh /var/log/nginx/error.log 2>/dev/null | cut -f1 || echo 0)"
echo "ACC_SIZE:$(du -sh /var/log/nginx/access.log 2>/dev/null | cut -f1 || echo 0)"
echo "ERR_COUNT:$(sudo tail -10 /var/log/nginx/error.log 2>/dev/null | grep -i error | wc -l)"
echo "COUNT_404:$(sudo tail -300 /var/log/nginx/access.log 2>/dev/null | grep " 404 " | wc -l)"
echo "COUNT_500:$(sudo tail -300 /var/log/nginx/access.log 2>/dev/null | grep " 500 " | wc -l)"
echo "COUNT_502:$(sudo tail -300 /var/log/nginx/access.log 2>/dev/null | grep " 502 " | grep -v "/logs/" | wc -l)"
echo "COUNT_503:$(sudo tail -300 /var/log/nginx/access.log 2>/dev/null | grep " 503 " | wc -l)"
echo "CERTBOT:$(systemctl is-active certbot.timer 2>/dev/null || echo inactive)"
echo "SSL_CERT_PATH:$(grep "ssl_certificate" /etc/nginx/sites-enabled/* 2>/dev/null | head -1 | sed "s/^.*ssl_certificate[[:space:]]*//;s/;.*//" | grep . || echo not_found)"
echo "SSL_EXPIRY:$(openssl x509 -in /etc/letsencrypt/live/*/cert.pem -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2 | head -1 || echo not_found)"
echo "SSL_CIPHERS:$(grep "ssl_ciphers" /etc/nginx/nginx.conf /etc/nginx/sites-enabled/* 2>/dev/null | head -1 | sed "s/^[^:]*:[[:space:]]*ssl_ciphers[[:space:]]*//;s/;.*//" | grep . || echo not_configured)"
echo "SSL_PREFER:$(grep -r "ssl_prefer_server_ciphers" /etc/nginx/ 2>/dev/null | grep "on" | wc -l)"
echo "HSTS_COUNT:$(grep -r "add_header Strict-Transport-Security" /etc/nginx/ 2>/dev/null | wc -l)"
echo "MAX_BODY_SIZE:$(grep -r "client_max_body_size" /etc/nginx/ 2>/dev/null | head -1 | sed "s/^.*client_max_body_size[[:space:]]*//;s/;.*//" | grep . || echo 1m)"
echo "BODY_BUFFER:$(grep -r "client_body_buffer_size" /etc/nginx/ 2>/dev/null | head -1 | sed "s/^.*client_body_buffer_size[[:space:]]*//;s/;.*//" | grep . || echo 128k)"
echo "HEADER_BUFFER:$(grep -r "client_header_buffer_size" /etc/nginx/ 2>/dev/null | head -1 | sed "s/^.*client_header_buffer_size[[:space:]]*//;s/;.*//" | grep . || echo 1k)"
echo "KEEPALIVE:$(grep -r "keepalive_timeout" /etc/nginx/ 2>/dev/null | head -1 | sed "s/^.*keepalive_timeout[[:space:]]*//;s/;.*//" | grep . || echo 65)"
echo "PROXY_COUNT:$(grep -r "proxy_pass" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "PROXY_BUFFER:$(grep -r "proxy_buffer_size" /etc/nginx/ 2>/dev/null | head -1 | sed "s/^.*proxy_buffer_size[[:space:]]*//;s/;.*//" | grep . || echo 4k)"
echo "PROXY_TIMEOUT:$(grep -r "proxy_connect_timeout" /etc/nginx/ 2>/dev/null | head -1 | sed "s/^.*proxy_connect_timeout[[:space:]]*//;s/;.*//" | grep . || echo 60s)"
echo "RATE_LIMIT:$(grep -r "limit_req_zone" /etc/nginx/ 2>/dev/null | wc -l)"
echo "CONN_LIMIT:$(grep -r "limit_conn_zone" /etc/nginx/ 2>/dev/null | wc -l)"
echo "UPSTREAM_COUNT:$(grep -r "upstream" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "FASTCGI_CACHE:$(grep -r "fastcgi_cache" /etc/nginx/ 2>/dev/null | wc -l)"
echo "PROXY_CACHE:$(grep -r "proxy_cache" /etc/nginx/ 2>/dev/null | wc -l)"
echo "ACCESS_LOG_OFF:$(grep -r "access_log.*off" /etc/nginx/ 2>/dev/null | wc -l)"
echo "WORKER_PROCS:$(ps aux | grep "nginx: worker" | grep -v grep | wc -l)"
echo "NGINX_CPU:$(ps aux | grep nginx | grep -v grep | tr -s " " | cut -d" " -f3 | paste -sd+ | bc 2>/dev/null || echo 0)"
echo "NGINX_MEM:$(ps aux | grep nginx | grep -v grep | tr -s " " | cut -d" " -f4 | paste -sd+ | bc 2>/dev/null || echo 0)"
echo "PORT_80:$(netstat -an 2>/dev/null | grep ":80.*LISTEN" | wc -l)"
echo "PORT_443:$(netstat -an 2>/dev/null | grep ":443.*LISTEN" | wc -l)"
echo "MODULES_COUNT:$(nginx -V 2>&1 | grep -o -- "--with-[^[:space:]]*" | wc -l)"
echo "MOD_SSL:$(nginx -V 2>&1 | grep "http_ssl_module" | wc -l)"
echo "MOD_HTTP2:$(nginx -V 2>&1 | grep "http_v2_module" | wc -l)"
echo "MOD_GZIP:$(nginx -V 2>&1 | grep "http_gzip_static_module" | wc -l)"
echo "MOD_REALIP:$(nginx -V 2>&1 | grep "http_realip_module" | wc -l)"
echo "SERVER_TOKENS:$(grep -r "server_tokens" /etc/nginx/ 2>/dev/null | grep "off" | wc -l)"
echo "XFRAME:$(grep -r "add_header X-Frame-Options" /etc/nginx/ 2>/dev/null | wc -l)"
echo "XCONTENT:$(grep -r "add_header X-Content-Type-Options" /etc/nginx/ 2>/dev/null | wc -l)"
echo "XXSS:$(grep -r "add_header X-XSS-Protection" /etc/nginx/ 2>/dev/null | wc -l)"
echo "CSP:$(grep -r "add_header Content-Security-Policy" /etc/nginx/ 2>/dev/null | wc -l)"
echo "CONF_FILES:$(find /etc/nginx -name "*.conf" -type f 2>/dev/null | wc -l)"
echo "LOG_FILES:$(find /var/log/nginx -name "*.log" -type f 2>/dev/null | wc -l)"
echo "GET_REQUESTS:$(sudo tail -1000 /var/log/nginx/access.log 2>/dev/null | grep "GET" | wc -l)"
echo "POST_REQUESTS:$(sudo tail -1000 /var/log/nginx/access.log 2>/dev/null | grep "POST" | wc -l)"
echo "TIMEOUT_ERRORS:$(sudo tail -100 /var/log/nginx/error.log 2>/dev/null | grep -i "timeout" | wc -l)"
echo "REFUSED_ERRORS:$(sudo tail -100 /var/log/nginx/error.log 2>/dev/null | grep -i "refused" | wc -l)"
echo "START_TIME:$(systemctl show nginx --property=ActiveEnterTimestamp --value 2>/dev/null | cut -d" " -f1-2 || echo unknown)"
echo "MEM_USAGE:$(systemctl show nginx --property=MemoryCurrent --value 2>/dev/null | numfmt --to=iec 2>/dev/null || echo 0)"
echo "SERVICE_STATUS:$(systemctl status nginx 2>/dev/null | grep "active (running)" | wc -l)"
echo "ERROR_LOG_PATH:$(grep -r "error_log" /etc/nginx/nginx.conf 2>/dev/null | head -1 | sed "s/^.*error_log[[:space:]]*//;s/[[:space:]].*//;s/;.*//" | grep . || echo /var/log/nginx/error.log)"
echo "ACCESS_LOG_PATH:$(grep -r "access_log" /etc/nginx/nginx.conf 2>/dev/null | head -1 | sed "s/^.*access_log[[:space:]]*//;s/[[:space:]].*//;s/;.*//" | grep . || echo /var/log/nginx/access.log)"
echo "LOG_DISK_USAGE:$(df -h /var/log/nginx 2>/dev/null | tail -1 | tr -s " " | cut -d" " -f5 || echo 0%)"
echo "CONF_SIZE:$(du -sh /etc/nginx 2>/dev/null | cut -f1 || echo 0)"
echo "CONF_PERMS:$(ls -ld /etc/nginx 2>/dev/null | cut -d" " -f1 || echo unknown)"
echo "LOG_PERMS:$(ls -ld /var/log/nginx 2>/dev/null | cut -d" " -f1 || echo unknown)"
' 60 | tr -d '\r')

    # ═══════════════════════════════════════════════════════════════════════════════
    # EXTRACT ALL VALUES USING MARKER-BASED PARSING (RELIABLE!)
    # ═══════════════════════════════════════════════════════════════════════════════
    NGINX_STATUS=$(extract_value "$MEGA1" "NGINX_STATUS")
    NGINX_VER=$(extract_value "$MEGA1" "NGINX_VER")
    CONFIG_TEST=$(extract_value "$MEGA1" "CONFIG_TEST")
    WORKER_PROC=$(extract_value "$MEGA1" "WORKER_PROC")
    WORKER_CONN=$(extract_value "$MEGA1" "WORKER_CONN")
    GZIP_CONF=$(extract_value "$MEGA1" "GZIP_CONF")
    SSL_PROTO=$(extract_value "$MEGA1" "SSL_PROTO")
    VHOSTS_COUNT=$(extract_value "$MEGA1" "VHOSTS_COUNT")
    SITES_LIST=$(extract_value "$MEGA1" "SITES_LIST")
    HTTP2_COUNT=$(extract_value "$MEGA1" "HTTP2_COUNT")
    SEC_HEADERS=$(extract_value "$MEGA1" "SEC_HEADERS")
    CACHE_HEADERS=$(extract_value "$MEGA1" "CACHE_HEADERS")
    ERR_SIZE=$(extract_value "$MEGA1" "ERR_SIZE")
    ACC_SIZE=$(extract_value "$MEGA1" "ACC_SIZE")
    ERR_COUNT=$(extract_value "$MEGA1" "ERR_COUNT")
    COUNT_404=$(extract_value "$MEGA1" "COUNT_404")
    COUNT_500=$(extract_value "$MEGA1" "COUNT_500")
    COUNT_502=$(extract_value "$MEGA1" "COUNT_502")
    COUNT_503=$(extract_value "$MEGA1" "COUNT_503")
    CERTBOT=$(extract_value "$MEGA1" "CERTBOT")
    SSL_CERT_PATH=$(extract_value "$MEGA1" "SSL_CERT_PATH")
    SSL_EXPIRY=$(extract_value "$MEGA1" "SSL_EXPIRY")
    SSL_CIPHERS=$(extract_value "$MEGA1" "SSL_CIPHERS")
    SSL_PREFER=$(extract_value "$MEGA1" "SSL_PREFER")
    HSTS_COUNT=$(extract_value "$MEGA1" "HSTS_COUNT")
    MAX_BODY_SIZE=$(extract_value "$MEGA1" "MAX_BODY_SIZE")
    BODY_BUFFER=$(extract_value "$MEGA1" "BODY_BUFFER")
    HEADER_BUFFER=$(extract_value "$MEGA1" "HEADER_BUFFER")
    KEEPALIVE=$(extract_value "$MEGA1" "KEEPALIVE")
    PROXY_COUNT=$(extract_value "$MEGA1" "PROXY_COUNT")
    PROXY_BUFFER=$(extract_value "$MEGA1" "PROXY_BUFFER")
    PROXY_TIMEOUT=$(extract_value "$MEGA1" "PROXY_TIMEOUT")
    RATE_LIMIT=$(extract_value "$MEGA1" "RATE_LIMIT")
    CONN_LIMIT=$(extract_value "$MEGA1" "CONN_LIMIT")
    UPSTREAM_COUNT=$(extract_value "$MEGA1" "UPSTREAM_COUNT")
    FASTCGI_CACHE=$(extract_value "$MEGA1" "FASTCGI_CACHE")
    PROXY_CACHE=$(extract_value "$MEGA1" "PROXY_CACHE")
    ACCESS_LOG_OFF=$(extract_value "$MEGA1" "ACCESS_LOG_OFF")
    WORKER_PROCS=$(extract_value "$MEGA1" "WORKER_PROCS")
    NGINX_CPU=$(extract_value "$MEGA1" "NGINX_CPU")
    NGINX_MEM=$(extract_value "$MEGA1" "NGINX_MEM")
    PORT_80=$(extract_value "$MEGA1" "PORT_80")
    PORT_443=$(extract_value "$MEGA1" "PORT_443")
    MODULES_COUNT=$(extract_value "$MEGA1" "MODULES_COUNT")
    MOD_SSL=$(extract_value "$MEGA1" "MOD_SSL")
    MOD_HTTP2=$(extract_value "$MEGA1" "MOD_HTTP2")
    MOD_GZIP=$(extract_value "$MEGA1" "MOD_GZIP")
    MOD_REALIP=$(extract_value "$MEGA1" "MOD_REALIP")
    SERVER_TOKENS=$(extract_value "$MEGA1" "SERVER_TOKENS")
    XFRAME=$(extract_value "$MEGA1" "XFRAME")
    XCONTENT=$(extract_value "$MEGA1" "XCONTENT")
    XXSS=$(extract_value "$MEGA1" "XXSS")
    CSP=$(extract_value "$MEGA1" "CSP")
    CONF_FILES=$(extract_value "$MEGA1" "CONF_FILES")
    LOG_FILES=$(extract_value "$MEGA1" "LOG_FILES")
    GET_REQUESTS=$(extract_value "$MEGA1" "GET_REQUESTS")
    POST_REQUESTS=$(extract_value "$MEGA1" "POST_REQUESTS")
    TIMEOUT_ERRORS=$(extract_value "$MEGA1" "TIMEOUT_ERRORS")
    REFUSED_ERRORS=$(extract_value "$MEGA1" "REFUSED_ERRORS")
    START_TIME=$(extract_value "$MEGA1" "START_TIME")
    MEM_USAGE=$(extract_value "$MEGA1" "MEM_USAGE")
    SERVICE_STATUS=$(extract_value "$MEGA1" "SERVICE_STATUS")
    ERROR_LOG_PATH=$(extract_value "$MEGA1" "ERROR_LOG_PATH")
    ACCESS_LOG_PATH=$(extract_value "$MEGA1" "ACCESS_LOG_PATH")
    LOG_DISK_USAGE=$(extract_value "$MEGA1" "LOG_DISK_USAGE")
    CONF_SIZE=$(extract_value "$MEGA1" "CONF_SIZE")
    CONF_PERMS=$(extract_value "$MEGA1" "CONF_PERMS")
    LOG_PERMS=$(extract_value "$MEGA1" "LOG_PERMS")

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
    [ "${REFUSED_ERRORS:-0}" -gt 15 ] 2>/dev/null && { check_warn "Connection refused: $REFUSED_ERRORS"; add_medium "Check upstream health"; } || check_pass "Connection refused: ${REFUSED_ERRORS:-0}"
    [ "${ACCESS_LOG_OFF:-0}" -gt 0 ] 2>/dev/null && check_info "Access logging disabled: $ACCESS_LOG_OFF locations"

    echo -e "\n${CYAN}Files & Permissions:${NC}"
    check_info "Config files: $CONF_FILES | Size: $CONF_SIZE"
    check_info "Log files: $LOG_FILES | Disk usage: $LOG_DISK_USAGE"
    check_info "Permissions: Config=$CONF_PERMS, Logs=$LOG_PERMS"
fi

section "61-70. STAGING NGINX [MARKER-BASED PARSING]"
if [ "$STAGING_CONN" = true ]; then
    # ═══════════════════════════════════════════════════════════════════════════════
    # MEGA BATCH 2: STAGING NGINX - MARKER-BASED OUTPUT
    # ═══════════════════════════════════════════════════════════════════════════════
    MEGA2=$(ssh_staging '
echo "STG_STATUS:$(systemctl is-active nginx)"
echo "STG_VER:$(nginx -v 2>&1 | grep -oP "\d+\.\d+\.\d+" || echo unknown)"
echo "STG_CONFIG:$(sudo nginx -t 2>&1 | tail -1)"
echo "STG_VHOSTS:$(ls /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "STG_WORKERS:$(grep "worker_processes" /etc/nginx/nginx.conf 2>/dev/null | head -1 | sed "s/.*worker_processes[[:space:]]*//;s/;.*//" | grep . || echo auto)"
echo "STG_SSL_PROTO:$(grep -r "ssl_protocols" /etc/nginx/ 2>/dev/null | head -1 | sed "s/^[^:]*:[[:space:]]*ssl_protocols[[:space:]]*//;s/;.*//" | grep . || echo not_found)"
echo "STG_HTTP2:$(grep -r "http2" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "STG_SEC_HEADERS:$(grep -rE "X-Frame-Options|X-Content-Type|X-XSS" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "STG_404:$(sudo cat /var/log/nginx/access.log 2>/dev/null | grep " 404 " | wc -l)"
echo "STG_500:$(sudo cat /var/log/nginx/access.log 2>/dev/null | grep " 500 " | wc -l)"
echo "STG_ERR_SIZE:$(du -sh /var/log/nginx/error.log 2>/dev/null | cut -f1 || echo 0)"
echo "STG_ACC_SIZE:$(du -sh /var/log/nginx/access.log 2>/dev/null | cut -f1 || echo 0)"
echo "STG_WORKER_PROCS:$(ps aux | grep "nginx: worker" | grep -v grep | wc -l)"
echo "STG_CPU:$(ps aux | grep nginx | grep -v grep | tr -s " " | cut -d" " -f3 | paste -sd+ | bc 2>/dev/null || echo 0)"
echo "STG_PORT_443:$(netstat -an 2>/dev/null | grep -c ":443.*LISTEN" || echo 0)"
echo "STG_HSTS:$(grep -r "add_header Strict-Transport-Security" /etc/nginx/ 2>/dev/null | wc -l)"
echo "STG_UPSTREAM:$(grep -r "upstream" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "STG_PROXY:$(grep -r "proxy_pass" /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)"
echo "STG_CERTBOT:$(systemctl is-active certbot.timer 2>/dev/null || echo inactive)"
echo "STG_SITES:$(ls /etc/nginx/sites-enabled/ 2>/dev/null | head -3 | tr "\n" "," || echo none)"
echo "STG_GZIP:$(grep -r "gzip on" /etc/nginx/ 2>/dev/null | wc -l)"
echo "STG_WORKER_CONN:$(grep "worker_connections" /etc/nginx/nginx.conf 2>/dev/null | head -1 | sed "s/.*worker_connections[[:space:]]*//;s/;.*//" | grep . || echo 512)"
echo "STG_MEM:$(systemctl show nginx --property=MemoryCurrent --value 2>/dev/null | numfmt --to=iec 2>/dev/null || echo 0)"
echo "STG_CONF_FILES:$(find /etc/nginx -name "*.conf" -type f 2>/dev/null | wc -l)"
echo "STG_ERR_COUNT:$(sudo tail -100 /var/log/nginx/error.log 2>/dev/null | grep -i error | wc -l)"
echo "STG_MOD_SSL:$(nginx -V 2>&1 | grep -c "http_ssl_module" || echo 0)"
echo "STG_MOD_HTTP2:$(nginx -V 2>&1 | grep -c "http_v2_module" || echo 0)"
echo "STG_SERVER_TOKENS:$(grep -r "server_tokens" /etc/nginx/ 2>/dev/null | grep -c "off" || echo 0)"
echo "STG_RATE_LIMIT:$(grep -r "limit_req_zone" /etc/nginx/ 2>/dev/null | wc -l)"
echo "STG_MAX_BODY:$(grep -r "client_max_body_size" /etc/nginx/ 2>/dev/null | head -1 | sed "s/^.*client_max_body_size[[:space:]]*//;s/;.*//" | grep . || echo 1m)"
' 60 | tr -d '\r')

    # ═══════════════════════════════════════════════════════════════════════════════
    # EXTRACT STAGING VALUES USING MARKER-BASED PARSING
    # ═══════════════════════════════════════════════════════════════════════════════
    STG_STATUS=$(extract_value "$MEGA2" "STG_STATUS")
    STG_VER=$(extract_value "$MEGA2" "STG_VER")
    STG_CONFIG=$(extract_value "$MEGA2" "STG_CONFIG")
    STG_VHOSTS=$(extract_value "$MEGA2" "STG_VHOSTS")
    STG_WORKERS=$(extract_value "$MEGA2" "STG_WORKERS")
    STG_SSL_PROTO=$(extract_value "$MEGA2" "STG_SSL_PROTO")
    STG_HTTP2=$(extract_value "$MEGA2" "STG_HTTP2")
    STG_SEC_HEADERS=$(extract_value "$MEGA2" "STG_SEC_HEADERS")
    STG_404=$(extract_value "$MEGA2" "STG_404")
    STG_500=$(extract_value "$MEGA2" "STG_500")
    STG_ERR_SIZE=$(extract_value "$MEGA2" "STG_ERR_SIZE")
    STG_ACC_SIZE=$(extract_value "$MEGA2" "STG_ACC_SIZE")
    STG_WORKER_PROCS=$(extract_value "$MEGA2" "STG_WORKER_PROCS")
    STG_CPU=$(extract_value "$MEGA2" "STG_CPU")
    STG_PORT_443=$(extract_value "$MEGA2" "STG_PORT_443")
    STG_HSTS=$(extract_value "$MEGA2" "STG_HSTS")
    STG_UPSTREAM=$(extract_value "$MEGA2" "STG_UPSTREAM")
    STG_PROXY=$(extract_value "$MEGA2" "STG_PROXY")
    STG_CERTBOT=$(extract_value "$MEGA2" "STG_CERTBOT")
    STG_SITES=$(extract_value "$MEGA2" "STG_SITES")
    STG_GZIP=$(extract_value "$MEGA2" "STG_GZIP")
    STG_WORKER_CONN=$(extract_value "$MEGA2" "STG_WORKER_CONN")
    STG_MEM=$(extract_value "$MEGA2" "STG_MEM")
    STG_CONF_FILES=$(extract_value "$MEGA2" "STG_CONF_FILES")
    STG_ERR_COUNT=$(extract_value "$MEGA2" "STG_ERR_COUNT")
    STG_MOD_SSL=$(extract_value "$MEGA2" "STG_MOD_SSL")
    STG_MOD_HTTP2=$(extract_value "$MEGA2" "STG_MOD_HTTP2")
    STG_SERVER_TOKENS=$(extract_value "$MEGA2" "STG_SERVER_TOKENS")
    STG_RATE_LIMIT=$(extract_value "$MEGA2" "STG_RATE_LIMIT")
    STG_MAX_BODY=$(extract_value "$MEGA2" "STG_MAX_BODY")

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

section "THINGS TO FIX"
if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
    echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              THINGS TO FIX - NGINX                            ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}MEDIUM: $issue${NC}"; done
    for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}LOW: $issue${NC}"; done
else
    echo -e "  ${GREEN}No issues found! Nginx is healthy.${NC}"
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
