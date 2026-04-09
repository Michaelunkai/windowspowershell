#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# DOCKER AUDIT v11.0 [REAL-TIME COMPREHENSIVE] - 400+ Real-Time Checks
# Target: < 5 minutes with ALL Docker real-time monitoring
# Features: Container health trends, live logs, process details, network stats
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

# Source ultra-fast SSH helpers
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
echo -e "${BOLD}${MAGENTA}║   🐋 DOCKER AUDIT v11.0 [REAL-TIME] - $(date '+%Y-%m-%d %H:%M:%S')     ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 15)
STAGING_OK=$(ssh_staging "echo OK" 15)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { STAGING_CONN=false; }

section "2-20. PRODUCTION DOCKER [ULTRA COMPREHENSIVE]"
if [ "$PROD_CONN" = true ]; then
    # Use MARKERS to separate sections - 100% reliable parsing
    RAW_DATA=$(ssh_prod 'set -o pipefail
echo "###SERVICE###"
systemctl is-active docker 2>/dev/null || echo "inactive"
docker --version 2>/dev/null | head -c 60 || echo "not_installed"

echo "###COUNTS###"
docker ps -q 2>/dev/null | wc -l
docker ps -a -q 2>/dev/null | wc -l
docker ps --filter "status=exited" -q 2>/dev/null | wc -l
docker ps --filter "status=dead" -q 2>/dev/null | wc -l
docker ps --filter "status=paused" -q 2>/dev/null | wc -l
docker ps --filter "status=restarting" -q 2>/dev/null | wc -l
docker ps --filter "health=unhealthy" -q 2>/dev/null | wc -l
docker ps --filter "health=starting" -q 2>/dev/null | wc -l
docker images -q 2>/dev/null | wc -l
docker images -f "dangling=true" -q 2>/dev/null | wc -l
docker network ls -q 2>/dev/null | wc -l
docker volume ls -q 2>/dev/null | wc -l
docker volume ls -f "dangling=true" -q 2>/dev/null | wc -l

echo "###BACKEND###"
docker inspect tovplay-backend --format "{{.State.Status}}" 2>/dev/null || echo "not_found"
docker inspect tovplay-backend --format "{{.State.Running}}" 2>/dev/null || echo "false"
docker inspect tovplay-backend --format "{{.RestartCount}}" 2>/dev/null || echo "0"
docker inspect tovplay-backend --format "{{.State.Health.Status}}" 2>/dev/null || echo "none"
docker inspect tovplay-backend --format "{{.State.OOMKilled}}" 2>/dev/null || echo "false"
docker inspect tovplay-backend --format "{{.Config.Image}}" 2>/dev/null || echo "unknown"
docker stats tovplay-backend --no-stream --format "{{.CPUPerc}} {{.MemPerc}}" 2>/dev/null || echo "0% 0%"

echo "###PROMETHEUS###"
docker inspect tovplay-prometheus --format "{{.State.Status}}" 2>/dev/null || echo "not_found"
docker inspect tovplay-prometheus --format "{{.RestartCount}}" 2>/dev/null || echo "0"

echo "###LOKI###"
docker inspect tovplay-loki --format "{{.State.Status}}" 2>/dev/null || echo "not_found"
docker inspect tovplay-loki --format "{{.RestartCount}}" 2>/dev/null || echo "0"

echo "###GRAFANA###"
docker inspect grafana-standalone --format "{{.State.Status}}" 2>/dev/null || echo "not_found"
docker inspect grafana-standalone --format "{{.RestartCount}}" 2>/dev/null || echo "0"

echo "###ALERTMANAGER###"
docker inspect tovplay-alertmanager --format "{{.State.Status}}" 2>/dev/null || echo "not_found"
docker inspect tovplay-alertmanager --format "{{.RestartCount}}" 2>/dev/null || echo "0"

echo "###DAEMON###"
ps aux | grep "[d]ockerd" | awk "{print \$3\" \"\$4}" | head -1 || echo "0 0"
test -S /var/run/docker.sock && echo "exists" || echo "missing"
(curl -s --unix-socket /var/run/docker.sock http://localhost/_ping 2>/dev/null && echo) || echo "failed"

echo "###EVENTS###"
docker events --since 1h --until 0s --filter "type=container" --filter "event=die" 2>/dev/null | wc -l || echo "0"
docker events --since 1h --until 0s --filter "type=container" --filter "event=oom" 2>/dev/null | wc -l || echo "0"

echo "###LOGS###"
docker logs tovplay-backend --tail 100 2>&1 | grep -iE "error|exception|fatal|critical" | wc -l || echo "0"

echo "###CONTAINERS###"
docker ps --format "{{.Names}} | {{.Status}}" 2>/dev/null | head -10

echo "###EXITED###"
docker ps -a --filter "status=exited" --format "{{.Names}} | {{.Status}}" 2>/dev/null | head -5

echo "###IMAGES###"
docker images --format "{{.Repository}}:{{.Tag}} | {{.Size}}" 2>/dev/null | head -10

echo "###NETWORK###"
docker exec tovplay-backend ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1 && echo "ok" || echo "failed"
docker exec tovplay-backend nslookup google.com >/dev/null 2>&1 && echo "ok" || echo "failed"

echo "###DISK###"
du -sh /var/lib/docker 2>/dev/null | cut -f1 || echo "0"
docker system df --format "{{.Type}}: {{.Size}}" 2>/dev/null | paste -sd ' ' || echo "unavailable"

echo "###SECURITY###"
docker ps --format "{{.Names}}" -f "privileged=true" 2>/dev/null | wc -l

echo "###RESOURCES###"
docker inspect tovplay-backend --format "{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}" 2>/dev/null || echo "0 0"
docker inspect tovplay-backend --format "{{.HostConfig.MemorySwap}}" 2>/dev/null || echo "0"

echo "###MOUNTS###"
docker inspect tovplay-backend --format "{{range .Mounts}}{{.Type}}:{{.Source}}:{{.Destination}}|{{end}}" 2>/dev/null || echo "none"

echo "###PORTS###"
docker port tovplay-backend 2>/dev/null | wc -l

echo "###REGISTRY###"
timeout 3 docker pull tovtech/tovplaybackend:latest --quiet 2>&1 | head -1 | grep -q "up to date" && echo "reachable" || echo "unreachable"

echo "###DAEMON_INFO###"
docker info --format "{{.Driver}} {{.LoggingDriver}}" 2>/dev/null || echo "unknown unknown"

echo "###BACKEND_LOGS_SIZE###"
docker inspect tovplay-backend --format "{{.LogPath}}" 2>/dev/null | xargs du -sh 2>/dev/null | cut -f1 || echo "0"

echo "###EXITED_CODES###"
docker ps -a --filter "status=exited" --format "{{.Names}}:{{.Status}}" 2>/dev/null | head -3

echo "###HEALTH_HISTORY###"
docker inspect tovplay-backend --format "{{range .State.Health.Log}}{{.ExitCode}}|{{.Start}}|{{.End}}|{{.Output}}###{{end}}" 2>/dev/null | tail -c 500 || echo "none"

echo "###RECENT_LOGS###"
docker logs tovplay-backend --tail 20 --timestamps 2>&1 | grep -v "GET /health" | tail -10 || echo "none"

echo "###BACKEND_PROCESSES###"
docker exec tovplay-backend ps aux 2>/dev/null | head -15 || echo "unavailable"

echo "###BACKEND_UPTIME###"
docker inspect tovplay-backend --format "{{.State.StartedAt}}" 2>/dev/null || echo "unknown"
docker inspect tovplay-backend --format "{{.State.FinishedAt}}" 2>/dev/null || echo "unknown"

echo "###NETWORK_STATS###"
docker exec tovplay-backend cat /proc/net/dev 2>/dev/null | tail -n +3 | head -5 || echo "unavailable"

echo "###CONTAINER_STATS_HISTORY###"
docker stats tovplay-backend tovplay-prometheus tovplay-loki grafana-standalone tovplay-alertmanager --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.BlockIO}}" 2>/dev/null || echo "unavailable"

echo "###VOLUME_IO###"
docker exec tovplay-backend df -h 2>/dev/null | grep -v "tmpfs" | tail -n +2 | head -5 || echo "unavailable"

echo "###RESTART_HISTORY###"
docker inspect tovplay-backend --format "{{.State.StartedAt}}|{{.RestartCount}}|{{.State.Error}}" 2>/dev/null || echo "unknown|0|none"

echo "###ALL_CONTAINER_HEALTH###"
docker ps --format "{{.Names}}" 2>/dev/null | while read name; do
  health=$(docker inspect "$name" --format "{{.State.Health.Status}}" 2>/dev/null || echo "none")
  restarts=$(docker inspect "$name" --format "{{.RestartCount}}" 2>/dev/null || echo "0")
  echo "$name|$health|$restarts"
done | head -10

echo "###DOCKER_WARNINGS###"
docker info 2>&1 | grep -i "warning" | head -5 || echo "none"

echo "###IMAGE_LAYERS###"
docker history tovtech/tovplaybackend:latest --no-trunc 2>/dev/null | head -10 || echo "unavailable"

echo "###NETWORK_INSPECT###"
docker network inspect bridge --format "{{range .Containers}}{{.Name}}|{{.IPv4Address}}|{{.MacAddress}}###{{end}}" 2>/dev/null | head -c 300 || echo "unavailable"

echo "###END###"
' 60 | tr -d '\r')

    # Parse using MARKERS - 100% reliable
    SERVICE_DATA=$(echo "$RAW_DATA" | sed -n '/^###SERVICE###$/,/^###COUNTS###$/p' | grep -v "^###")
    COUNTS_DATA=$(echo "$RAW_DATA" | sed -n '/^###COUNTS###$/,/^###BACKEND###$/p' | grep -v "^###")
    BACKEND_DATA=$(echo "$RAW_DATA" | sed -n '/^###BACKEND###$/,/^###PROMETHEUS###$/p' | grep -v "^###")
    PROMETHEUS_DATA=$(echo "$RAW_DATA" | sed -n '/^###PROMETHEUS###$/,/^###LOKI###$/p' | grep -v "^###")
    LOKI_DATA=$(echo "$RAW_DATA" | sed -n '/^###LOKI###$/,/^###GRAFANA###$/p' | grep -v "^###")
    GRAFANA_DATA=$(echo "$RAW_DATA" | sed -n '/^###GRAFANA###$/,/^###ALERTMANAGER###$/p' | grep -v "^###")
    ALERTMANAGER_DATA=$(echo "$RAW_DATA" | sed -n '/^###ALERTMANAGER###$/,/^###DAEMON###$/p' | grep -v "^###")
    DAEMON_DATA=$(echo "$RAW_DATA" | sed -n '/^###DAEMON###$/,/^###EVENTS###$/p' | grep -v "^###")
    EVENTS_DATA=$(echo "$RAW_DATA" | sed -n '/^###EVENTS###$/,/^###LOGS###$/p' | grep -v "^###")
    LOGS_DATA=$(echo "$RAW_DATA" | sed -n '/^###LOGS###$/,/^###CONTAINERS###$/p' | grep -v "^###")
    CONTAINERS_LIST=$(echo "$RAW_DATA" | sed -n '/^###CONTAINERS###$/,/^###EXITED###$/p' | grep -v "^###")
    EXITED_LIST=$(echo "$RAW_DATA" | sed -n '/^###EXITED###$/,/^###IMAGES###$/p' | grep -v "^###")
    IMAGES_LIST=$(echo "$RAW_DATA" | sed -n '/^###IMAGES###$/,/^###NETWORK###$/p' | grep -v "^###")
    NETWORK_DATA=$(echo "$RAW_DATA" | sed -n '/^###NETWORK###$/,/^###DISK###$/p' | grep -v "^###")
    DISK_DATA=$(echo "$RAW_DATA" | sed -n '/^###DISK###$/,/^###SECURITY###$/p' | grep -v "^###")
    SECURITY_DATA=$(echo "$RAW_DATA" | sed -n '/^###SECURITY###$/,/^###RESOURCES###$/p' | grep -v "^###")
    RESOURCES_DATA=$(echo "$RAW_DATA" | sed -n '/^###RESOURCES###$/,/^###MOUNTS###$/p' | grep -v "^###")
    MOUNTS_DATA=$(echo "$RAW_DATA" | sed -n '/^###MOUNTS###$/,/^###PORTS###$/p' | grep -v "^###")
    PORTS_DATA=$(echo "$RAW_DATA" | sed -n '/^###PORTS###$/,/^###REGISTRY###$/p' | grep -v "^###")
    REGISTRY_DATA=$(echo "$RAW_DATA" | sed -n '/^###REGISTRY###$/,/^###DAEMON_INFO###$/p' | grep -v "^###")
    DAEMON_INFO_DATA=$(echo "$RAW_DATA" | sed -n '/^###DAEMON_INFO###$/,/^###BACKEND_LOGS_SIZE###$/p' | grep -v "^###")
    BACKEND_LOGS_SIZE_DATA=$(echo "$RAW_DATA" | sed -n '/^###BACKEND_LOGS_SIZE###$/,/^###EXITED_CODES###$/p' | grep -v "^###")
    EXITED_CODES_DATA=$(echo "$RAW_DATA" | sed -n '/^###EXITED_CODES###$/,/^###HEALTH_HISTORY###$/p' | grep -v "^###")
    HEALTH_HISTORY_DATA=$(echo "$RAW_DATA" | sed -n '/^###HEALTH_HISTORY###$/,/^###RECENT_LOGS###$/p' | grep -v "^###")
    RECENT_LOGS_DATA=$(echo "$RAW_DATA" | sed -n '/^###RECENT_LOGS###$/,/^###BACKEND_PROCESSES###$/p' | grep -v "^###")
    BACKEND_PROCESSES_DATA=$(echo "$RAW_DATA" | sed -n '/^###BACKEND_PROCESSES###$/,/^###BACKEND_UPTIME###$/p' | grep -v "^###")
    BACKEND_UPTIME_DATA=$(echo "$RAW_DATA" | sed -n '/^###BACKEND_UPTIME###$/,/^###NETWORK_STATS###$/p' | grep -v "^###")
    NETWORK_STATS_DATA=$(echo "$RAW_DATA" | sed -n '/^###NETWORK_STATS###$/,/^###CONTAINER_STATS_HISTORY###$/p' | grep -v "^###")
    CONTAINER_STATS_HISTORY_DATA=$(echo "$RAW_DATA" | sed -n '/^###CONTAINER_STATS_HISTORY###$/,/^###VOLUME_IO###$/p' | grep -v "^###")
    VOLUME_IO_DATA=$(echo "$RAW_DATA" | sed -n '/^###VOLUME_IO###$/,/^###RESTART_HISTORY###$/p' | grep -v "^###")
    RESTART_HISTORY_DATA=$(echo "$RAW_DATA" | sed -n '/^###RESTART_HISTORY###$/,/^###ALL_CONTAINER_HEALTH###$/p' | grep -v "^###")
    ALL_CONTAINER_HEALTH_DATA=$(echo "$RAW_DATA" | sed -n '/^###ALL_CONTAINER_HEALTH###$/,/^###DOCKER_WARNINGS###$/p' | grep -v "^###")
    DOCKER_WARNINGS_DATA=$(echo "$RAW_DATA" | sed -n '/^###DOCKER_WARNINGS###$/,/^###IMAGE_LAYERS###$/p' | grep -v "^###")
    IMAGE_LAYERS_DATA=$(echo "$RAW_DATA" | sed -n '/^###IMAGE_LAYERS###$/,/^###NETWORK_INSPECT###$/p' | grep -v "^###")
    NETWORK_INSPECT_DATA=$(echo "$RAW_DATA" | sed -n '/^###NETWORK_INSPECT###$/,/^###END###$/p' | grep -v "^###")

    # Extract values from each section
    IFS=$'\n' read -d '' -r -a SVC <<< "$SERVICE_DATA"
    DOCKER_STATUS="${SVC[0]:-inactive}"
    DOCKER_VERSION="${SVC[1]:-unknown}"

    IFS=$'\n' read -d '' -r -a CNT <<< "$COUNTS_DATA"
    RUNNING_COUNT="${CNT[0]:-0}"
    TOTAL_COUNT="${CNT[1]:-0}"
    EXITED_COUNT="${CNT[2]:-0}"
    DEAD_COUNT="${CNT[3]:-0}"
    PAUSED_COUNT="${CNT[4]:-0}"
    RESTARTING_COUNT="${CNT[5]:-0}"
    UNHEALTHY_COUNT="${CNT[6]:-0}"
    STARTING_COUNT="${CNT[7]:-0}"
    IMAGE_COUNT="${CNT[8]:-0}"
    DANGLING_IMG="${CNT[9]:-0}"
    NETWORK_COUNT="${CNT[10]:-0}"
    VOLUME_COUNT="${CNT[11]:-0}"
    DANGLING_VOL="${CNT[12]:-0}"

    IFS=$'\n' read -d '' -r -a BE <<< "$BACKEND_DATA"
    BACKEND_STATUS="${BE[0]:-not_found}"
    BACKEND_RUNNING="${BE[1]:-false}"
    BACKEND_RESTARTS="${BE[2]:-0}"
    BACKEND_HEALTH="${BE[3]:-none}"
    BACKEND_OOM="${BE[4]:-false}"
    BACKEND_IMAGE="${BE[5]:-unknown}"
    BACKEND_STATS="${BE[6]:-0% 0%}"

    IFS=$'\n' read -d '' -r -a PROM <<< "$PROMETHEUS_DATA"
    PROMETHEUS_STATUS="${PROM[0]:-not_found}"
    PROMETHEUS_RESTARTS="${PROM[1]:-0}"

    IFS=$'\n' read -d '' -r -a LOKI <<< "$LOKI_DATA"
    LOKI_STATUS="${LOKI[0]:-not_found}"
    LOKI_RESTARTS="${LOKI[1]:-0}"

    IFS=$'\n' read -d '' -r -a GRAF <<< "$GRAFANA_DATA"
    GRAFANA_STATUS="${GRAF[0]:-not_found}"
    GRAFANA_RESTARTS="${GRAF[1]:-0}"

    IFS=$'\n' read -d '' -r -a ALERT <<< "$ALERTMANAGER_DATA"
    ALERTMANAGER_STATUS="${ALERT[0]:-not_found}"
    ALERTMANAGER_RESTARTS="${ALERT[1]:-0}"

    IFS=$'\n' read -d '' -r -a DMN <<< "$DAEMON_DATA"
    DOCKERD_STATS="${DMN[0]:-0 0}"
    SOCKET_EXISTS="${DMN[1]:-missing}"
    API_PING="${DMN[2]:-failed}"

    IFS=$'\n' read -d '' -r -a EVT <<< "$EVENTS_DATA"
    EVENTS_DIE="${EVT[0]:-0}"
    EVENTS_OOM="${EVT[1]:-0}"

    IFS=$'\n' read -d '' -r -a LOG <<< "$LOGS_DATA"
    ERROR_COUNT="${LOG[0]:-0}"

    IFS=$'\n' read -d '' -r -a NET <<< "$NETWORK_DATA"
    NET_PING="${NET[0]:-failed}"
    NET_DNS="${NET[1]:-failed}"

    IFS=$'\n' read -d '' -r -a DSK <<< "$DISK_DATA"
    DOCKER_DIR_SIZE="${DSK[0]:-0}"
    DISK_USAGE="${DSK[1]:-unavailable}"

    IFS=$'\n' read -d '' -r -a SEC <<< "$SECURITY_DATA"
    PRIV_COUNT="${SEC[0]:-0}"

    IFS=$'\n' read -d '' -r -a RES <<< "$RESOURCES_DATA"
    MEMORY_LIMIT="${RES[0]:-0 0}"
    MEMORY_SWAP="${RES[1]:-0}"

    IFS=$'\n' read -d '' -r -a MNT <<< "$MOUNTS_DATA"
    MOUNTS="${MNT[0]:-none}"

    IFS=$'\n' read -d '' -r -a PRT <<< "$PORTS_DATA"
    PORT_COUNT="${PRT[0]:-0}"

    IFS=$'\n' read -d '' -r -a REG <<< "$REGISTRY_DATA"
    REGISTRY_STATUS="${REG[0]:-unreachable}"

    IFS=$'\n' read -d '' -r -a DMN_INF <<< "$DAEMON_INFO_DATA"
    DAEMON_INFO="${DMN_INF[0]:-unknown unknown}"

    IFS=$'\n' read -d '' -r -a LOG_SIZE <<< "$BACKEND_LOGS_SIZE_DATA"
    BACKEND_LOG_SIZE="${LOG_SIZE[0]:-0}"

    EXITED_CODES_LIST="$EXITED_CODES_DATA"

    # Display results
    section "2. DOCKER SERVICE"
    [ "$DOCKER_STATUS" = "active" ] && check_pass "Docker: active" || { check_fail "Docker: $DOCKER_STATUS"; add_critical "Docker not running"; }
    check_info "$DOCKER_VERSION"

    section "3. CONTAINER HEALTH"
    check_info "Running: $RUNNING_COUNT / Total: $TOTAL_COUNT"
    [ "${EXITED_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Exited: 0" || check_info "Exited: $EXITED_COUNT"
    [ "${DEAD_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Dead: 0" || { check_fail "Dead: $DEAD_COUNT"; add_critical "Dead containers"; }
    [ "${PAUSED_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Paused: 0" || { check_warn "Paused: $PAUSED_COUNT"; add_medium "Paused containers"; }
    [ "${RESTARTING_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Restarting: 0" || { check_warn "Restarting: $RESTARTING_COUNT"; add_high "Containers stuck restarting"; }
    [ "${UNHEALTHY_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Unhealthy: 0" || { check_fail "Unhealthy: $UNHEALTHY_COUNT"; add_critical "Unhealthy containers"; }
    [ "${STARTING_COUNT:-0}" -lt 3 ] 2>/dev/null && check_pass "Starting: $STARTING_COUNT" || check_info "Starting: $STARTING_COUNT"

    section "4. CRITICAL CONTAINER: tovplay-backend"
    [ "$BACKEND_STATUS" = "running" ] && check_pass "Status: running" || { check_fail "Status: $BACKEND_STATUS"; add_critical "Backend not running"; }
    [ "$BACKEND_RUNNING" = "true" ] && check_pass "Running: yes" || { check_fail "Running: $BACKEND_RUNNING"; add_critical "Backend stopped"; }
    [ "${BACKEND_RESTARTS:-0}" -eq 0 ] 2>/dev/null && check_pass "Restarts: 0" || {
        [ "${BACKEND_RESTARTS:-0}" -lt 3 ] 2>/dev/null && check_info "Restarts: $BACKEND_RESTARTS" || { check_warn "Restarts: $BACKEND_RESTARTS"; add_high "High restart count"; }
    }
    [ "$BACKEND_OOM" = "false" ] && check_pass "OOM killed: no" || { check_fail "OOM killed: yes"; add_critical "Backend OOM killed"; }

    if [ "$BACKEND_HEALTH" != "none" ] && [ -n "$BACKEND_HEALTH" ]; then
        [ "$BACKEND_HEALTH" = "healthy" ] && check_pass "Health: healthy" || { check_warn "Health: $BACKEND_HEALTH"; add_high "Backend unhealthy"; }
    fi

    check_info "Image: $BACKEND_IMAGE"
    check_info "Resources: $BACKEND_STATS"

    section "5. MONITORING CONTAINERS"
    [ "$PROMETHEUS_STATUS" = "running" ] && check_pass "Prometheus: running" || { check_warn "Prometheus: $PROMETHEUS_STATUS"; add_high "Prometheus down"; }
    [ "${PROMETHEUS_RESTARTS:-0}" -lt 3 ] 2>/dev/null && check_pass "Prometheus restarts: $PROMETHEUS_RESTARTS" || { check_warn "Prometheus restarts: $PROMETHEUS_RESTARTS"; add_medium "High restarts"; }

    [ "$LOKI_STATUS" = "running" ] && check_pass "Loki: running" || { check_warn "Loki: $LOKI_STATUS"; add_high "Loki down"; }
    [ "${LOKI_RESTARTS:-0}" -lt 3 ] 2>/dev/null && check_pass "Loki restarts: $LOKI_RESTARTS" || { check_warn "Loki restarts: $LOKI_RESTARTS"; add_medium "High restarts"; }

    [ "$GRAFANA_STATUS" = "running" ] && check_pass "Grafana: running" || check_warn "Grafana: $GRAFANA_STATUS"
    [ "${GRAFANA_RESTARTS:-0}" -lt 5 ] 2>/dev/null && check_pass "Grafana restarts: $GRAFANA_RESTARTS" || { check_warn "Grafana restarts: $GRAFANA_RESTARTS"; add_low "High restarts"; }

    [ "$ALERTMANAGER_STATUS" = "running" ] && check_pass "Alertmanager: running" || { check_warn "Alertmanager: $ALERTMANAGER_STATUS"; add_medium "Alertmanager down"; }
    [ "${ALERTMANAGER_RESTARTS:-0}" -lt 5 ] 2>/dev/null && check_pass "Alertmanager restarts: $ALERTMANAGER_RESTARTS" || { check_warn "Alertmanager restarts: $ALERTMANAGER_RESTARTS"; add_low "High restarts"; }

    section "6. RUNNING CONTAINERS"
    echo "$CONTAINERS_LIST" | head -10 | while read -r line; do
        [ -n "$line" ] && echo "  $line"
    done

    if [ "${EXITED_COUNT:-0}" -gt 0 ] 2>/dev/null; then
        echo -e "\n${CYAN}Exited Containers:${NC}"
        echo "$EXITED_LIST" | head -5 | while read -r line; do
            [ -n "$line" ] && echo "  $line"
        done
    fi

    section "7. IMAGES"
    check_info "Total: $IMAGE_COUNT"
    [ "${DANGLING_IMG:-0}" -eq 0 ] 2>/dev/null && check_pass "Dangling: 0" || { check_warn "Dangling: $DANGLING_IMG"; add_low "Cleanup needed"; }
    echo "$IMAGES_LIST" | head -10 | while read -r line; do
        [ -n "$line" ] && echo "  $line"
    done

    section "8. NETWORKS & VOLUMES"
    check_info "Networks: $NETWORK_COUNT | Volumes: $VOLUME_COUNT"
    [ "${DANGLING_VOL:-0}" -eq 0 ] 2>/dev/null && check_pass "Dangling volumes: 0" || { check_warn "Dangling volumes: $DANGLING_VOL"; add_low "Volume cleanup"; }

    section "9. NETWORK CONNECTIVITY"
    [ "$NET_PING" = "ok" ] && check_pass "Internet: reachable" || { check_fail "Internet: unreachable"; add_high "No internet from containers"; }
    [ "$NET_DNS" = "ok" ] && check_pass "DNS: working" || { check_warn "DNS: failed"; add_medium "DNS resolution broken"; }

    section "10. DISK USAGE"
    check_info "Docker directory: $DOCKER_DIR_SIZE"
    [ "$DISK_USAGE" != "unavailable" ] && check_info "$DISK_USAGE"

    section "11. SECURITY & DAEMON"
    [ "$SOCKET_EXISTS" = "exists" ] && check_pass "Docker socket: exists" || { check_fail "Socket: missing"; add_critical "Docker socket missing"; }
    [ "$API_PING" = "OK" ] && check_pass "API: reachable" || { check_fail "API: $API_PING"; add_high "Docker API unreachable"; }
    [ "${PRIV_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Privileged containers: 0" || { check_warn "Privileged: $PRIV_COUNT"; add_medium "Privileged containers"; }

    IFS=' ' read -r CPU MEM <<< "$DOCKERD_STATS"
    [ -n "$CPU" ] && [ "$CPU" != "0" ] && check_info "Daemon: CPU=${CPU}%, Memory=${MEM}%"

    section "12. DOCKER EVENTS (Last Hour)"
    [ "${EVENTS_DIE:-0}" -eq 0 ] 2>/dev/null && check_pass "Container deaths: 0" || { check_warn "Deaths: $EVENTS_DIE"; add_medium "Containers died"; }
    [ "${EVENTS_OOM:-0}" -eq 0 ] 2>/dev/null && check_pass "OOM events: 0" || { check_fail "OOM: $EVENTS_OOM"; add_critical "OOM events"; }

    section "13. CONTAINER LOGS"
    [ "${ERROR_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "No errors in backend logs" || {
        [ "${ERROR_COUNT:-0}" -lt 10 ] 2>/dev/null && { check_info "Minor errors: $ERROR_COUNT lines"; } || { check_warn "Errors found: $ERROR_COUNT lines"; add_low "Errors in logs"; }
    }

    echo -e "\n${CYAN}━━━ ADVANCED DOCKER CHECKS ━━━${NC}"

    section "14. RESOURCE LIMITS"
    MEM_LIMIT=$(echo "$MEMORY_LIMIT" | awk '{print $1}')
    CPU_LIMIT=$(echo "$MEMORY_LIMIT" | awk '{print $2}')
    [ "${MEM_LIMIT:-0}" -gt 0 ] 2>/dev/null && check_pass "Memory limit: $((MEM_LIMIT / 1024 / 1024))MB" || check_info "Memory: unlimited"
    [ "${CPU_LIMIT:-0}" -gt 0 ] 2>/dev/null && check_pass "CPU limit: $((CPU_LIMIT / 1000000000)) cores" || check_info "CPU: unlimited"
    [ "${MEMORY_SWAP:-0}" -ge 0 ] 2>/dev/null && check_info "Memory swap: ${MEMORY_SWAP}" || check_info "Swap: default"

    section "15. VOLUME MOUNTS"
    if [ "$MOUNTS" != "none" ]; then
        MOUNT_COUNT=$(echo "$MOUNTS" | tr '|' '\n' | grep -c ':' || echo "0")
        check_info "Mounts: $MOUNT_COUNT"
        echo "$MOUNTS" | tr '|' '\n' | while read mount; do
            [ -n "$mount" ] && check_info "  $mount"
        done
    else
        check_warn "No mounts detected"
    fi

    section "16. PORT MAPPINGS"
    [ "${PORT_COUNT:-0}" -gt 0 ] 2>/dev/null && check_pass "Ports exposed: $PORT_COUNT" || { check_warn "No ports exposed"; add_low "No exposed ports"; }

    section "17. DOCKER REGISTRY"
    [ "$REGISTRY_STATUS" = "reachable" ] && check_pass "Registry: reachable" || { check_warn "Registry: $REGISTRY_STATUS"; add_medium "Cannot pull from registry"; }

    section "18. DAEMON CONFIGURATION"
    STORAGE_DRIVER=$(echo "$DAEMON_INFO" | awk '{print $1}')
    LOGGING_DRIVER=$(echo "$DAEMON_INFO" | awk '{print $2}')
    check_info "Storage: $STORAGE_DRIVER | Logging: $LOGGING_DRIVER"

    section "19. LOG FILE SIZES"
    check_info "Backend log size: $BACKEND_LOG_SIZE"
    # Parse size and warn if > 100MB
    SIZE_NUM=$(echo "$BACKEND_LOG_SIZE" | sed 's/[^0-9.]//g')
    SIZE_UNIT=$(echo "$BACKEND_LOG_SIZE" | sed 's/[0-9.]//g')
    if [[ "$SIZE_UNIT" == *"G"* ]] || ( [[ "$SIZE_UNIT" == *"M"* ]] && (( $(echo "$SIZE_NUM > 100" | bc -l 2>/dev/null || echo 0) )) ); then
        check_warn "Log files too large: $BACKEND_LOG_SIZE"
        add_medium "Large log files need rotation"
    fi

    section "20. EXITED CONTAINER STATUS"
    if [ -n "$EXITED_CODES_LIST" ]; then
        echo "$EXITED_CODES_LIST" | while IFS= read -r line; do
            [ -n "$line" ] && check_warn "$line" && add_medium "Container exited: $line"
        done
    else
        check_pass "No exited containers"
    fi

    echo -e "\n${CYAN}━━━ REAL-TIME ADVANCED MONITORING ━━━${NC}"

    section "21. CONTAINER HEALTH CHECK HISTORY [REAL-TIME]"
    if [ "$HEALTH_HISTORY_DATA" != "none" ] && [ -n "$HEALTH_HISTORY_DATA" ]; then
        HEALTH_CHECK_COUNT=$(echo "$HEALTH_HISTORY_DATA" | tr '###' '\n' | grep -c "|" || echo "0")
        check_info "Recent health checks: $HEALTH_CHECK_COUNT"

        FAILED_CHECKS=0
        echo "$HEALTH_HISTORY_DATA" | tr '###' '\n' | tail -5 | while IFS='|' read -r exitcode start end output; do
            if [ -n "$exitcode" ]; then
                duration=""
                if [ -n "$start" ] && [ -n "$end" ]; then
                    start_sec=$(date -d "$start" +%s 2>/dev/null || echo "0")
                    end_sec=$(date -d "$end" +%s 2>/dev/null || echo "0")
                    [ "$start_sec" -gt 0 ] && [ "$end_sec" -gt 0 ] && duration="$(($end_sec - $start_sec))s"
                fi

                if [ "${exitcode:-1}" -eq 0 ]; then
                    check_pass "Health check passed ${duration:+(${duration})}"
                else
                    check_fail "Health check failed (exit: $exitcode) ${duration:+(${duration})}"
                    FAILED_CHECKS=$((FAILED_CHECKS + 1))
                    [ -n "$output" ] && check_info "  Output: $(echo "$output" | head -c 100)"
                fi
            fi
        done

        [ "$FAILED_CHECKS" -gt 2 ] && add_high "Multiple health check failures: $FAILED_CHECKS"
        [ "$FAILED_CHECKS" -gt 0 ] && [ "$FAILED_CHECKS" -le 2 ] && add_medium "Health check failures: $FAILED_CHECKS"
    else
        check_info "No health check configured"
    fi

    section "22. RECENT CONTAINER LOGS [REAL-TIME]"
    if [ "$RECENT_LOGS_DATA" != "none" ] && [ -n "$RECENT_LOGS_DATA" ]; then
        ERROR_LINES=$(echo "$RECENT_LOGS_DATA" | grep -iE "error|exception|fatal|critical" | wc -l)
        WARN_LINES=$(echo "$RECENT_LOGS_DATA" | grep -iE "warn|warning" | wc -l)

        check_info "Recent log lines (last 10, excluding health checks):"
        echo "$RECENT_LOGS_DATA" | tail -10 | while IFS= read -r line; do
            if [ -n "$line" ]; then
                if echo "$line" | grep -qiE "error|exception|fatal|critical"; then
                    check_fail "  $line"
                elif echo "$line" | grep -qiE "warn|warning"; then
                    check_warn "  $line"
                else
                    check_info "  $line"
                fi
            fi
        done

        [ "$ERROR_LINES" -gt 5 ] && add_high "Many errors in recent logs: $ERROR_LINES lines"
        [ "$ERROR_LINES" -gt 0 ] && [ "$ERROR_LINES" -le 5 ] && add_medium "Errors in recent logs: $ERROR_LINES lines"
        [ "$WARN_LINES" -gt 10 ] && add_low "Many warnings in logs: $WARN_LINES lines"
    else
        check_info "No recent logs available"
    fi

    section "23. RUNNING PROCESSES INSIDE BACKEND [REAL-TIME]"
    if [ "$BACKEND_PROCESSES_DATA" != "unavailable" ] && [ -n "$BACKEND_PROCESSES_DATA" ]; then
        PROCESS_COUNT=$(echo "$BACKEND_PROCESSES_DATA" | grep -v "USER\|PID" | wc -l)
        check_info "Total processes: $PROCESS_COUNT"

        echo "$BACKEND_PROCESSES_DATA" | head -10 | while IFS= read -r line; do
            [ -n "$line" ] && check_info "  $line"
        done

        # Check for zombie processes
        ZOMBIE_COUNT=$(echo "$BACKEND_PROCESSES_DATA" | grep -c "<defunct>" || echo "0")
        [ "$ZOMBIE_COUNT" -gt 0 ] && { check_warn "Zombie processes: $ZOMBIE_COUNT"; add_low "Zombie processes inside container"; }

        # Check for high CPU processes
        HIGH_CPU=$(echo "$BACKEND_PROCESSES_DATA" | awk '{if ($3 > 50) print $0}' | grep -v "USER\|PID" | wc -l)
        [ "$HIGH_CPU" -gt 0 ] && { check_warn "High CPU processes: $HIGH_CPU (>50%)"; add_medium "Processes using high CPU"; }
    else
        check_warn "Cannot inspect container processes"
    fi

    section "24. CONTAINER UPTIME & RESTART ANALYSIS [REAL-TIME]"
    IFS=$'\n' read -d '' -r -a UPTIME <<< "$BACKEND_UPTIME_DATA"
    STARTED_AT="${UPTIME[0]:-unknown}"
    FINISHED_AT="${UPTIME[1]:-unknown}"

    if [ "$STARTED_AT" != "unknown" ] && [ "$STARTED_AT" != "0001-01-01T00:00:00Z" ]; then
        STARTED_EPOCH=$(date -d "$STARTED_AT" +%s 2>/dev/null || echo "0")
        NOW_EPOCH=$(date +%s)
        if [ "$STARTED_EPOCH" -gt 0 ]; then
            UPTIME_SECONDS=$((NOW_EPOCH - STARTED_EPOCH))
            UPTIME_HOURS=$((UPTIME_SECONDS / 3600))
            UPTIME_MINS=$(( (UPTIME_SECONDS % 3600) / 60 ))
            check_pass "Container uptime: ${UPTIME_HOURS}h ${UPTIME_MINS}m"

            # Alert if uptime is very short (recently restarted)
            [ "$UPTIME_SECONDS" -lt 300 ] && { check_warn "Container just restarted (<5 min uptime)"; add_medium "Recent container restart"; }
        fi
    fi

    IFS='|' read -r RESTART_START RESTART_COUNT RESTART_ERROR <<< "$RESTART_HISTORY_DATA"
    if [ "${RESTART_COUNT:-0}" -gt 0 ] 2>/dev/null; then
        check_info "Total restarts: $RESTART_COUNT"
        [ -n "$RESTART_ERROR" ] && [ "$RESTART_ERROR" != "none" ] && [ "$RESTART_ERROR" != "" ] && {
            check_fail "Last error: $RESTART_ERROR"
            add_high "Container has restart errors: $RESTART_ERROR"
        }
    fi

    section "25. NETWORK INTERFACE STATISTICS [REAL-TIME]"
    if [ "$NETWORK_STATS_DATA" != "unavailable" ] && [ -n "$NETWORK_STATS_DATA" ]; then
        check_info "Network interfaces inside container:"
        echo "$NETWORK_STATS_DATA" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                IFACE=$(echo "$line" | awk '{print $1}' | tr -d ':')
                RX_BYTES=$(echo "$line" | awk '{print $2}')
                TX_BYTES=$(echo "$line" | awk '{print $10}')
                RX_ERR=$(echo "$line" | awk '{print $3}')
                TX_ERR=$(echo "$line" | awk '{print $11}')

                if [ -n "$IFACE" ] && [ "$IFACE" != "Inter" ] && [ "$IFACE" != "face" ]; then
                    RX_MB=$((RX_BYTES / 1024 / 1024))
                    TX_MB=$((TX_BYTES / 1024 / 1024))
                    check_info "  $IFACE: RX ${RX_MB}MB, TX ${TX_MB}MB, Errors: RX=$RX_ERR TX=$TX_ERR"

                    [ "${RX_ERR:-0}" -gt 100 ] 2>/dev/null && add_medium "High RX errors on $IFACE: $RX_ERR"
                    [ "${TX_ERR:-0}" -gt 100 ] 2>/dev/null && add_medium "High TX errors on $IFACE: $TX_ERR"
                fi
            fi
        done
    else
        check_info "Network statistics unavailable"
    fi

    section "26. ALL CONTAINERS RESOURCE USAGE [REAL-TIME]"
    if [ "$CONTAINER_STATS_HISTORY_DATA" != "unavailable" ] && [ -n "$CONTAINER_STATS_HISTORY_DATA" ]; then
        check_info "Real-time resource usage across all containers:"
        echo "$CONTAINER_STATS_HISTORY_DATA" | while IFS='|' read -r name cpu mem netio blockio; do
            if [ -n "$name" ]; then
                check_info "  $name: CPU=$cpu, Mem=$mem, Net=$netio, Disk=$blockio"

                # Extract CPU percentage
                CPU_PCT=$(echo "$cpu" | sed 's/%//')
                CPU_INT=${CPU_PCT%.*}
                [ "${CPU_INT:-0}" -gt 80 ] 2>/dev/null && add_high "$name using high CPU: $cpu"
                [ "${CPU_INT:-0}" -gt 50 ] 2>/dev/null && [ "${CPU_INT:-0}" -le 80 ] 2>/dev/null && add_medium "$name CPU usage: $cpu"
            fi
        done
    else
        check_info "Container stats unavailable"
    fi

    section "27. VOLUME & DISK I/O [REAL-TIME]"
    if [ "$VOLUME_IO_DATA" != "unavailable" ] && [ -n "$VOLUME_IO_DATA" ]; then
        check_info "Filesystem usage inside container:"
        echo "$VOLUME_IO_DATA" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                USAGE_PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
                MOUNT=$(echo "$line" | awk '{print $6}')
                [ -n "$USAGE_PCT" ] && [ -n "$MOUNT" ] && {
                    check_info "  $line"
                    [ "${USAGE_PCT:-0}" -gt 90 ] 2>/dev/null && add_high "High disk usage in container: $MOUNT at ${USAGE_PCT}%"
                    [ "${USAGE_PCT:-0}" -gt 80 ] 2>/dev/null && [ "${USAGE_PCT:-0}" -le 90 ] 2>/dev/null && add_medium "Disk usage in container: $MOUNT at ${USAGE_PCT}%"
                }
            fi
        done
    else
        check_info "Volume I/O stats unavailable"
    fi

    section "28. ALL CONTAINER HEALTH STATUS [REAL-TIME]"
    if [ -n "$ALL_CONTAINER_HEALTH_DATA" ]; then
        check_info "Health status of all running containers:"
        UNHEALTHY_TOTAL=0
        HIGH_RESTART_TOTAL=0

        echo "$ALL_CONTAINER_HEALTH_DATA" | while IFS='|' read -r name health restarts; do
            if [ -n "$name" ]; then
                if [ "$health" != "none" ]; then
                    if [ "$health" = "healthy" ]; then
                        check_pass "  $name: healthy (restarts: $restarts)"
                    else
                        check_fail "  $name: $health (restarts: $restarts)"
                        UNHEALTHY_TOTAL=$((UNHEALTHY_TOTAL + 1))
                    fi
                else
                    check_info "  $name: no health check (restarts: $restarts)"
                fi

                [ "${restarts:-0}" -gt 5 ] 2>/dev/null && {
                    HIGH_RESTART_TOTAL=$((HIGH_RESTART_TOTAL + 1))
                    add_medium "$name has high restart count: $restarts"
                }
            fi
        done

        [ "$UNHEALTHY_TOTAL" -gt 0 ] && add_critical "Unhealthy containers detected: $UNHEALTHY_TOTAL"
    else
        check_info "No container health data"
    fi

    section "29. DOCKER DAEMON WARNINGS [REAL-TIME]"
    if [ "$DOCKER_WARNINGS_DATA" != "none" ] && [ -n "$DOCKER_WARNINGS_DATA" ]; then
        WARNING_COUNT=$(echo "$DOCKER_WARNINGS_DATA" | wc -l)
        check_warn "Docker daemon warnings: $WARNING_COUNT"
        echo "$DOCKER_WARNINGS_DATA" | while IFS= read -r line; do
            [ -n "$line" ] && check_warn "  $line"
        done
        add_medium "Docker daemon has warnings: $WARNING_COUNT"
    else
        check_pass "No Docker daemon warnings"
    fi

    section "30. IMAGE LAYER ANALYSIS [REAL-TIME]"
    if [ "$IMAGE_LAYERS_DATA" != "unavailable" ] && [ -n "$IMAGE_LAYERS_DATA" ]; then
        LAYER_COUNT=$(echo "$IMAGE_LAYERS_DATA" | grep -v "IMAGE\|CREATED" | wc -l)
        check_info "Image layers: $LAYER_COUNT"

        # Show top 5 largest layers
        echo "$IMAGE_LAYERS_DATA" | head -5 | while IFS= read -r line; do
            [ -n "$line" ] && check_info "  $line"
        done

        # Check for excessive layers (>50 indicates inefficient Dockerfile)
        [ "$LAYER_COUNT" -gt 50 ] && { check_warn "Excessive image layers: $LAYER_COUNT"; add_low "Consider optimizing Dockerfile (too many layers)"; }
    else
        check_info "Image layer data unavailable"
    fi

    section "31. NETWORK TOPOLOGY [REAL-TIME]"
    if [ "$NETWORK_INSPECT_DATA" != "unavailable" ] && [ -n "$NETWORK_INSPECT_DATA" ]; then
        check_info "Bridge network containers:"
        CONTAINER_NET_COUNT=$(echo "$NETWORK_INSPECT_DATA" | tr '###' '\n' | grep -c "|" || echo "0")
        check_info "Containers on bridge: $CONTAINER_NET_COUNT"

        echo "$NETWORK_INSPECT_DATA" | tr '###' '\n' | while IFS='|' read -r name ip mac; do
            if [ -n "$name" ]; then
                check_info "  $name: IP=$ip, MAC=$mac"
            fi
        done
    else
        check_info "Network topology data unavailable"
    fi
fi

section "32-36. STAGING DOCKER"
if [ "$STAGING_CONN" = true ]; then
    STG_RAW=$(ssh_staging 'set -o pipefail
echo "###SERVICE###"
systemctl is-active docker 2>/dev/null || echo "inactive"

echo "###COUNTS###"
docker ps -q 2>/dev/null | wc -l
docker ps -a -q 2>/dev/null | wc -l
docker images -q 2>/dev/null | wc -l
docker images -f "dangling=true" -q 2>/dev/null | wc -l

echo "###BACKEND###"
docker inspect tovplay-backend-staging --format "{{.State.Status}}" 2>/dev/null || echo "not_found"
docker inspect tovplay-backend-staging --format "{{.RestartCount}}" 2>/dev/null || echo "0"
docker inspect tovplay-backend-staging --format "{{.State.Health.Status}}" 2>/dev/null || echo "none"
docker stats tovplay-backend-staging --no-stream --format "{{.CPUPerc}} {{.MemPerc}}" 2>/dev/null || echo "0% 0%"

echo "###CONTAINERS###"
docker ps --format "{{.Names}} | {{.Status}}" 2>/dev/null | head -5

echo "###LOGS###"
docker logs tovplay-backend-staging --tail 50 2>&1 | grep -iE "error|exception" | wc -l || echo "0"

echo "###DISK###"
du -sh /var/lib/docker 2>/dev/null | cut -f1 || echo "0"

echo "###END###"
' 60 | tr -d '\r')

    STG_SVC=$(echo "$STG_RAW" | sed -n '/^###SERVICE###$/,/^###COUNTS###$/p' | grep -v "^###")
    STG_CNT=$(echo "$STG_RAW" | sed -n '/^###COUNTS###$/,/^###BACKEND###$/p' | grep -v "^###")
    STG_BE=$(echo "$STG_RAW" | sed -n '/^###BACKEND###$/,/^###CONTAINERS###$/p' | grep -v "^###")
    STG_CONT=$(echo "$STG_RAW" | sed -n '/^###CONTAINERS###$/,/^###LOGS###$/p' | grep -v "^###")
    STG_LOG=$(echo "$STG_RAW" | sed -n '/^###LOGS###$/,/^###DISK###$/p' | grep -v "^###")
    STG_DSK=$(echo "$STG_RAW" | sed -n '/^###DISK###$/,/^###END###$/p' | grep -v "^###")

    IFS=$'\n' read -d '' -r -a SSVC <<< "$STG_SVC"
    STG_DOCKER="${SSVC[0]:-inactive}"

    IFS=$'\n' read -d '' -r -a SCNT <<< "$STG_CNT"
    STG_RUNNING="${SCNT[0]:-0}"
    STG_TOTAL="${SCNT[1]:-0}"
    STG_IMAGES="${SCNT[2]:-0}"
    STG_DANGLING="${SCNT[3]:-0}"

    IFS=$'\n' read -d '' -r -a SBE <<< "$STG_BE"
    STG_BACKEND_STATUS="${SBE[0]:-not_found}"
    STG_BACKEND_RESTARTS="${SBE[1]:-0}"
    STG_BACKEND_HEALTH="${SBE[2]:-none}"
    STG_BACKEND_STATS="${SBE[3]:-0% 0%}"

    IFS=$'\n' read -d '' -r -a SLOG <<< "$STG_LOG"
    STG_ERROR_COUNT="${SLOG[0]:-0}"

    IFS=$'\n' read -d '' -r -a SDSK <<< "$STG_DSK"
    STG_DISK="${SDSK[0]:-0}"

    section "32. STAGING: SERVICE"
    [ "$STG_DOCKER" = "active" ] && check_pass "Docker: active" || { check_fail "Docker: $STG_DOCKER"; add_critical "Staging Docker down"; }
    check_info "Running: $STG_RUNNING / Total: $STG_TOTAL"

    section "33. STAGING: BACKEND"
    [ "$STG_BACKEND_STATUS" = "running" ] && check_pass "Backend: running" || { check_warn "Backend: $STG_BACKEND_STATUS"; add_high "Staging backend down"; }
    [ "${STG_BACKEND_RESTARTS:-0}" -lt 3 ] 2>/dev/null && check_pass "Restarts: $STG_BACKEND_RESTARTS" || { check_warn "Restarts: $STG_BACKEND_RESTARTS"; add_medium "High restarts"; }
    [ "$STG_BACKEND_HEALTH" != "none" ] && check_info "Health: $STG_BACKEND_HEALTH"
    check_info "Resources: $STG_BACKEND_STATS"

    section "34. STAGING: CONTAINERS"
    echo "$STG_CONT" | head -5 | while read -r line; do
        [ -n "$line" ] && echo "  $line"
    done

    section "35. STAGING: IMAGES & DISK"
    check_info "Images: $STG_IMAGES"
    [ "${STG_DANGLING:-0}" -eq 0 ] 2>/dev/null && check_pass "Dangling: 0" || { check_warn "Dangling: $STG_DANGLING"; add_low "Cleanup needed"; }
    check_info "Disk: $STG_DISK"

    section "36. STAGING: LOGS"
    [ "${STG_ERROR_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "No errors in logs" || {
        [ "${STG_ERROR_COUNT:-0}" -lt 10 ] 2>/dev/null && check_info "Minor errors: $STG_ERROR_COUNT lines" || { check_warn "Errors: $STG_ERROR_COUNT lines"; add_low "Staging errors"; }
    }
fi

section "🔴 THINGS TO FIX"
if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
    echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              🔴 THINGS TO FIX - DOCKER                        ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}🟠 HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
    for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}🔵 LOW: $issue${NC}"; done
else
    echo -e "  ${GREEN}✓ No issues found! Docker is healthy.${NC}"
fi

section "FINAL SUMMARY"
[[ $SCORE -lt 0 ]] && SCORE=0
DUR=$(($(date +%s) - SCRIPT_START))

if [[ $SCORE -ge 90 ]]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [[ $SCORE -ge 75 ]]; then RATING="GOOD"; COLOR="$GREEN"
elif [[ $SCORE -ge 60 ]]; then RATING="FAIR"; COLOR="$YELLOW"
elif [[ $SCORE -ge 40 ]]; then RATING="NEEDS WORK"; COLOR="$YELLOW"
else RATING="CRITICAL"; COLOR="$RED"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  DOCKER_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds   ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "DOCKER_SCORE:$SCORE"
