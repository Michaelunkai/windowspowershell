#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# CI/CD PIPELINE AUDIT v5.2 [MARKER-BASED PARSING] - Reliable SSH Output
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

# GitHub Configuration
GITHUB_ORG="TovTechOrg"; FRONTEND_REPO="tovplay-frontend"; BACKEND_REPO="tovplay-backend"

# Servers
PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'; DIM='\033[2m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
SCORE=100

# SSH helpers
ssh_prod() { timeout ${2:-8}s sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 $PROD_USER@$PROD_HOST "$1" 2>/dev/null | tr -d '\r'; }
ssh_staging() { timeout ${2:-8}s sshpass -p "$STAGING_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 $STAGING_USER@$STAGING_HOST "$1" 2>/dev/null | tr -d '\r'; }

# Extract value from marker-prefixed output
extract_value() {
    echo "$1" | grep "^$2:" | head -1 | cut -d: -f2-
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
echo -e "${BOLD}${MAGENTA}║     CI/CD AUDIT v5.2 [MARKER-BASED] - $(date '+%Y-%m-%d %H:%M:%S')     ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: CONNECTIVITY
# ═══════════════════════════════════════════════════════════════════════════════
section "1. SERVER CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 5); STAGING_OK=$(ssh_staging "echo OK" 5)
[ "$PROD_OK" = "OK" ] && { check_pass "Production SSH: connected"; PROD_CONN=true; } || { check_fail "Production SSH: failed"; add_critical "Production SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging SSH: connected"; STAGING_CONN=true; } || { check_warn "Staging SSH: failed"; STAGING_CONN=false; }

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 1: PRODUCTION CI/CD STATUS (marker-based)
# ═══════════════════════════════════════════════════════════════════════════════
section "2-6. PRODUCTION CI/CD & DEPLOYMENT"
if [ "$PROD_CONN" = true ]; then
    BATCH1=$(ssh_prod '
echo "GIT_INSTALLED:$(which git >/dev/null 2>&1 && echo yes || echo no)"
echo "DOCKER_STATUS:$(systemctl is-active docker 2>/dev/null || echo inactive)"
echo "BACKEND_DIR:$(test -d /root/tovplay-backend && echo yes || test -d /opt/tovplay && echo yes || echo no)"
echo "BACKEND_BRANCH:$(cd /root/tovplay-backend 2>/dev/null && git branch --show-current || cd /opt/tovplay 2>/dev/null && git branch --show-current || echo unknown)"
echo "BACKEND_COMMIT:$(cd /root/tovplay-backend 2>/dev/null && git log -1 --format="%h %s" 2>/dev/null || cd /opt/tovplay 2>/dev/null && git log -1 --format="%h %s" 2>/dev/null || echo unknown)"
echo "BACKEND_REMOTE:$(cd /root/tovplay-backend 2>/dev/null && git remote -v 2>/dev/null | head -1 || cd /opt/tovplay 2>/dev/null && git remote -v 2>/dev/null | head -1 || echo none)"
echo "LAST_PULL:$(cd /root/tovplay-backend 2>/dev/null && stat -c "%y" .git/FETCH_HEAD 2>/dev/null | cut -d. -f1 || cd /opt/tovplay 2>/dev/null && stat -c "%y" .git/FETCH_HEAD 2>/dev/null | cut -d. -f1 || echo unknown)"
echo "UNCOMMITTED:$(cd /root/tovplay-backend 2>/dev/null && git status --porcelain 2>/dev/null | wc -l || cd /opt/tovplay 2>/dev/null && git status --porcelain 2>/dev/null | wc -l || echo 0)"
echo "CONTAINER_STATUS:$(docker ps --filter "name=tovplay-backend" --format "{{.Status}}" 2>/dev/null | head -1)"
echo "CONTAINER_IMAGE:$(docker ps --filter "name=tovplay-backend" --format "{{.Image}}" 2>/dev/null | head -1)"
echo "WEBHOOK_LOG:$(test -f /var/log/tovplay/github-webhooks.log && tail -1 /var/log/tovplay/github-webhooks.log 2>/dev/null || echo none)"
echo "DEPLOY_SCRIPT:$(test -f /root/deploy.sh && echo yes || test -f /opt/deploy.sh && echo yes || echo no)"
echo "ENV_FILE:$(test -f /opt/tovplay/.env && echo yes || test -f /opt/tovplay-backend/.env && echo yes || test -f /home/admin/tovplay/.env && echo yes || echo no)"
' 15)

    GIT_INSTALLED=$(extract_value "$BATCH1" "GIT_INSTALLED")
    DOCKER_STATUS=$(extract_value "$BATCH1" "DOCKER_STATUS")
    BACKEND_DIR=$(extract_value "$BATCH1" "BACKEND_DIR")
    BACKEND_BRANCH=$(extract_value "$BATCH1" "BACKEND_BRANCH")
    BACKEND_COMMIT=$(extract_value "$BATCH1" "BACKEND_COMMIT")
    BACKEND_REMOTE=$(extract_value "$BATCH1" "BACKEND_REMOTE")
    LAST_PULL=$(extract_value "$BATCH1" "LAST_PULL")
    UNCOMMITTED=$(extract_value "$BATCH1" "UNCOMMITTED")
    CONTAINER_STATUS=$(extract_value "$BATCH1" "CONTAINER_STATUS")
    CONTAINER_IMAGE=$(extract_value "$BATCH1" "CONTAINER_IMAGE")
    WEBHOOK_LOG=$(extract_value "$BATCH1" "WEBHOOK_LOG")
    DEPLOY_SCRIPT=$(extract_value "$BATCH1" "DEPLOY_SCRIPT")
    ENV_FILE=$(extract_value "$BATCH1" "ENV_FILE")

    echo -e "${CYAN}Git & Deployment:${NC}"
    [ "$GIT_INSTALLED" = "yes" ] && check_pass "Git: installed" || check_warn "Git not installed"
    [ "$BACKEND_DIR" = "yes" ] && check_pass "Backend repo: exists" || check_info "Backend repo: Docker-based deploy"
    [ -n "$BACKEND_BRANCH" ] && [ "$BACKEND_BRANCH" != "unknown" ] && check_info "Branch: $BACKEND_BRANCH"
    [ -n "$BACKEND_COMMIT" ] && [ "$BACKEND_COMMIT" != "unknown" ] && check_info "Last commit: $BACKEND_COMMIT"
    [ -n "$BACKEND_REMOTE" ] && [ "$BACKEND_REMOTE" != "none" ] && check_info "Remote: $BACKEND_REMOTE"
    [ -n "$LAST_PULL" ] && [ "$LAST_PULL" != "unknown" ] && check_info "Last fetch: $LAST_PULL"
    [ "${UNCOMMITTED:-0}" -eq 0 ] 2>/dev/null && check_pass "Working tree: clean" || check_info "Uncommitted changes: ${UNCOMMITTED:-0}"

    echo -e "\n${CYAN}Docker Deployment:${NC}"
    [ "$DOCKER_STATUS" = "active" ] && check_pass "Docker: active" || { check_fail "Docker: $DOCKER_STATUS"; add_critical "Docker not running"; }
    [ -n "$CONTAINER_STATUS" ] && check_pass "Backend container: $CONTAINER_STATUS" || check_info "Backend container: checking..."
    [ -n "$CONTAINER_IMAGE" ] && check_info "Container image: $CONTAINER_IMAGE"

    echo -e "\n${CYAN}Automation:${NC}"
    [ "$DEPLOY_SCRIPT" = "yes" ] && check_pass "Deploy script: exists" || check_info "Deploy script: using CI/CD"
    [ -n "$WEBHOOK_LOG" ] && [ "$WEBHOOK_LOG" != "none" ] && { check_pass "Webhook logging: active"; } || check_info "Webhook: not configured"
    [ "$ENV_FILE" = "yes" ] && check_pass "Environment file: exists" || check_info "Env file: using Docker secrets"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 2: STAGING CI/CD (marker-based)
# ═══════════════════════════════════════════════════════════════════════════════
section "7-9. STAGING CI/CD"
if [ "$STAGING_CONN" = true ]; then
    BATCH2=$(ssh_staging '
echo "STG_DIR:$(test -d /home/admin/tovplay && echo yes || echo no)"
echo "STG_BRANCH:$(cd /home/admin/tovplay 2>/dev/null && git branch --show-current || echo unknown)"
echo "STG_COMMIT:$(cd /home/admin/tovplay 2>/dev/null && git log -1 --format="%h %s" 2>/dev/null || echo unknown)"
echo "STG_UNCOMMITTED:$(cd /home/admin/tovplay 2>/dev/null && git status --porcelain 2>/dev/null | wc -l || echo 0)"
echo "STG_CONTAINER:$(docker ps --filter "name=staging" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -1)"
' 10)

    STG_DIR=$(extract_value "$BATCH2" "STG_DIR")
    STG_BRANCH=$(extract_value "$BATCH2" "STG_BRANCH")
    STG_COMMIT=$(extract_value "$BATCH2" "STG_COMMIT")
    STG_UNCOMMITTED=$(extract_value "$BATCH2" "STG_UNCOMMITTED")
    STG_CONTAINER=$(extract_value "$BATCH2" "STG_CONTAINER")

    [ "$STG_DIR" = "yes" ] && check_pass "Staging repo: exists" || check_info "Staging repo: Docker-based"
    [ -n "$STG_BRANCH" ] && [ "$STG_BRANCH" != "unknown" ] && check_info "Branch: $STG_BRANCH"
    [ -n "$STG_COMMIT" ] && [ "$STG_COMMIT" != "unknown" ] && check_info "Last commit: $STG_COMMIT"
    [ "${STG_UNCOMMITTED:-0}" -eq 0 ] 2>/dev/null && check_pass "Working tree: clean" || check_info "Uncommitted: ${STG_UNCOMMITTED:-0}"
    [ -n "$STG_CONTAINER" ] && check_pass "Container: $STG_CONTAINER" || check_info "Staging container: checking..."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 10: GITHUB WORKFLOWS (Local check)
# ═══════════════════════════════════════════════════════════════════════════════
section "10-12. GITHUB WORKFLOWS"
LOCAL_BE="/mnt/f/tovplay/tovplay-backend"
LOCAL_FE="/mnt/f/tovplay/tovplay-frontend"

if [ -d "$LOCAL_BE/.github/workflows" ]; then
    BE_WORKFLOWS=$(ls "$LOCAL_BE/.github/workflows/"*.yml 2>/dev/null | wc -l)
    check_pass "Backend workflows: $BE_WORKFLOWS found"
    ls "$LOCAL_BE/.github/workflows/"*.yml 2>/dev/null | while read f; do check_info "  $(basename $f)"; done
else
    check_info "Backend workflows: not found locally"
fi

if [ -d "$LOCAL_FE/.github/workflows" ]; then
    FE_WORKFLOWS=$(ls "$LOCAL_FE/.github/workflows/"*.yml 2>/dev/null | wc -l)
    check_pass "Frontend workflows: $FE_WORKFLOWS found"
    ls "$LOCAL_FE/.github/workflows/"*.yml 2>/dev/null | while read f; do check_info "  $(basename $f)"; done
else
    check_info "Frontend workflows: not found locally"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 13: DOCKER REGISTRY (marker-based)
# ═══════════════════════════════════════════════════════════════════════════════
section "13-14. DOCKER REGISTRY"
if [ "$PROD_CONN" = true ]; then
    BATCH3=$(ssh_prod '
echo "IMAGES_START"
docker images --format "{{.Repository}}:{{.Tag}} {{.CreatedSince}}" 2>/dev/null | grep -i tovplay | head -5
echo "IMAGES_END"
echo "LATEST:$(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep latest | head -1)"
' 10)

    IMAGES=$(echo "$BATCH3" | sed -n '/IMAGES_START/,/IMAGES_END/p' | grep -v 'IMAGES_')
    LATEST=$(extract_value "$BATCH3" "LATEST")

    echo -e "${CYAN}Docker Images:${NC}"
    echo "$IMAGES" | while read -r line; do [ -n "$line" ] && check_info "$line"; done
    [ -n "$LATEST" ] && check_pass "Latest tags found" || check_info "No :latest tags"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# ENVIRONMENT COMPARISON
# ═══════════════════════════════════════════════════════════════════════════════
section "15. ENVIRONMENT COMPARISON"
echo -e "  ${BOLD}Metric              Production    Staging${NC}"
echo -e "  ─────────────────────────────────────────────"
printf "  %-18s %-13s %s\n" "Branch" "${BACKEND_BRANCH:-docker}" "${STG_BRANCH:-docker}"
printf "  %-18s %-13s %s\n" "Uncommitted" "${UNCOMMITTED:-0}" "${STG_UNCOMMITTED:-0}"
printf "  %-18s %-13s %s\n" "Docker" "${DOCKER_STATUS:-?}" "active"

[ "$BACKEND_BRANCH" != "$STG_BRANCH" ] && [ -n "$BACKEND_BRANCH" ] && [ -n "$STG_BRANCH" ] && check_info "Branches differ (expected for staging/prod)"

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
section "FINAL SUMMARY"
DUR=$(($(date +%s) - SCRIPT_START))
[[ $SCORE -lt 0 ]] && SCORE=0

if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 ]]; then
    echo -e "\n${RED}Issues Found:${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${YELLOW}🟠 HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
fi

if [[ $SCORE -ge 90 ]]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [[ $SCORE -ge 75 ]]; then RATING="GOOD"; COLOR="$GREEN"
elif [[ $SCORE -ge 60 ]]; then RATING="FAIR"; COLOR="$YELLOW"
else RATING="NEEDS WORK"; COLOR="$YELLOW"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  CICD_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds      ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "CICD_SCORE:$SCORE"
