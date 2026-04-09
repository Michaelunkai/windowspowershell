#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# STAGING AUDIT v5.1 [3X SPEED OPTIMIZED] - SSH Batching Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
SCORE=100

SSH_CTRL="/tmp/tovplay_staging_$$"
mkdir -p "$SSH_CTRL"
cleanup() { ssh -S "$SSH_CTRL/stag" -O exit $STAGING_USER@$STAGING_HOST 2>/dev/null; rm -rf "$SSH_CTRL"; }
trap cleanup EXIT

init_connections() {
    sshpass -p "$STAGING_PASS" ssh -fNM -S "$SSH_CTRL/stag" -o ControlPersist=90 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
        $STAGING_USER@$STAGING_HOST 2>/dev/null
}

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
echo -e "${BOLD}${MAGENTA}║     🧪 STAGING AUDIT v5.1 [3X SPEED] - $(date '+%Y-%m-%d %H:%M:%S')           ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

init_connections

section "1. CONNECTIVITY"
STAGING_OK=$(ssh_staging "echo OK" 3)
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { check_fail "Staging: failed"; add_critical "SSH failed"; STAGING_CONN=false; }

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 1: ALL STAGING INFO
# ═══════════════════════════════════════════════════════════════════════════════
section "2-10. STAGING ENVIRONMENT"
if [ "$STAGING_CONN" = true ]; then
    BATCH1=$(ssh_staging 'echo ":::DOCKER:::"; systemctl is-active docker
echo ":::NGINX:::"; systemctl is-active nginx
echo ":::BACKEND_CONTAINER:::"; docker ps --filter "name=staging" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -1
echo ":::BACKEND_IMAGE:::"; docker ps --filter "name=staging" --format "{{.Image}}" 2>/dev/null | head -1
echo ":::CONTAINERS:::"; docker ps -q 2>/dev/null | wc -l
echo ":::FRONTEND_EXISTS:::"; test -f /var/www/tovplay-staging/index.html && echo yes || echo no
echo ":::FRONTEND_SIZE:::"; du -sh /var/www/tovplay-staging 2>/dev/null | cut -f1
echo ":::REPO_DIR:::"; test -d /home/admin/tovplay && echo yes || echo no
echo ":::GIT_BRANCH:::"; cd /home/admin/tovplay 2>/dev/null && git branch --show-current
echo ":::GIT_COMMIT:::"; cd /home/admin/tovplay 2>/dev/null && git log -1 --format="%h %s" 2>/dev/null
echo ":::UNCOMMITTED:::"; cd /home/admin/tovplay 2>/dev/null && git status --porcelain 2>/dev/null | wc -l
echo ":::LOAD:::"; cat /proc/loadavg | cut -d" " -f1-3
echo ":::MEM_PCT:::"; free | awk "/Mem:/{printf \"%.0f\", \$3/\$2*100}"
echo ":::DISK_PCT:::"; df -h / | awk "NR==2{print \$5}" | tr -d "%"
echo ":::DB_CONN:::"; PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -c "SELECT 1" 2>/dev/null | grep -c "1"
echo ":::BACKUPS:::"; find /opt/backups -type f -mtime -1 2>/dev/null | wc -l
echo ":::BACKUP_SIZE:::"; du -sh /opt/backups 2>/dev/null | cut -f1
echo ":::SYNC_STATUS:::"; test -f /home/admin/tovplay/.git/refs/remotes/origin/main && echo "synced" || echo "not synced"' 15)

    DOCKER=$(echo "$BATCH1" | sed -n '/:::DOCKER:::/,/:::NGINX:::/p' | tail -1)
    NGINX=$(echo "$BATCH1" | sed -n '/:::NGINX:::/,/:::BACKEND_CONTAINER:::/p' | tail -1)
    BACKEND_CONT=$(echo "$BATCH1" | sed -n '/:::BACKEND_CONTAINER:::/,/:::BACKEND_IMAGE:::/p' | tail -1)
    BACKEND_IMG=$(echo "$BATCH1" | sed -n '/:::BACKEND_IMAGE:::/,/:::CONTAINERS:::/p' | tail -1)
    CONTAINERS=$(echo "$BATCH1" | sed -n '/:::CONTAINERS:::/,/:::FRONTEND_EXISTS:::/p' | tail -1)
    FRONTEND=$(echo "$BATCH1" | sed -n '/:::FRONTEND_EXISTS:::/,/:::FRONTEND_SIZE:::/p' | tail -1)
    FRONTEND_SIZE=$(echo "$BATCH1" | sed -n '/:::FRONTEND_SIZE:::/,/:::REPO_DIR:::/p' | tail -1)
    REPO_DIR=$(echo "$BATCH1" | sed -n '/:::REPO_DIR:::/,/:::GIT_BRANCH:::/p' | tail -1)
    GIT_BRANCH=$(echo "$BATCH1" | sed -n '/:::GIT_BRANCH:::/,/:::GIT_COMMIT:::/p' | tail -1)
    GIT_COMMIT=$(echo "$BATCH1" | sed -n '/:::GIT_COMMIT:::/,/:::UNCOMMITTED:::/p' | tail -1)
    UNCOMMITTED=$(echo "$BATCH1" | sed -n '/:::UNCOMMITTED:::/,/:::LOAD:::/p' | tail -1)
    LOAD=$(echo "$BATCH1" | sed -n '/:::LOAD:::/,/:::MEM_PCT:::/p' | tail -1)
    MEM_PCT=$(echo "$BATCH1" | sed -n '/:::MEM_PCT:::/,/:::DISK_PCT:::/p' | tail -1)
    DISK_PCT=$(echo "$BATCH1" | sed -n '/:::DISK_PCT:::/,/:::DB_CONN:::/p' | tail -1)
    DB_CONN=$(echo "$BATCH1" | sed -n '/:::DB_CONN:::/,/:::BACKUPS:::/p' | tail -1)
    BACKUPS=$(echo "$BATCH1" | sed -n '/:::BACKUPS:::/,/:::BACKUP_SIZE:::/p' | tail -1)
    BACKUP_SIZE=$(echo "$BATCH1" | sed -n '/:::BACKUP_SIZE:::/,/:::SYNC_STATUS:::/p' | tail -1)
    SYNC=$(echo "$BATCH1" | sed -n '/:::SYNC_STATUS:::/,$p' | tail -1)

    echo -e "${CYAN}Services:${NC}"
    [ "$DOCKER" = "active" ] && check_pass "Docker: active" || { check_warn "Docker: $DOCKER"; add_high "Docker not running"; }
    [ "$NGINX" = "active" ] && check_pass "Nginx: active" || { check_warn "Nginx: $NGINX"; add_high "Nginx not running"; }

    echo -e "\n${CYAN}Application:${NC}"
    [ -n "$BACKEND_CONT" ] && check_pass "Backend: $BACKEND_CONT" || check_info "No staging backend container"
    check_info "Image: $BACKEND_IMG"
    check_info "Containers: $CONTAINERS"
    [ "$FRONTEND" = "yes" ] && check_pass "Frontend: deployed ($FRONTEND_SIZE)" || check_info "Frontend: not deployed"

    echo -e "\n${CYAN}Git Repository:${NC}"
    [ "$REPO_DIR" = "yes" ] && check_pass "Repository: exists" || check_info "Repository: not found"
    check_info "Branch: $GIT_BRANCH"
    check_info "Last commit: $GIT_COMMIT"
    [ "${UNCOMMITTED:-0}" -eq 0 ] 2>/dev/null && check_pass "Working tree: clean" || { check_warn "Uncommitted: $UNCOMMITTED"; add_low "Uncommitted changes"; }
    check_info "Sync status: $SYNC"

    echo -e "\n${CYAN}Resources:${NC}"
    check_info "Load: $LOAD | Memory: ${MEM_PCT}% | Disk: ${DISK_PCT}%"
    [ "${MEM_PCT:-0}" -gt 90 ] 2>/dev/null && { check_warn "Memory high"; add_medium "Memory >90%"; }
    [ "${DISK_PCT:-0}" -gt 90 ] 2>/dev/null && { check_warn "Disk high"; add_medium "Disk >90%"; }

    echo -e "\n${CYAN}Database:${NC}"
    [ "${DB_CONN:-0}" -eq 1 ] 2>/dev/null && check_pass "Database: connected" || { check_warn "Database: connection issue"; add_medium "DB connection"; }

    echo -e "\n${CYAN}Backups:${NC}"
    [ "${BACKUPS:-0}" -gt 0 ] 2>/dev/null && check_pass "Recent backups: $BACKUPS" || check_info "No recent backups"
    check_info "Backup storage: $BACKUP_SIZE"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# URL CHECK
# ═══════════════════════════════════════════════════════════════════════════════
section "11. URL ACCESSIBILITY"
HTTP=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "https://staging.tovplay.org" 2>/dev/null)
TIME=$(curl -sL -o /dev/null -w "%{time_total}" --connect-timeout 5 --max-time 10 "https://staging.tovplay.org" 2>/dev/null)
[ "$HTTP" = "200" ] && check_pass "https://staging.tovplay.org: HTTP $HTTP (${TIME}s)" || check_warn "URL: HTTP $HTTP"

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
printf "${BOLD}║  STAGING_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds    ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "STAGING_SCORE:$SCORE"
