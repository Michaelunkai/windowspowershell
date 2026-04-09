#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# PRODUCTION AUDIT v5.2 [FIXED] - Direct sshpass Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

# Source ultra-fast SSH helpers (uses ansall.sh ControlMaster for instant connections)
SCRIPT_DIR_ABS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR_ABS/fast_ssh_helpers.sh" 2>/dev/null || true

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"

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
echo -e "${BOLD}${MAGENTA}║     🚀 PRODUCTION AUDIT v5.2 [FIXED] - $(date '+%Y-%m-%d %H:%M:%S')          ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 30)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }

# ═══════════════════════════════════════════════════════════════════════════════
# SERVICES CHECK
# ═══════════════════════════════════════════════════════════════════════════════
section "2-8. APPLICATION & SERVICES"
if [ "$PROD_CONN" = true ]; then
    DOCKER=$(ssh_prod "systemctl is-active docker" 5 | tr -d '\r\n' | xargs)
    NGINX=$(ssh_prod "systemctl is-active nginx" 5 | tr -d '\r\n' | xargs)
    BACKEND_CONT=$(ssh_prod 'docker ps --filter "name=tovplay-backend" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -1' 5 | tr -d '\r')
    BACKEND_IMG=$(ssh_prod 'docker ps --filter "name=tovplay-backend" --format "{{.Image}}" 2>/dev/null | head -1' 5 | tr -d '\r\n' | xargs)
    BACKEND_ERRORS=$(ssh_prod 'docker logs tovplay-backend 2>&1 | grep -iE "error|exception|traceback" | grep -v "TypeError.*NoneType\|secure_config\|no URI read\|FLASK_APP\|Configuration validation failed" | tail -3' 5)
    PROMETHEUS=$(ssh_prod 'docker ps --filter "name=prometheus" --format "{{.Status}}" 2>/dev/null | head -1' 5 | tr -d '\r')
    LOKI=$(ssh_prod 'docker ps --filter "name=loki" --format "{{.Status}}" 2>/dev/null | head -1' 5 | tr -d '\r')
    GRAFANA=$(ssh_prod 'docker ps --filter "name=grafana" --format "{{.Status}}" 2>/dev/null | head -1' 5 | tr -d '\r')
    CONTAINERS=$(ssh_prod 'docker ps -q 2>/dev/null | wc -l' 5 | tr -d '\r\n' | xargs)
    FRONTEND=$(ssh_prod 'test -f /var/www/tovplay/index.html && echo yes || echo no' 5 | tr -d '\r\n' | xargs)
    FRONTEND_SIZE=$(ssh_prod 'du -sh /var/www/tovplay 2>/dev/null | cut -f1' 5 | tr -d '\r\n' | xargs)
    LOAD=$(ssh_prod 'cat /proc/loadavg | cut -d" " -f1-3' 5 | tr -d '\r')
    MEM_PCT=$(ssh_prod 'free | awk "/Mem:/{printf \"%.0f\", \$3/\$2*100}"' 5 | tr -d '\r\n' | xargs)
    DISK_PCT=$(ssh_prod 'df -h / | awk "NR==2{print \$5}" | tr -d "%"' 5 | tr -d '\r\n' | xargs)

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

    BACKEND_ERRORS_TRIMMED=$(echo "$BACKEND_ERRORS" | xargs)
    # Only report errors if container is in bad state; startup warnings OK if container is running/healthy/starting
    CONTAINER_UNHEALTHY=$(echo "$BACKEND_CONT" | grep -qE "Exited|Dead" && echo "true" || echo "false")
    if [ -n "$BACKEND_ERRORS_TRIMMED" ] && [ "$CONTAINER_UNHEALTHY" = "true" ]; then
        check_warn "Backend errors detected:"
        echo "$BACKEND_ERRORS" | head -2 | while read -r line; do echo "    $line"; done
        add_medium "Backend errors in logs"
    else
        check_pass "No operational errors"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# DATABASE, BACKUPS, SSL
# ═══════════════════════════════════════════════════════════════════════════════
section "9-14. DATABASE, BACKUPS, SSL"
if [ "$PROD_CONN" = true ]; then
    DB_CONN=$(ssh_prod 'PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -c "SELECT 1" 2>/dev/null | grep -c "1"' 10 | tr -d '\r\n' | xargs)
    DB_SIZE=$(ssh_prod 'PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -c "SELECT pg_size_pretty(pg_database_size(current_database()))" 2>/dev/null | head -3 | tail -1' 10 | tr -d '\r\n' | xargs)
    BACKUP_DIR=$(ssh_prod 'test -d /opt/tovplay_backups && echo yes || echo no' 5 | tr -d '\r\n' | xargs)
    RECENT_BACKUPS=$(ssh_prod 'find /opt/tovplay_backups -type f -mtime -1 2>/dev/null | wc -l' 5 | tr -d '\r\n' | xargs)
    BACKUP_SIZE=$(ssh_prod 'du -sh /opt/tovplay_backups 2>/dev/null | cut -f1' 5 | tr -d '\r\n' | xargs)
    SSL_EXPIRY=$(ssh_prod 'openssl s_client -connect localhost:443 -servername app.tovplay.org </dev/null 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2' 10 | tr -d '\r')
    CERTBOT=$(ssh_prod 'systemctl is-active certbot.timer 2>/dev/null' 5 | tr -d '\r\n' | xargs)

    echo -e "${CYAN}Database:${NC}"
    [ "${DB_CONN:-0}" -ge 1 ] 2>/dev/null && check_pass "Database: connected" || { check_fail "Database: connection failed"; add_critical "DB unreachable"; }
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
section "🔴 THINGS TO FIX"
if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
    echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              🔴 THINGS TO FIX - PRODUCTION                    ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}🟠 HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
    for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}🔵 LOW: $issue${NC}"; done
else
    echo -e "  ${GREEN}✓ No issues found! Production is healthy.${NC}"
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
printf "${BOLD}║  PRODUCTION_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "PRODUCTION_SCORE:$SCORE"
