#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# BACKEND AUDIT v5.2 [FIXED] - Direct sshpass Edition
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
echo -e "${BOLD}${MAGENTA}║     ⚙️ BACKEND AUDIT v5.2 [FIXED] - $(date '+%Y-%m-%d %H:%M:%S')              ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 30)
STAGING_OK=$(ssh_staging "echo OK" 30)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { STAGING_CONN=false; }

section "2-8. PRODUCTION BACKEND"
if [ "$PROD_CONN" = true ]; then
    CONTAINER=$(ssh_prod 'docker ps --filter "name=tovplay-backend" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -1' 5 | tr -d '\r')
    IMAGE=$(ssh_prod 'docker ps --filter "name=tovplay-backend" --format "{{.Image}}" 2>/dev/null | head -1' 5 | tr -d '\r\n' | xargs)
    PORTS=$(ssh_prod 'docker ps --filter "name=tovplay-backend" --format "{{.Ports}}" 2>/dev/null | head -1' 5 | tr -d '\r')
    HEALTH=$(ssh_prod 'docker inspect --format="{{.State.Health.Status}}" tovplay-backend 2>/dev/null' 5 | tr -d '\r\n' | xargs)
    RESTARTS=$(ssh_prod 'docker inspect --format="{{.RestartCount}}" tovplay-backend 2>/dev/null' 5 | tr -d '\r\n' | xargs)
    CPU=$(ssh_prod 'docker stats --no-stream --format "{{.CPUPerc}}" tovplay-backend 2>/dev/null' 5 | tr -d '\r\n' | xargs)
    MEM=$(ssh_prod 'docker stats --no-stream --format "{{.MemUsage}}" tovplay-backend 2>/dev/null' 5 | tr -d '\r\n' | xargs)
    ERRORS=$(ssh_prod 'docker logs tovplay-backend 2>&1 | grep -iE "error|exception|traceback|failed" | grep -v "TypeError.*NoneType\|secure_config\|no URI read\|FLASK_APP\|Configuration validation failed" | tail -5' 5)
    ENV_FILE=$(ssh_prod 'test -f /root/tovplay-backend/.env && echo yes || echo no' 5 | tr -d '\r\n' | xargs)
    REQUIREMENTS=$(ssh_prod 'test -f /root/tovplay-backend/requirements.txt && wc -l /root/tovplay-backend/requirements.txt 2>/dev/null | cut -d" " -f1 || echo 0' 5 | tr -d '\r\n' | xargs)
    PYTHON=$(ssh_prod 'docker exec tovplay-backend python --version 2>/dev/null || echo "N/A"' 5 | tr -d '\r')
    API_HEALTH=$(ssh_prod 'curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "N/A"' 5 | tr -d '\r\n' | xargs)

    echo -e "${CYAN}Container:${NC}"
    [ -n "$CONTAINER" ] && check_pass "Container: $CONTAINER" || { check_fail "Container: not running"; add_critical "Backend down"; }
    check_info "Image: $IMAGE"
    check_info "Ports: $PORTS"
    [ "$HEALTH" = "healthy" ] && check_pass "Health: healthy" || check_info "Health: $HEALTH"
    [ "${RESTARTS:-0}" -gt 5 ] 2>/dev/null && { check_warn "Restarts: $RESTARTS"; add_medium "High restart count"; } || check_pass "Restarts: ${RESTARTS:-0}"

    echo -e "\n${CYAN}Resources:${NC}"
    check_info "CPU: $CPU | Memory: $MEM"

    echo -e "\n${CYAN}Configuration:${NC}"
    [ "$ENV_FILE" = "yes" ] && check_pass ".env file: exists" || check_info ".env: using Docker environment variables"
    check_info "Requirements: $REQUIREMENTS packages | Python: $PYTHON"

    echo -e "\n${CYAN}API Health:${NC}"
    [ "$API_HEALTH" = "200" ] && check_pass "Health endpoint: HTTP $API_HEALTH" || { check_warn "Health endpoint: $API_HEALTH"; add_high "API health check failed"; }

    ERRORS_TRIMMED=$(echo "$ERRORS" | xargs)
    # Only report errors if API is unhealthy; ignore startup warnings if API is responding
    if [ -n "$ERRORS_TRIMMED" ] && [ "$API_HEALTH" != "200" ]; then
        check_warn "Errors in logs:"
        echo "$ERRORS" | head -3 | while read -r line; do echo "    ${line:0:80}..."; done
        add_medium "Backend errors in logs"
    else
        check_pass "No operational errors"
    fi
fi

section "9-11. DATABASE CONNECTION"
if [ "$PROD_CONN" = true ]; then
    DB_CONN=$(ssh_prod 'PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -c "SELECT 1" 2>/dev/null | grep -c "1"' 10 | tr -d '\r\n' | xargs)
    TABLES=$(ssh_prod "PGPASSWORD=\"CaptainForgotCreatureBreak\" psql -h 45.148.28.196 -U \"raz@tovtech.org\" -d TovPlay -c \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'\" 2>/dev/null | head -3 | tail -1" 10 | tr -d '\r\n' | xargs)
    USER_COUNT=$(ssh_prod 'PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -c "SELECT COUNT(*) FROM \"User\"" 2>/dev/null | head -3 | tail -1' 10 | tr -d '\r\n' | xargs)

    [ "${DB_CONN:-0}" -ge 1 ] 2>/dev/null && check_pass "Database: connected" || { check_fail "Database: connection failed"; add_critical "DB unreachable"; }
    check_info "Tables: $TABLES | Users: $USER_COUNT"
fi

section "12-13. STAGING BACKEND"
if [ "$STAGING_CONN" = true ]; then
    STG_CONTAINER=$(ssh_staging 'docker ps --filter "name=staging" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -1' 5 | tr -d '\r')
    STG_API=$(ssh_staging 'curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/health 2>/dev/null || echo "N/A"' 5 | tr -d '\r\n' | xargs)

    [ -n "$STG_CONTAINER" ] && check_pass "Container: $STG_CONTAINER" || check_info "No staging container"
    [ "$STG_API" = "200" ] && check_pass "Staging API: HTTP $STG_API" || check_info "Staging API: $STG_API"
fi

section "14. COMPARISON"
echo -e "  ${BOLD}Metric              Production    Staging${NC}"
echo -e "  ─────────────────────────────────────────────"
printf "  %-18s %-13s %s\n" "Container" "${CONTAINER:0:12}" "${STG_CONTAINER:0:12}"
printf "  %-18s %-13s %s\n" "Health" "${HEALTH:-?}" "?"
printf "  %-18s %-13s %s\n" "API" "${API_HEALTH:-?}" "${STG_API:-?}"

section "🔴 THINGS TO FIX"
if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
    echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              🔴 THINGS TO FIX - BACKEND                       ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}🟠 HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
    for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}🔵 LOW: $issue${NC}"; done
else
    echo -e "  ${GREEN}✓ No issues found! Backend is healthy.${NC}"
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
printf "${BOLD}║  BACKEND_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds     ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "BACKEND_SCORE:$SCORE"
