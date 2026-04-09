#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# PRODUCTION AUDIT v5.1 [3X SPEED OPTIMIZED] - SSH Batching Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
SCORE=100

SSH_CTRL="/tmp/tovplay_prod_$$"
mkdir -p "$SSH_CTRL"
cleanup() { ssh -S "$SSH_CTRL/prod" -O exit $PROD_USER@$PROD_HOST 2>/dev/null; rm -rf "$SSH_CTRL"; }
trap cleanup EXIT

init_connections() {
    sshpass -p "$PROD_PASS" ssh -fNM -S "$SSH_CTRL/prod" -o ControlPersist=90 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
        $PROD_USER@$PROD_HOST 2>/dev/null
}

ssh_prod() { timeout ${2:-5}s ssh -S "$SSH_CTRL/prod" -o StrictHostKeyChecking=no $PROD_USER@$PROD_HOST "$1" 2>/dev/null; }

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
echo -e "${BOLD}${MAGENTA}║     🚀 PRODUCTION AUDIT v5.1 [3X SPEED] - $(date '+%Y-%m-%d %H:%M:%S')        ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

init_connections

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 3)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 1: APP, DOCKER, SERVICES
# ═══════════════════════════════════════════════════════════════════════════════
section "2-8. APPLICATION & SERVICES"
if [ "$PROD_CONN" = true ]; then
    BATCH1=$(ssh_prod 'echo ":::DOCKER:::"; systemctl is-active docker
echo ":::NGINX:::"; systemctl is-active nginx
echo ":::BACKEND_CONTAINER:::"; docker ps --filter "name=tovplay-backend" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -1
echo ":::BACKEND_IMAGE:::"; docker ps --filter "name=tovplay-backend" --format "{{.Image}}" 2>/dev/null | head -1
echo ":::BACKEND_LOGS:::"; docker logs --tail 5 tovplay-backend 2>&1 | tail -3
echo ":::BACKEND_ERRORS:::"; docker logs tovplay-backend 2>&1 | grep -iE "error|exception|traceback" | tail -3
echo ":::PROMETHEUS:::"; docker ps --filter "name=prometheus" --format "{{.Status}}" 2>/dev/null | head -1
echo ":::LOKI:::"; docker ps --filter "name=loki" --format "{{.Status}}" 2>/dev/null | head -1
echo ":::GRAFANA:::"; docker ps --filter "name=grafana" --format "{{.Status}}" 2>/dev/null | head -1
echo ":::RUNNING_CONTAINERS:::"; docker ps -q 2>/dev/null | wc -l
echo ":::FRONTEND_EXISTS:::"; test -f /var/www/tovplay/index.html && echo yes || echo no
echo ":::FRONTEND_SIZE:::"; du -sh /var/www/tovplay 2>/dev/null | cut -f1
echo ":::LOAD:::"; cat /proc/loadavg | cut -d" " -f1-3
echo ":::MEM_PCT:::"; free | awk "/Mem:/{printf \"%.0f\", \$3/\$2*100}"
echo ":::DISK_PCT:::"; df -h / | awk "NR==2{print \$5}" | tr -d "%"' 15)

    DOCKER=$(echo "$BATCH1" | sed -n '/:::DOCKER:::/,/:::NGINX:::/p' | tail -1)
    NGINX=$(echo "$BATCH1" | sed -n '/:::NGINX:::/,/:::BACKEND_CONTAINER:::/p' | tail -1)
    BACKEND_CONT=$(echo "$BATCH1" | sed -n '/:::BACKEND_CONTAINER:::/,/:::BACKEND_IMAGE:::/p' | tail -1)
    BACKEND_IMG=$(echo "$BATCH1" | sed -n '/:::BACKEND_IMAGE:::/,/:::BACKEND_LOGS:::/p' | tail -1)
    BACKEND_LOGS=$(echo "$BATCH1" | sed -n '/:::BACKEND_LOGS:::/,/:::BACKEND_ERRORS:::/p' | grep -v ':::')
    BACKEND_ERRORS=$(echo "$BATCH1" | sed -n '/:::BACKEND_ERRORS:::/,/:::PROMETHEUS:::/p' | grep -v ':::')
    PROMETHEUS=$(echo "$BATCH1" | sed -n '/:::PROMETHEUS:::/,/:::LOKI:::/p' | tail -1)
    LOKI=$(echo "$BATCH1" | sed -n '/:::LOKI:::/,/:::GRAFANA:::/p' | tail -1)
    GRAFANA=$(echo "$BATCH1" | sed -n '/:::GRAFANA:::/,/:::RUNNING_CONTAINERS:::/p' | tail -1)
    CONTAINERS=$(echo "$BATCH1" | sed -n '/:::RUNNING_CONTAINERS:::/,/:::FRONTEND_EXISTS:::/p' | tail -1)
    FRONTEND=$(echo "$BATCH1" | sed -n '/:::FRONTEND_EXISTS:::/,/:::FRONTEND_SIZE:::/p' | tail -1)
    FRONTEND_SIZE=$(echo "$BATCH1" | sed -n '/:::FRONTEND_SIZE:::/,/:::LOAD:::/p' | tail -1)
    LOAD=$(echo "$BATCH1" | sed -n '/:::LOAD:::/,/:::MEM_PCT:::/p' | tail -1)
    MEM_PCT=$(echo "$BATCH1" | sed -n '/:::MEM_PCT:::/,/:::DISK_PCT:::/p' | tail -1)
    DISK_PCT=$(echo "$BATCH1" | sed -n '/:::DISK_PCT:::/,$p' | tail -1)

    echo -e "${CYAN}Core Services:${NC}"
    [ "$DOCKER" = "active" ] && check_pass "Docker: active" || { check_fail "Docker: $DOCKER"; add_critical "Docker down"; }
    [ "$NGINX" = "active" ] && check_pass "Nginx: active" || { check_fail "Nginx: $NGINX"; add_critical "Nginx down"; }

    echo -e "\n${CYAN}Application:${NC}"
    [ -n "$BACKEND_CONT" ] && check_pass "Backend: $BACKEND_CONT" || { check_fail "Backend container: not found"; add_critical "Backend down"; }
    check_info "Image: $BACKEND_IMG"
    [ "$FRONTEND" = "yes" ] && check_pass "Frontend: deployed ($FRONTEND_SIZE)" || { check_fail "Frontend: missing"; add_critical "Frontend down"; }

    echo -e "\n${CYAN}Monitoring Stack:${NC}"
    [ -n "$PROMETHEUS" ] && check_pass "Prometheus: $PROMETHEUS" || check_info "Prometheus: not found"
    [ -n "$LOKI" ] && check_pass "Loki: $LOKI" || check_info "Loki: not found"
    [ -n "$GRAFANA" ] && check_pass "Grafana: $GRAFANA" || check_info "Grafana: not found"
    check_info "Total containers: $CONTAINERS"

    echo -e "\n${CYAN}Resources:${NC}"
    check_info "Load: $LOAD | Memory: ${MEM_PCT}% | Disk: ${DISK_PCT}%"
    [ "${MEM_PCT:-0}" -gt 90 ] 2>/dev/null && { check_fail "Memory critical"; add_critical "Memory >90%"; }
    [ "${DISK_PCT:-0}" -gt 90 ] 2>/dev/null && { check_fail "Disk critical"; add_critical "Disk >90%"; }

    if [ -n "$BACKEND_ERRORS" ]; then
        check_warn "Backend errors detected:"
        echo "$BACKEND_ERRORS" | head -2 | while read -r line; do echo "    $line"; done
        add_medium "Backend errors in logs"
    else
        check_pass "No recent backend errors"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 2: DATABASE, BACKUPS, SSL
# ═══════════════════════════════════════════════════════════════════════════════
section "9-14. DATABASE, BACKUPS, SSL"
if [ "$PROD_CONN" = true ]; then
    BATCH2=$(ssh_prod 'echo ":::DB_CONN:::"; PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -c "SELECT 1" 2>/dev/null | grep -c "1"
echo ":::DB_SIZE:::"; PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -c "SELECT pg_size_pretty(pg_database_size(current_database()))" 2>/dev/null | head -3 | tail -1
echo ":::BACKUP_DIR:::"; test -d /opt/tovplay_backups && echo yes || echo no
echo ":::RECENT_BACKUPS:::"; find /opt/tovplay_backups -type f -mtime -1 2>/dev/null | wc -l
echo ":::BACKUP_SIZE:::"; du -sh /opt/tovplay_backups 2>/dev/null | cut -f1
echo ":::SSL_EXPIRY:::"; openssl s_client -connect localhost:443 -servername app.tovplay.org </dev/null 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2
echo ":::CERTBOT:::"; systemctl is-active certbot.timer 2>/dev/null' 15)

    DB_CONN=$(echo "$BATCH2" | sed -n '/:::DB_CONN:::/,/:::DB_SIZE:::/p' | tail -1)
    DB_SIZE=$(echo "$BATCH2" | sed -n '/:::DB_SIZE:::/,/:::BACKUP_DIR:::/p' | tail -1 | xargs)
    BACKUP_DIR=$(echo "$BATCH2" | sed -n '/:::BACKUP_DIR:::/,/:::RECENT_BACKUPS:::/p' | tail -1)
    RECENT_BACKUPS=$(echo "$BATCH2" | sed -n '/:::RECENT_BACKUPS:::/,/:::BACKUP_SIZE:::/p' | tail -1)
    BACKUP_SIZE=$(echo "$BATCH2" | sed -n '/:::BACKUP_SIZE:::/,/:::SSL_EXPIRY:::/p' | tail -1)
    SSL_EXPIRY=$(echo "$BATCH2" | sed -n '/:::SSL_EXPIRY:::/,/:::CERTBOT:::/p' | tail -1)
    CERTBOT=$(echo "$BATCH2" | sed -n '/:::CERTBOT:::/,$p' | tail -1)

    echo -e "${CYAN}Database:${NC}"
    [ "${DB_CONN:-0}" -eq 1 ] 2>/dev/null && check_pass "Database: connected" || { check_fail "Database: connection failed"; add_critical "DB unreachable"; }
    check_info "Database size: $DB_SIZE"

    echo -e "\n${CYAN}Backups:${NC}"
    [ "$BACKUP_DIR" = "yes" ] && check_pass "Backup directory: exists" || { check_warn "No backup directory"; add_medium "Setup backups"; }
    [ "${RECENT_BACKUPS:-0}" -gt 0 ] 2>/dev/null && check_pass "Recent backups: $RECENT_BACKUPS" || { check_warn "No recent backups"; add_high "Backup not running"; }
    check_info "Backup storage: $BACKUP_SIZE"

    echo -e "\n${CYAN}SSL:${NC}"
    if [ -n "$SSL_EXPIRY" ]; then
        EXPIRY_EPOCH=$(date -d "$SSL_EXPIRY" +%s 2>/dev/null || echo 0)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - $(date +%s)) / 86400 ))
        [ "$DAYS_LEFT" -lt 14 ] && { check_fail "SSL expires in $DAYS_LEFT days!"; add_critical "SSL expiring"; } || check_pass "SSL valid: $DAYS_LEFT days"
    fi
    [ "$CERTBOT" = "active" ] && check_pass "Auto-renewal: active" || check_info "Certbot: $CERTBOT"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# URL CHECK
# ═══════════════════════════════════════════════════════════════════════════════
section "15. URL ACCESSIBILITY"
HTTP=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "https://app.tovplay.org" 2>/dev/null)
TIME=$(curl -sL -o /dev/null -w "%{time_total}" --connect-timeout 5 --max-time 10 "https://app.tovplay.org" 2>/dev/null)
[ "$HTTP" = "200" ] && check_pass "https://app.tovplay.org: HTTP $HTTP (${TIME}s)" || { check_fail "URL: HTTP $HTTP"; add_critical "Site not accessible"; }

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL
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
else RATING="NEEDS WORK"; COLOR="$RED"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  PRODUCTION_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "PRODUCTION_SCORE:$SCORE"
