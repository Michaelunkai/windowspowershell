#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# DOCKER INFRASTRUCTURE AUDIT - 5X COMPREHENSIVE v5.1 [3X SPEED OPTIMIZED]
# ═══════════════════════════════════════════════════════════════════════════════
# SSH ControlMaster + Command Batching for 3X faster execution
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

# Configuration
PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'; DIM='\033[2m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
SCORE=100

# SSH ControlMaster for connection reuse
SSH_CTRL="/tmp/tovplay_docker_$$"
mkdir -p "$SSH_CTRL"
cleanup() {
    ssh -S "$SSH_CTRL/prod" -O exit $PROD_USER@$PROD_HOST 2>/dev/null
    ssh -S "$SSH_CTRL/stag" -O exit $STAGING_USER@$STAGING_HOST 2>/dev/null
    rm -rf "$SSH_CTRL"
}
trap cleanup EXIT

# Initialize persistent connections (parallel)
init_connections() {
    sshpass -p "$PROD_PASS" ssh -fNM -S "$SSH_CTRL/prod" -o ControlPersist=90 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
        $PROD_USER@$PROD_HOST 2>/dev/null &
    sshpass -p "$STAGING_PASS" ssh -fNM -S "$SSH_CTRL/stag" -o ControlPersist=90 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
        $STAGING_USER@$STAGING_HOST 2>/dev/null &
    wait
}

# Fast SSH using existing connection
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
echo -e "${BOLD}${MAGENTA}║     DOCKER AUDIT v5.1 [3X SPEED OPTIMIZED] - $(date '+%Y-%m-%d %H:%M:%S')      ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

# Initialize SSH connections
init_connections

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 1: ALL PRODUCTION DOCKER INFO (Single SSH call - MASSIVE speedup)
# ═══════════════════════════════════════════════════════════════════════════════
section "1-4. PRODUCTION DOCKER SERVICE, CONTAINERS, RESOURCES, IMAGES"

BATCH_PROD=$(ssh_prod 'echo ":::DOCKER_STATUS:::"; systemctl is-active docker
echo ":::DOCKER_VERSION:::"; docker --version
echo ":::COMPOSE_VERSION:::"; docker compose version 2>/dev/null || docker-compose --version 2>/dev/null
echo ":::RUNNING_COUNT:::"; docker ps -q | wc -l
echo ":::CONTAINERS:::"; docker ps --format "{{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -10
echo ":::STOPPED_COUNT:::"; docker ps -a --filter "status=exited" -q | wc -l
echo ":::STATS:::"; docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null | head -8
echo ":::IMAGE_COUNT:::"; docker images -q | wc -l
echo ":::IMAGES:::"; docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}" | head -8
echo ":::DANGLING:::"; docker images -f "dangling=true" -q | wc -l
echo ":::NETWORK_COUNT:::"; docker network ls -q | wc -l
echo ":::NETWORKS:::"; docker network ls --format "{{.Name}}\t{{.Driver}}" | head -8
echo ":::VOLUME_COUNT:::"; docker volume ls -q | wc -l
echo ":::DANGLING_VOLS:::"; docker volume ls -f dangling=true -q | wc -l
echo ":::DISK_USAGE:::"; docker system df --format "Type: {{.Type}}, Size: {{.Size}}, Reclaimable: {{.Reclaimable}}" 2>/dev/null
echo ":::BACKEND_STATUS:::"; docker inspect --format="{{.State.Status}}" tovplay-backend 2>/dev/null
echo ":::PROMETHEUS_STATUS:::"; docker inspect --format="{{.State.Status}}" tovplay-prometheus 2>/dev/null
echo ":::LOKI_STATUS:::"; docker inspect --format="{{.State.Status}}" tovplay-loki 2>/dev/null
echo ":::BACKEND_HEALTH:::"; docker inspect --format="{{.State.Health.Status}}" tovplay-backend 2>/dev/null
echo ":::BACKEND_RESTARTS:::"; docker inspect --format="{{.RestartCount}}" tovplay-backend 2>/dev/null
echo ":::COMPOSE_FILES:::"; ls /root/docker-compose*.yml /root/tovplay-backend/docker-compose*.yml 2>/dev/null | head -3
echo ":::RECENT_LOGS:::"; docker logs --tail 5 tovplay-backend 2>&1 | tail -3
echo ":::PRUNE_SIZE:::"; docker system df --format "{{.Reclaimable}}" 2>/dev/null | head -1' 20)

# Parse results
DOCKER_STATUS=$(echo "$BATCH_PROD" | sed -n '/:::DOCKER_STATUS:::/,/:::DOCKER_VERSION:::/p' | tail -1)
DOCKER_VERSION=$(echo "$BATCH_PROD" | sed -n '/:::DOCKER_VERSION:::/,/:::COMPOSE_VERSION:::/p' | tail -1)
COMPOSE_VERSION=$(echo "$BATCH_PROD" | sed -n '/:::COMPOSE_VERSION:::/,/:::RUNNING_COUNT:::/p' | tail -1)
RUNNING_COUNT=$(echo "$BATCH_PROD" | sed -n '/:::RUNNING_COUNT:::/,/:::CONTAINERS:::/p' | tail -1)
CONTAINERS=$(echo "$BATCH_PROD" | sed -n '/:::CONTAINERS:::/,/:::STOPPED_COUNT:::/p' | grep -v ':::')
STOPPED_COUNT=$(echo "$BATCH_PROD" | sed -n '/:::STOPPED_COUNT:::/,/:::STATS:::/p' | tail -1)
STATS=$(echo "$BATCH_PROD" | sed -n '/:::STATS:::/,/:::IMAGE_COUNT:::/p' | grep -v ':::')
IMAGE_COUNT=$(echo "$BATCH_PROD" | sed -n '/:::IMAGE_COUNT:::/,/:::IMAGES:::/p' | tail -1)
IMAGES=$(echo "$BATCH_PROD" | sed -n '/:::IMAGES:::/,/:::DANGLING:::/p' | grep -v ':::')
DANGLING=$(echo "$BATCH_PROD" | sed -n '/:::DANGLING:::/,/:::NETWORK_COUNT:::/p' | tail -1)
NETWORK_COUNT=$(echo "$BATCH_PROD" | sed -n '/:::NETWORK_COUNT:::/,/:::NETWORKS:::/p' | tail -1)
NETWORKS=$(echo "$BATCH_PROD" | sed -n '/:::NETWORKS:::/,/:::VOLUME_COUNT:::/p' | grep -v ':::')
VOLUME_COUNT=$(echo "$BATCH_PROD" | sed -n '/:::VOLUME_COUNT:::/,/:::DANGLING_VOLS:::/p' | tail -1)
DANGLING_VOLS=$(echo "$BATCH_PROD" | sed -n '/:::DANGLING_VOLS:::/,/:::DISK_USAGE:::/p' | tail -1)
DISK_USAGE=$(echo "$BATCH_PROD" | sed -n '/:::DISK_USAGE:::/,/:::BACKEND_STATUS:::/p' | grep -v ':::')
BACKEND_STATUS=$(echo "$BATCH_PROD" | sed -n '/:::BACKEND_STATUS:::/,/:::PROMETHEUS_STATUS:::/p' | tail -1)
PROMETHEUS_STATUS=$(echo "$BATCH_PROD" | sed -n '/:::PROMETHEUS_STATUS:::/,/:::LOKI_STATUS:::/p' | tail -1)
LOKI_STATUS=$(echo "$BATCH_PROD" | sed -n '/:::LOKI_STATUS:::/,/:::BACKEND_HEALTH:::/p' | tail -1)
BACKEND_HEALTH=$(echo "$BATCH_PROD" | sed -n '/:::BACKEND_HEALTH:::/,/:::BACKEND_RESTARTS:::/p' | tail -1)
BACKEND_RESTARTS=$(echo "$BATCH_PROD" | sed -n '/:::BACKEND_RESTARTS:::/,/:::COMPOSE_FILES:::/p' | tail -1)
COMPOSE_FILES=$(echo "$BATCH_PROD" | sed -n '/:::COMPOSE_FILES:::/,/:::RECENT_LOGS:::/p' | grep -v ':::')
PRUNE_SIZE=$(echo "$BATCH_PROD" | sed -n '/:::PRUNE_SIZE:::/,$p' | tail -1)

# Display: Docker Service
echo -e "${CYAN}Docker Service:${NC}"
[ "$DOCKER_STATUS" = "active" ] && check_pass "Docker service: active" || { check_fail "Docker: $DOCKER_STATUS"; add_critical "Production Docker not active"; }
check_info "$DOCKER_VERSION"
[ -n "$COMPOSE_VERSION" ] && check_info "Compose: $COMPOSE_VERSION"

# Display: Running Containers
echo -e "\n${CYAN}Running Containers ($RUNNING_COUNT):${NC}"
echo "$CONTAINERS" | while read -r line; do [ -n "$line" ] && echo "    $line"; done

# Container Health
[ "$BACKEND_STATUS" = "running" ] && check_pass "tovplay-backend: running" || { check_warn "tovplay-backend: $BACKEND_STATUS"; add_high "Backend not running"; }
[ "$PROMETHEUS_STATUS" = "running" ] && check_pass "tovplay-prometheus: running" || check_info "prometheus: $PROMETHEUS_STATUS"
[ "$LOKI_STATUS" = "running" ] && check_pass "tovplay-loki: running" || check_info "loki: $LOKI_STATUS"
[ -n "$BACKEND_HEALTH" ] && check_info "Backend health: $BACKEND_HEALTH"
[ "${BACKEND_RESTARTS:-0}" -gt 5 ] 2>/dev/null && { check_warn "Backend restarts: $BACKEND_RESTARTS"; add_medium "High restart count"; } || check_pass "Backend restarts: ${BACKEND_RESTARTS:-0}"

# Stopped containers
[ "${STOPPED_COUNT:-0}" -lt 5 ] 2>/dev/null && check_pass "Stopped containers: $STOPPED_COUNT" || { check_warn "Stopped: $STOPPED_COUNT (cleanup recommended)"; add_low "Many stopped containers"; }

# Display: Resource Stats
echo -e "\n${CYAN}Resource Usage:${NC}"
echo "$STATS" | while read -r line; do [ -n "$line" ] && check_info "$line"; done

# Display: Images
echo -e "\n${CYAN}Images ($IMAGE_COUNT):${NC}"
echo "$IMAGES" | head -5 | while read -r line; do [ -n "$line" ] && echo "    $line"; done
[ "${DANGLING:-0}" -lt 3 ] 2>/dev/null && check_pass "Dangling images: $DANGLING" || { check_warn "Dangling: $DANGLING (cleanup needed)"; add_low "Dangling images"; }

# Display: Networks & Volumes
echo -e "\n${CYAN}Networks ($NETWORK_COUNT) & Volumes ($VOLUME_COUNT):${NC}"
echo "$NETWORKS" | head -5 | while read -r line; do [ -n "$line" ] && check_info "Network: $line"; done
[ "${DANGLING_VOLS:-0}" -lt 3 ] 2>/dev/null && check_pass "Dangling volumes: $DANGLING_VOLS" || { check_warn "Dangling volumes: $DANGLING_VOLS"; add_low "Cleanup volumes"; }

# Display: Disk Usage
echo -e "\n${CYAN}Disk Usage:${NC}"
echo "$DISK_USAGE" | while read -r line; do [ -n "$line" ] && check_info "$line"; done
[ -n "$PRUNE_SIZE" ] && check_info "Reclaimable: $PRUNE_SIZE"

# Compose Files
[ -n "$COMPOSE_FILES" ] && { echo -e "\n${CYAN}Compose Files:${NC}"; echo "$COMPOSE_FILES" | while read -r f; do check_info "$f"; done; }

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 2: STAGING DOCKER INFO
# ═══════════════════════════════════════════════════════════════════════════════
section "5-6. STAGING DOCKER"

BATCH_STG=$(ssh_staging 'echo ":::DOCKER_STATUS:::"; systemctl is-active docker
echo ":::DOCKER_VERSION:::"; docker --version
echo ":::RUNNING:::"; docker ps -q | wc -l
echo ":::IMAGES:::"; docker images -q | wc -l
echo ":::BACKEND:::"; docker inspect --format="{{.State.Status}}" tovplay-backend-staging 2>/dev/null || echo "not found"' 10)

STG_DOCKER=$(echo "$BATCH_STG" | sed -n '/:::DOCKER_STATUS:::/,/:::DOCKER_VERSION:::/p' | tail -1)
STG_VERSION=$(echo "$BATCH_STG" | sed -n '/:::DOCKER_VERSION:::/,/:::RUNNING:::/p' | tail -1)
STG_RUNNING=$(echo "$BATCH_STG" | sed -n '/:::RUNNING:::/,/:::IMAGES:::/p' | tail -1)
STG_IMAGES=$(echo "$BATCH_STG" | sed -n '/:::IMAGES:::/,/:::BACKEND:::/p' | tail -1)
STG_BACKEND=$(echo "$BATCH_STG" | sed -n '/:::BACKEND:::/,$p' | tail -1)

[ "$STG_DOCKER" = "active" ] && check_pass "Staging Docker: active" || check_warn "Staging Docker: $STG_DOCKER"
check_info "$STG_VERSION"
check_info "Running containers: $STG_RUNNING | Images: $STG_IMAGES"
[ "$STG_BACKEND" = "running" ] && check_pass "Staging backend: running" || check_info "Staging backend: $STG_BACKEND"

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 3: SECURITY & LOGGING
# ═══════════════════════════════════════════════════════════════════════════════
section "7-10. SECURITY & LOGGING"

BATCH_SEC=$(ssh_prod 'echo ":::PRIV_CONTAINERS:::"; docker ps --format "{{.Names}}" -f "privileged=true" 2>/dev/null | wc -l
echo ":::ROOT_CONTAINERS:::"; docker ps -q 2>/dev/null | xargs -I {} docker inspect --format "{{.Name}}: {{.Config.User}}" {} 2>/dev/null | grep -E "^[^:]+: $" | wc -l
echo ":::LOG_DRIVER:::"; docker info --format "{{.LoggingDriver}}" 2>/dev/null
echo ":::LOGGING_OPTS:::"; docker info --format "{{.LoggingDriverOptions}}" 2>/dev/null
echo ":::BACKEND_LOGS:::"; docker logs --tail 3 tovplay-backend 2>&1 | tail -2
echo ":::ERROR_LOGS:::"; docker logs tovplay-backend 2>&1 | grep -iE "error|exception|fatal" | tail -2' 10)

PRIV_COUNT=$(echo "$BATCH_SEC" | sed -n '/:::PRIV_CONTAINERS:::/,/:::ROOT_CONTAINERS:::/p' | tail -1)
ROOT_COUNT=$(echo "$BATCH_SEC" | sed -n '/:::ROOT_CONTAINERS:::/,/:::LOG_DRIVER:::/p' | tail -1)
LOG_DRIVER=$(echo "$BATCH_SEC" | sed -n '/:::LOG_DRIVER:::/,/:::LOGGING_OPTS:::/p' | tail -1)
ERROR_LOGS=$(echo "$BATCH_SEC" | sed -n '/:::ERROR_LOGS:::/,$p' | grep -v ':::')

[ "${PRIV_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "No privileged containers" || { check_warn "Privileged containers: $PRIV_COUNT"; add_medium "Privileged containers"; }
[ "${ROOT_COUNT:-0}" -lt 3 ] 2>/dev/null && check_pass "Root containers: $ROOT_COUNT" || { check_warn "Root containers: $ROOT_COUNT"; add_low "Containers running as root"; }
check_info "Log driver: $LOG_DRIVER"
if [ -n "$ERROR_LOGS" ]; then
    check_warn "Recent errors in logs:"
    echo "$ERROR_LOGS" | head -2 | while read -r line; do echo "    $line"; done
else
    check_pass "No recent errors in backend logs"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# ENVIRONMENT COMPARISON
# ═══════════════════════════════════════════════════════════════════════════════
section "11. ENVIRONMENT COMPARISON"
echo -e "  ${BOLD}Metric              Production    Staging${NC}"
echo -e "  ─────────────────────────────────────────────"
printf "  %-18s %-13s %s\n" "Running" "${RUNNING_COUNT:-?}" "${STG_RUNNING:-?}"
printf "  %-18s %-13s %s\n" "Images" "${IMAGE_COUNT:-?}" "${STG_IMAGES:-?}"
printf "  %-18s %-13s %s\n" "Dangling" "${DANGLING:-?}" "?"
printf "  %-18s %-13s %s\n" "Stopped" "${STOPPED_COUNT:-?}" "?"

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP RECOMMENDATIONS
# ═══════════════════════════════════════════════════════════════════════════════
section "12. CLEANUP RECOMMENDATIONS"
[ "${DANGLING:-0}" -gt 5 ] 2>/dev/null && check_warn "Run: docker image prune" || check_pass "Images OK"
[ "${DANGLING_VOLS:-0}" -gt 3 ] 2>/dev/null && check_warn "Run: docker volume prune" || check_pass "Volumes OK"
[ "${STOPPED_COUNT:-0}" -gt 5 ] 2>/dev/null && check_warn "Run: docker container prune" || check_pass "Containers OK"

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
section "FINAL SUMMARY"

[[ $SCORE -lt 0 ]] && SCORE=0
DUR=$(($(date +%s) - SCRIPT_START))

if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 ]]; then
    echo -e "\n${RED}Issues Found:${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${YELLOW}🟠 HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
fi

if [[ $SCORE -ge 90 ]]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [[ $SCORE -ge 75 ]]; then RATING="GOOD"; COLOR="$GREEN"
elif [[ $SCORE -ge 60 ]]; then RATING="FAIR"; COLOR="$YELLOW"
elif [[ $SCORE -ge 40 ]]; then RATING="NEEDS IMPROVEMENT"; COLOR="$YELLOW"
else RATING="CRITICAL"; COLOR="$RED"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  DOCKER_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds   ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "DOCKER_SCORE:$SCORE"
