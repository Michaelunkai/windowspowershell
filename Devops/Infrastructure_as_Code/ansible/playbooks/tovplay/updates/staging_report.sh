#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# STAGING AUDIT v5.2 [FIXED] - Direct sshpass Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

# Source ultra-fast SSH helpers (uses ansall.sh ControlMaster for instant connections)
SCRIPT_DIR_ABS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR_ABS/fast_ssh_helpers.sh" 2>/dev/null || true

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
echo -e "${BOLD}${MAGENTA}║     🧪 STAGING AUDIT v5.2 [FIXED] - $(date '+%Y-%m-%d %H:%M:%S')              ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

section "1. CONNECTIVITY"
STAGING_OK=$(ssh_staging "echo OK" 30)
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { check_fail "Staging: failed"; add_critical "SSH failed"; STAGING_CONN=false; }

section "2-10. STAGING ENVIRONMENT"
if [ "$STAGING_CONN" = true ]; then
    DOCKER=$(ssh_staging "systemctl is-active docker" 5 | tr -d '\r\n' | xargs)
    NGINX=$(ssh_staging "systemctl is-active nginx" 5 | tr -d '\r\n' | xargs)
    BACKEND_CONT=$(ssh_staging 'docker ps --filter "name=staging" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -1' 5 | tr -d '\r')
    BACKEND_IMG=$(ssh_staging 'docker ps --filter "name=staging" --format "{{.Image}}" 2>/dev/null | head -1' 5 | tr -d '\r\n' | xargs)
    CONTAINERS=$(ssh_staging 'docker ps -q 2>/dev/null | wc -l' 5 | tr -d '\r\n' | xargs)
    FRONTEND=$(ssh_staging 'test -f /var/www/tovplay-staging/index.html && echo yes || echo no' 5 | tr -d '\r\n' | xargs)
    FRONTEND_SIZE=$(ssh_staging 'du -sh /var/www/tovplay-staging 2>/dev/null | cut -f1' 5 | tr -d '\r\n' | xargs)
    REPO_DIR=$(ssh_staging 'test -d /home/admin/tovplay && echo yes || echo no' 5 | tr -d '\r\n' | xargs)
    GIT_BRANCH=$(ssh_staging 'cd /home/admin/tovplay 2>/dev/null && git branch --show-current' 5 | tr -d '\r\n' | xargs)
    GIT_COMMIT=$(ssh_staging 'cd /home/admin/tovplay 2>/dev/null && git log -1 --format="%h %s" 2>/dev/null' 5 | tr -d '\r')
    UNCOMMITTED=$(ssh_staging 'cd /home/admin/tovplay 2>/dev/null && git status --porcelain 2>/dev/null | wc -l' 5 | tr -d '\r\n' | xargs)
    LOAD=$(ssh_staging 'cat /proc/loadavg | cut -d" " -f1-3' 5 | tr -d '\r')
    MEM_PCT=$(ssh_staging 'free | awk "/Mem:/{printf \"%.0f\", \$3/\$2*100}"' 5 | tr -d '\r\n' | xargs)
    DISK_PCT=$(ssh_staging 'df -h / | awk "NR==2{print \$5}" | tr -d "%"' 5 | tr -d '\r\n' | xargs)
    DB_CONN=$(ssh_staging 'PGPASSWORD="CaptainForgotCreatureBreak" psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -c "SELECT 1" 2>/dev/null | grep -c "1"' 10 | tr -d '\r\n' | xargs)
    BACKUPS=$(ssh_staging 'find /opt/backups -type f -mtime -1 2>/dev/null | wc -l' 5 | tr -d '\r\n' | xargs)
    BACKUP_SIZE=$(ssh_staging 'du -sh /opt/backups 2>/dev/null | cut -f1' 5 | tr -d '\r\n' | xargs)
    SYNC=$(ssh_staging 'test -f /home/admin/tovplay/.git/refs/remotes/origin/main && echo "synced" || echo "not synced"' 5 | tr -d '\r\n' | xargs)

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
    [ "${DB_CONN:-0}" -ge 1 ] 2>/dev/null && check_pass "Database: connected" || { check_warn "Database: connection issue"; add_medium "DB connection"; }

    echo -e "\n${CYAN}Backups:${NC}"
    [ "${BACKUPS:-0}" -gt 0 ] 2>/dev/null && check_pass "Recent backups: $BACKUPS" || check_info "No recent backups"
    check_info "Backup storage: $BACKUP_SIZE"
fi

section "11. URL ACCESSIBILITY"
HTTP=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "https://staging.tovplay.org" 2>/dev/null)
TIME=$(curl -sL -o /dev/null -w "%{time_total}" --connect-timeout 5 --max-time 10 "https://staging.tovplay.org" 2>/dev/null)
[ "$HTTP" = "200" ] && check_pass "https://staging.tovplay.org: HTTP $HTTP (${TIME}s)" || check_warn "URL: HTTP $HTTP"

section "🔴 THINGS TO FIX"
if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
    echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              🔴 THINGS TO FIX - STAGING                       ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}🟠 HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
    for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}🔵 LOW: $issue${NC}"; done
else
    echo -e "  ${GREEN}✓ No issues found! Staging is healthy.${NC}"
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
printf "${BOLD}║  STAGING_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds    ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "STAGING_SCORE:$SCORE"
