#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# BACKEND AUDIT v5.1 [3X SPEED OPTIMIZED] - SSH Batching Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
SCORE=100

SSH_CTRL="/tmp/tovplay_backend_$$"
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
echo -e "${BOLD}${MAGENTA}║     ⚙️ BACKEND AUDIT v5.1 [3X SPEED] - $(date '+%Y-%m-%d %H:%M:%S')           ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

init_connections

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 3); STAGING_OK=$(ssh_staging "echo OK" 3)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { STAGING_CONN=false; }

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 1: PRODUCTION BACKEND
# ═══════════════════════════════════════════════════════════════════════════════
section "2-8. PRODUCTION BACKEND"
if [ "$PROD_CONN" = true ]; then
    BATCH1=$(ssh_prod 'echo ":::CONTAINER:::"; docker ps --filter "name=tovplay-backend" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -1
echo ":::IMAGE:::"; docker ps --filter "name=tovplay-backend" --format "{{.Image}}" 2>/dev/null | head -1
echo ":::PORTS:::"; docker ps --filter "name=tovplay-backend" --format "{{.Ports}}" 2>/dev/null | head -1
echo ":::HEALTH:::"; docker inspect --format="{{.State.Health.Status}}" tovplay-backend 2>/dev/null
echo ":::RESTARTS:::"; docker inspect --format="{{.RestartCount}}" tovplay-backend 2>/dev/null
echo ":::CPU:::"; docker stats --no-stream --format "{{.CPUPerc}}" tovplay-backend 2>/dev/null
echo ":::MEM:::"; docker stats --no-stream --format "{{.MemUsage}}" tovplay-backend 2>/dev/null
echo ":::LOGS:::"; docker logs --tail 10 tovplay-backend 2>&1 | tail -5
echo ":::ERRORS:::"; docker logs tovplay-backend 2>&1 | grep -iE "error|exception|traceback|failed" | tail -5
echo ":::ENV_FILE:::"; test -f /root/tovplay-backend/.env && echo yes || echo no
echo ":::REQUIREMENTS:::"; test -f /root/tovplay-backend/requirements.txt && wc -l /root/tovplay-backend/requirements.txt 2>/dev/null | cut -d" " -f1 || echo 0
echo ":::PYTHON:::"; docker exec tovplay-backend python --version 2>/dev/null || echo "N/A"
echo ":::API_HEALTH:::"; curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health 2>/dev/null || echo "N/A"' 15)

    CONTAINER=$(echo "$BATCH1" | sed -n '/:::CONTAINER:::/,/:::IMAGE:::/p' | tail -1)
    IMAGE=$(echo "$BATCH1" | sed -n '/:::IMAGE:::/,/:::PORTS:::/p' | tail -1)
    PORTS=$(echo "$BATCH1" | sed -n '/:::PORTS:::/,/:::HEALTH:::/p' | tail -1)
    HEALTH=$(echo "$BATCH1" | sed -n '/:::HEALTH:::/,/:::RESTARTS:::/p' | tail -1)
    RESTARTS=$(echo "$BATCH1" | sed -n '/:::RESTARTS:::/,/:::CPU:::/p' | tail -1)
    CPU=$(echo "$BATCH1" | sed -n '/:::CPU:::/,/:::MEM:::/p' | tail -1)
    MEM=$(echo "$BATCH1" | sed -n '/:::MEM:::/,/:::LOGS:::/p' | tail -1)
    LOGS=$(echo "$BATCH1" | sed -n '/:::LOGS:::/,/:::ERRORS:::/p' | grep -v ':::')
    ERRORS=$(echo "$BATCH1" | sed -n '/:::ERRORS:::/,/:::ENV_FILE:::/p' | grep -v ':::')
    ENV_FILE=$(echo "$BATCH1" | sed -n '/:::ENV_FILE:::/,/:::REQUIREMENTS:::/p' | tail -1)
    REQUIREMENTS=$(echo "$BATCH1" | sed -n '/:::REQUIREMENTS:::/,/:::PYTHON:::/p' | tail -1)
    PYTHON=$(echo "$BATCH1" | sed -n '/:::PYTHON:::/,/:::API_HEALTH:::/p' | tail -1)
    API_HEALTH=$(echo "$BATCH1" | sed -n '/:::API_HEALTH:::/,$p' | tail -1)

    echo -e "${CYAN}Container:${NC}"
    [ -n "$CONTAINER" ] && check_pass "Container: $CONTAINER" || { check_fail "Container: not running"; add_critical "Backend down"; }
    check_info "Image: $IMAGE"
    check_info "Ports: $PORTS"
    [ "$HEALTH" = "healthy" ] && check_pass "Health: healthy" || check_info "Health: $HEALTH"
    [ "${RESTARTS:-0}" -gt 5 ] 2>/dev/null && { check_warn "Restarts: $RESTARTS"; add_medium "High restart count"; } || check_pass "Restarts: ${RESTARTS:-0}"

    echo -e "\n${CYAN}Resources:${NC}"
    check_info "CPU: $CPU | Memory: $MEM"

    echo -e "\n${CYAN}Configuration:${NC}"
    [ "$ENV_FILE" = "yes" ] && check_pass ".env file: exists" || { check_warn ".env: missing"; add_medium "No .env file"; }
    check_info "Requirements: $REQUIREMENTS packages | Python: $PYTHON"

    echo -e "\n${CYAN}API Health:${NC}"
    [ "$API_HEALTH" = "200" ] && check_pass "Health endpoint: HTTP $API_HEALTH" || { check_warn "Health endpoint: $API_HEALTH"; add_high "API health check failed"; }

    if [ -n "$ERRORS" ]; then
        check_warn "Errors in logs:"
        echo "$ERRORS" | head -3 | while read -r line; do echo "    ${line:0:80}..."; done
        add_medium "Backend errors in logs"
    else
        check_pass "No recent errors"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 2: DATABASE CONNECTION
# ═══════════════════════════════════════════════════════════════════════════════
section "9-11. DATABASE CONNECTION"
if [ "$PROD_CONN" = true ]; then
    BATCH2=$(ssh_prod 'echo ":::DB_CONN:::"; PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -c "SELECT 1" 2>/dev/null | grep -c "1"
echo ":::TABLES:::"; PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '"'"'public'"'"'" 2>/dev/null | head -3 | tail -1
echo ":::USER_COUNT:::"; PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -c "SELECT COUNT(*) FROM \"User\"" 2>/dev/null | head -3 | tail -1' 10)

    DB_CONN=$(echo "$BATCH2" | sed -n '/:::DB_CONN:::/,/:::TABLES:::/p' | tail -1)
    TABLES=$(echo "$BATCH2" | sed -n '/:::TABLES:::/,/:::USER_COUNT:::/p' | tail -1 | xargs)
    USER_COUNT=$(echo "$BATCH2" | sed -n '/:::USER_COUNT:::/,$p' | tail -1 | xargs)

    [ "${DB_CONN:-0}" -eq 1 ] 2>/dev/null && check_pass "Database: connected" || { check_fail "Database: connection failed"; add_critical "DB unreachable"; }
    check_info "Tables: $TABLES | Users: $USER_COUNT"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STAGING BACKEND
# ═══════════════════════════════════════════════════════════════════════════════
section "12-13. STAGING BACKEND"
if [ "$STAGING_CONN" = true ]; then
    BATCH3=$(ssh_staging 'echo ":::CONTAINER:::"; docker ps --filter "name=staging" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -1
echo ":::API_HEALTH:::"; curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/health 2>/dev/null || echo "N/A"' 8)

    STG_CONTAINER=$(echo "$BATCH3" | sed -n '/:::CONTAINER:::/,/:::API_HEALTH:::/p' | tail -1)
    STG_API=$(echo "$BATCH3" | sed -n '/:::API_HEALTH:::/,$p' | tail -1)

    [ -n "$STG_CONTAINER" ] && check_pass "Container: $STG_CONTAINER" || check_info "No staging container"
    [ "$STG_API" = "200" ] && check_pass "Staging API: HTTP $STG_API" || check_info "Staging API: $STG_API"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# COMPARISON
# ═══════════════════════════════════════════════════════════════════════════════
section "14. COMPARISON"
echo -e "  ${BOLD}Metric              Production    Staging${NC}"
echo -e "  ─────────────────────────────────────────────"
printf "  %-18s %-13s %s\n" "Container" "${CONTAINER:0:12}" "${STG_CONTAINER:0:12}"
printf "  %-18s %-13s %s\n" "Health" "${HEALTH:-?}" "?"
printf "  %-18s %-13s %s\n" "API" "${API_HEALTH:-?}" "${STG_API:-?}"

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
else RATING="NEEDS WORK"; COLOR="$YELLOW"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  BACKEND_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds     ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "BACKEND_SCORE:$SCORE"
