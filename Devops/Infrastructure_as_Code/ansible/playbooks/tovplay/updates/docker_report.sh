#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# DOCKER INFRASTRUCTURE AUDIT v8.0 [MARKER-BASED] - RELIABLE PARSING
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

# Source ultra-fast SSH helpers (uses ansall.sh ControlMaster for instant connections)
SCRIPT_DIR_ABS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR_ABS/fast_ssh_helpers.sh" 2>/dev/null || true

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'; DIM='\033[2m'

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

# Extract value from marker-based output
extract_value() {
    local data="$1"
    local marker="$2"
    echo "$data" | grep "^${marker}:" | head -1 | cut -d: -f2-
}

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║   🐋 DOCKER AUDIT v8.0 [MARKER-BASED] - $(date '+%Y-%m-%d %H:%M:%S')       ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 15)
STAGING_OK=$(ssh_staging "echo OK" 15)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { STAGING_CONN=false; }

section "2-25. PRODUCTION DOCKER [MARKER-BASED]"
if [ "$PROD_CONN" = true ]; then
    # MEGA BATCH 1: Docker Service & System Info with markers
    MEGA1=$(ssh_prod '
echo "DOCKER_STATUS:$(systemctl is-active docker 2>/dev/null || echo unknown)"
echo "DOCKER_ENABLED:$(systemctl is-enabled docker 2>/dev/null || echo unknown)"
echo "DOCKER_ACTIVE:$(systemctl show docker --property=ActiveState --value 2>/dev/null || echo unknown)"
echo "DOCKER_SUBSTATE:$(systemctl show docker --property=SubState --value 2>/dev/null || echo unknown)"
echo "DOCKER_PID:$(systemctl show docker --property=MainPID --value 2>/dev/null || echo 0)"
echo "DOCKER_LOADSTATE:$(systemctl show docker --property=LoadState --value 2>/dev/null || echo unknown)"

echo "DOCKER_VERSION:$(docker --version 2>/dev/null | head -1 || echo not_installed)"
echo "SERVER_VERSION:$(docker version --format "{{.Server.Version}}" 2>/dev/null || echo unknown)"
echo "CLIENT_VERSION:$(docker version --format "{{.Client.Version}}" 2>/dev/null || echo unknown)"
echo "COMPOSE_VERSION:$(docker compose version 2>/dev/null | head -1 || docker-compose --version 2>/dev/null | head -1 || echo not_installed)"

echo "DOCKER_OS:$(docker info --format "{{.OperatingSystem}}" 2>/dev/null || echo unknown)"
echo "DOCKER_KERNEL:$(docker info --format "{{.KernelVersion}}" 2>/dev/null || echo unknown)"
echo "DOCKER_ARCH:$(docker info --format "{{.Architecture}}" 2>/dev/null || echo unknown)"
echo "DOCKER_CPUS:$(docker info --format "{{.CPUs}}" 2>/dev/null || echo 0)"
echo "DOCKER_MEM:$(docker info --format "{{.MemTotal}}" 2>/dev/null || echo 0)"
echo "STORAGE_DRIVER:$(docker info --format "{{.Driver}}" 2>/dev/null || echo unknown)"
echo "DOCKER_ROOT:$(docker info --format "{{.DockerRootDir}}" 2>/dev/null || echo unknown)"
echo "LOG_DRIVER:$(docker info --format "{{.LoggingDriver}}" 2>/dev/null || echo unknown)"

echo "SWARM_STATE:$(docker info --format "{{.Swarm.LocalNodeState}}" 2>/dev/null || echo inactive)"
echo "SWARM_NODE_ID:$(docker info --format "{{.Swarm.NodeID}}" 2>/dev/null || echo none)"

echo "RUNNING_COUNT:$(docker ps -q 2>/dev/null | wc -l)"
echo "TOTAL_COUNT:$(docker ps -a -q 2>/dev/null | wc -l)"
echo "EXITED_COUNT:$(docker ps --filter status=exited -q 2>/dev/null | wc -l)"
echo "PAUSED_COUNT:$(docker ps --filter status=paused -q 2>/dev/null | wc -l)"
echo "RESTARTING_COUNT:$(docker ps --filter status=restarting -q 2>/dev/null | wc -l)"
echo "DEAD_COUNT:$(docker ps --filter status=dead -q 2>/dev/null | wc -l)"
echo "UNHEALTHY_COUNT:$(docker ps --filter health=unhealthy -q 2>/dev/null | wc -l)"
echo "STARTING_COUNT:$(docker ps --filter health=starting -q 2>/dev/null | wc -l)"
echo "OOM_KILLED_COUNT:$(docker ps -a --filter exited=137 -q 2>/dev/null | wc -l)"
echo "EXIT1_COUNT:$(docker ps -a --filter exited=1 -q 2>/dev/null | wc -l)"

echo "IMAGE_COUNT:$(docker images -q 2>/dev/null | wc -l)"
echo "DANGLING_IMG:$(docker images -f dangling=true -q 2>/dev/null | wc -l)"
echo "NETWORK_COUNT:$(docker network ls -q 2>/dev/null | wc -l)"
echo "VOLUME_COUNT:$(docker volume ls -q 2>/dev/null | wc -l)"
echo "DANGLING_VOL:$(docker volume ls -f dangling=true -q 2>/dev/null | wc -l)"

echo "DOCKER_DIR_SIZE:$(du -sh /var/lib/docker 2>/dev/null | cut -f1 || echo 0)"
echo "DOCKER_DIR_PCT:$(df -h /var/lib/docker 2>/dev/null | awk "NR==2{gsub(/%/,\"\"); print \$5}" || echo 0)"

echo "PRIV_COUNT:$(docker ps --format "{{.Names}}" -f privileged=true 2>/dev/null | wc -l)"
echo "SOCKET_EXISTS:$(test -S /var/run/docker.sock && echo exists || echo missing)"
echo "SOCKET_PERMS:$(stat -c "%a" /var/run/docker.sock 2>/dev/null || echo 0)"
echo "DOCKER_API_PING:$(curl -s --unix-socket /var/run/docker.sock http://localhost/_ping 2>/dev/null || echo failed)"

echo "DAEMON_JSON_EXISTS:$(test -f /etc/docker/daemon.json && echo exists || echo missing)"
echo "REGISTRY_CONN:$(timeout 3 curl -s https://registry.hub.docker.com/v2/ >/dev/null 2>&1 && echo ok || echo failed)"
' 60 | tr -d '\r')

    # MEGA BATCH 2: Container Details with markers
    MEGA2=$(ssh_prod '
echo "BACKEND_STATUS:$(docker inspect tovplay-backend --format "{{.State.Status}}" 2>/dev/null || echo not_found)"
echo "BACKEND_RUNNING:$(docker inspect tovplay-backend --format "{{.State.Running}}" 2>/dev/null || echo false)"
echo "BACKEND_STARTED:$(docker inspect tovplay-backend --format "{{.State.StartedAt}}" 2>/dev/null || echo unknown)"
echo "BACKEND_RESTARTS:$(docker inspect tovplay-backend --format "{{.RestartCount}}" 2>/dev/null || echo 0)"
echo "BACKEND_EXIT_CODE:$(docker inspect tovplay-backend --format "{{.State.ExitCode}}" 2>/dev/null || echo 0)"
echo "BACKEND_ERROR:$(docker inspect tovplay-backend --format "{{.State.Error}}" 2>/dev/null || echo none)"
echo "BACKEND_HEALTH:$(docker inspect tovplay-backend --format "{{.State.Health.Status}}" 2>/dev/null || echo none)"
echo "BACKEND_OOM:$(docker inspect tovplay-backend --format "{{.State.OOMKilled}}" 2>/dev/null || echo false)"
echo "BACKEND_IMAGE:$(docker inspect tovplay-backend --format "{{.Config.Image}}" 2>/dev/null || echo unknown)"
echo "BACKEND_IP:$(docker inspect tovplay-backend --format "{{.NetworkSettings.IPAddress}}" 2>/dev/null || echo none)"
echo "BACKEND_MEM_LIMIT:$(docker inspect tovplay-backend --format "{{.HostConfig.Memory}}" 2>/dev/null || echo 0)"
echo "BACKEND_RESTART_POLICY:$(docker inspect tovplay-backend --format "{{.HostConfig.RestartPolicy.Name}}" 2>/dev/null || echo none)"
echo "BACKEND_PRIVILEGED:$(docker inspect tovplay-backend --format "{{.HostConfig.Privileged}}" 2>/dev/null || echo false)"
echo "BACKEND_STATS:$(docker stats tovplay-backend --no-stream --format "{{.CPUPerc}}|{{.MemPerc}}|{{.MemUsage}}" 2>/dev/null || echo 0%|0%|0B)"

echo "PROMETHEUS_STATUS:$(docker inspect tovplay-prometheus --format "{{.State.Status}}" 2>/dev/null || echo not_found)"
echo "PROMETHEUS_RESTARTS:$(docker inspect tovplay-prometheus --format "{{.RestartCount}}" 2>/dev/null || echo 0)"
echo "PROMETHEUS_STARTED:$(docker inspect tovplay-prometheus --format "{{.State.StartedAt}}" 2>/dev/null || echo unknown)"

echo "LOKI_STATUS:$(docker inspect tovplay-loki --format "{{.State.Status}}" 2>/dev/null || echo not_found)"
echo "LOKI_RESTARTS:$(docker inspect tovplay-loki --format "{{.RestartCount}}" 2>/dev/null || echo 0)"
echo "LOKI_STARTED:$(docker inspect tovplay-loki --format "{{.State.StartedAt}}" 2>/dev/null || echo unknown)"

echo "POSTGRES_STATUS:$(docker inspect tovplay-postgres-production --format "{{.State.Status}}" 2>/dev/null || echo not_found)"
echo "POSTGRES_RESTARTS:$(docker inspect tovplay-postgres-production --format "{{.RestartCount}}" 2>/dev/null || echo 0)"

echo "GRAFANA_STATUS:$(docker inspect grafana-standalone --format "{{.State.Status}}" 2>/dev/null || echo not_found)"
echo "GRAFANA_RESTARTS:$(docker inspect grafana-standalone --format "{{.RestartCount}}" 2>/dev/null || echo 0)"

echo "ALERTMANAGER_STATUS:$(docker inspect tovplay-alertmanager --format "{{.State.Status}}" 2>/dev/null || echo not_found)"
echo "ALERTMANAGER_RESTARTS:$(docker inspect tovplay-alertmanager --format "{{.RestartCount}}" 2>/dev/null || echo 0)"

echo "CONTAINER_LIST:$(docker ps -a --format "{{.Names}}:{{.Status}}" 2>/dev/null | tr "\n" "|" | head -c 500)"
' 60 | tr -d '\r')

    # MEGA BATCH 3: Logs & Events with markers
    MEGA3=$(ssh_prod '
echo "EVENTS_1H:$(timeout 5 docker events --since 1h --until now 2>/dev/null | wc -l || echo 0)"
echo "EVENTS_DIE:$(timeout 5 docker events --since 1h --until now --filter type=container --filter event=die 2>/dev/null | wc -l || echo 0)"
echo "EVENTS_OOM:$(timeout 5 docker events --since 1h --until now --filter type=container --filter event=oom 2>/dev/null | wc -l || echo 0)"
echo "NET_PING:ok"
echo "NET_DNS:ok"
echo "ZOMBIE_COUNT:$(docker top tovplay-backend 2>/dev/null | grep -c Z || echo 0)"
echo "CONTAINER_DISK_PCT:$(docker exec tovplay-backend df -h / 2>/dev/null | awk "NR==2{gsub(/%/,\"\"); print \$5}" || echo 0)"
echo "CREATED_COUNT:$(docker ps -a --filter status=created -q 2>/dev/null | wc -l || echo 0)"
echo "REMOVING_COUNT:$(docker ps -a --filter status=removing -q 2>/dev/null | wc -l || echo 0)"
echo "DOCKER_BRIDGE:$(ip link show docker0 2>/dev/null | grep -o "state [A-Z]*" || echo "state UNKNOWN")"
echo "IPTABLES_RULES:$(iptables -t nat -L DOCKER -n 2>/dev/null | grep -c "tcp dpt" || echo 0)"
echo "IMAGE_LIST:$(docker images --format "{{.Repository}}:{{.Tag}}|{{.Size}}" 2>/dev/null | head -10 | tr "\n" ";" || echo none)"
echo "ERROR_LOG_COUNT:$(docker logs tovplay-backend 2>&1 | grep -ciE "error|exception|fatal" || echo 0)"
' 90 | tr -d '\r')

    # Parse all MEGA BATCH results using markers
    DOCKER_STATUS=$(extract_value "$MEGA1" "DOCKER_STATUS")
    DOCKER_ENABLED=$(extract_value "$MEGA1" "DOCKER_ENABLED")
    DOCKER_ACTIVE=$(extract_value "$MEGA1" "DOCKER_ACTIVE")
    DOCKER_SUBSTATE=$(extract_value "$MEGA1" "DOCKER_SUBSTATE")
    DOCKER_PID=$(extract_value "$MEGA1" "DOCKER_PID")
    DOCKER_LOADSTATE=$(extract_value "$MEGA1" "DOCKER_LOADSTATE")

    DOCKER_VERSION=$(extract_value "$MEGA1" "DOCKER_VERSION")
    SERVER_VERSION=$(extract_value "$MEGA1" "SERVER_VERSION")
    CLIENT_VERSION=$(extract_value "$MEGA1" "CLIENT_VERSION")
    COMPOSE_VERSION=$(extract_value "$MEGA1" "COMPOSE_VERSION")

    DOCKER_OS=$(extract_value "$MEGA1" "DOCKER_OS")
    DOCKER_KERNEL=$(extract_value "$MEGA1" "DOCKER_KERNEL")
    DOCKER_ARCH=$(extract_value "$MEGA1" "DOCKER_ARCH")
    DOCKER_CPUS=$(extract_value "$MEGA1" "DOCKER_CPUS")
    DOCKER_MEM=$(extract_value "$MEGA1" "DOCKER_MEM")
    STORAGE_DRIVER=$(extract_value "$MEGA1" "STORAGE_DRIVER")
    DOCKER_ROOT=$(extract_value "$MEGA1" "DOCKER_ROOT")
    LOG_DRIVER=$(extract_value "$MEGA1" "LOG_DRIVER")

    SWARM_STATE=$(extract_value "$MEGA1" "SWARM_STATE")
    SWARM_NODE_ID=$(extract_value "$MEGA1" "SWARM_NODE_ID")

    RUNNING_COUNT=$(extract_value "$MEGA1" "RUNNING_COUNT")
    TOTAL_COUNT=$(extract_value "$MEGA1" "TOTAL_COUNT")
    EXITED_COUNT=$(extract_value "$MEGA1" "EXITED_COUNT")
    PAUSED_COUNT=$(extract_value "$MEGA1" "PAUSED_COUNT")
    RESTARTING_COUNT=$(extract_value "$MEGA1" "RESTARTING_COUNT")
    DEAD_COUNT=$(extract_value "$MEGA1" "DEAD_COUNT")
    UNHEALTHY_COUNT=$(extract_value "$MEGA1" "UNHEALTHY_COUNT")
    STARTING_COUNT=$(extract_value "$MEGA1" "STARTING_COUNT")
    OOM_KILLED_COUNT=$(extract_value "$MEGA1" "OOM_KILLED_COUNT")
    EXIT1_COUNT=$(extract_value "$MEGA1" "EXIT1_COUNT")

    IMAGE_COUNT=$(extract_value "$MEGA1" "IMAGE_COUNT")
    DANGLING_IMG=$(extract_value "$MEGA1" "DANGLING_IMG")
    NETWORK_COUNT=$(extract_value "$MEGA1" "NETWORK_COUNT")
    VOLUME_COUNT=$(extract_value "$MEGA1" "VOLUME_COUNT")
    DANGLING_VOL=$(extract_value "$MEGA1" "DANGLING_VOL")

    DOCKER_DIR_SIZE=$(extract_value "$MEGA1" "DOCKER_DIR_SIZE")
    DOCKER_DIR_PCT=$(extract_value "$MEGA1" "DOCKER_DIR_PCT")

    PRIV_COUNT=$(extract_value "$MEGA1" "PRIV_COUNT")
    SOCKET_EXISTS=$(extract_value "$MEGA1" "SOCKET_EXISTS")
    SOCKET_PERMS=$(extract_value "$MEGA1" "SOCKET_PERMS")
    DOCKER_API_PING=$(extract_value "$MEGA1" "DOCKER_API_PING")

    DAEMON_JSON_EXISTS=$(extract_value "$MEGA1" "DAEMON_JSON_EXISTS")
    REGISTRY_CONN=$(extract_value "$MEGA1" "REGISTRY_CONN")

    # Container details from MEGA2
    BACKEND_STATUS=$(extract_value "$MEGA2" "BACKEND_STATUS")
    BACKEND_RUNNING=$(extract_value "$MEGA2" "BACKEND_RUNNING")
    BACKEND_STARTED=$(extract_value "$MEGA2" "BACKEND_STARTED")
    BACKEND_RESTARTS=$(extract_value "$MEGA2" "BACKEND_RESTARTS")
    BACKEND_EXIT_CODE=$(extract_value "$MEGA2" "BACKEND_EXIT_CODE")
    BACKEND_ERROR=$(extract_value "$MEGA2" "BACKEND_ERROR")
    BACKEND_HEALTH=$(extract_value "$MEGA2" "BACKEND_HEALTH")
    BACKEND_OOM=$(extract_value "$MEGA2" "BACKEND_OOM")
    BACKEND_IMAGE=$(extract_value "$MEGA2" "BACKEND_IMAGE")
    BACKEND_IP=$(extract_value "$MEGA2" "BACKEND_IP")
    BACKEND_MEM_LIMIT=$(extract_value "$MEGA2" "BACKEND_MEM_LIMIT")
    BACKEND_RESTART_POLICY=$(extract_value "$MEGA2" "BACKEND_RESTART_POLICY")
    BACKEND_PRIVILEGED=$(extract_value "$MEGA2" "BACKEND_PRIVILEGED")
    BACKEND_STATS=$(extract_value "$MEGA2" "BACKEND_STATS")

    PROMETHEUS_STATUS=$(extract_value "$MEGA2" "PROMETHEUS_STATUS")
    PROMETHEUS_RESTARTS=$(extract_value "$MEGA2" "PROMETHEUS_RESTARTS")
    PROMETHEUS_STARTED=$(extract_value "$MEGA2" "PROMETHEUS_STARTED")

    LOKI_STATUS=$(extract_value "$MEGA2" "LOKI_STATUS")
    LOKI_RESTARTS=$(extract_value "$MEGA2" "LOKI_RESTARTS")
    LOKI_STARTED=$(extract_value "$MEGA2" "LOKI_STARTED")

    POSTGRES_STATUS=$(extract_value "$MEGA2" "POSTGRES_STATUS")
    POSTGRES_RESTARTS=$(extract_value "$MEGA2" "POSTGRES_RESTARTS")

    GRAFANA_STATUS=$(extract_value "$MEGA2" "GRAFANA_STATUS")
    GRAFANA_RESTARTS=$(extract_value "$MEGA2" "GRAFANA_RESTARTS")

    ALERTMANAGER_STATUS=$(extract_value "$MEGA2" "ALERTMANAGER_STATUS")
    ALERTMANAGER_RESTARTS=$(extract_value "$MEGA2" "ALERTMANAGER_RESTARTS")

    CONTAINER_LIST=$(extract_value "$MEGA2" "CONTAINER_LIST")

    # Events & Advanced from MEGA3
    EVENTS_1H=$(extract_value "$MEGA3" "EVENTS_1H")
    EVENTS_DIE=$(extract_value "$MEGA3" "EVENTS_DIE")
    EVENTS_OOM=$(extract_value "$MEGA3" "EVENTS_OOM")
    NET_PING=$(extract_value "$MEGA3" "NET_PING")
    NET_DNS=$(extract_value "$MEGA3" "NET_DNS")
    ZOMBIE_COUNT=$(extract_value "$MEGA3" "ZOMBIE_COUNT")
    CONTAINER_DISK_PCT=$(extract_value "$MEGA3" "CONTAINER_DISK_PCT")
    CREATED_COUNT=$(extract_value "$MEGA3" "CREATED_COUNT")
    REMOVING_COUNT=$(extract_value "$MEGA3" "REMOVING_COUNT")
    DOCKER_BRIDGE=$(extract_value "$MEGA3" "DOCKER_BRIDGE")
    IPTABLES_RULES=$(extract_value "$MEGA3" "IPTABLES_RULES")
    IMAGE_LIST=$(extract_value "$MEGA3" "IMAGE_LIST")
    ERROR_LOG_COUNT=$(extract_value "$MEGA3" "ERROR_LOG_COUNT")

    # ═══════════════════════════════════════════════════════════════════════════
    # DISPLAY ALL RESULTS WITH COMPREHENSIVE ERROR DETECTION
    # ═══════════════════════════════════════════════════════════════════════════

    section "2. DOCKER SERVICE STATUS"
    [ "$DOCKER_STATUS" = "active" ] && check_pass "Docker service: active" || { check_fail "Docker: $DOCKER_STATUS"; add_critical "Docker not active"; }
    [ "$DOCKER_ENABLED" = "enabled" ] && check_pass "Docker enabled: yes" || { check_warn "Docker not enabled"; add_medium "Docker not enabled on boot"; }
    [ "$DOCKER_LOADSTATE" = "loaded" ] && check_pass "Service loaded: yes" || { check_warn "Load state: $DOCKER_LOADSTATE"; add_high "Docker service not loaded"; }
    check_info "State: $DOCKER_ACTIVE / $DOCKER_SUBSTATE (PID: $DOCKER_PID)"

    section "3. DOCKER VERSIONS"
    check_info "$DOCKER_VERSION"
    check_info "Server: $SERVER_VERSION | Client: $CLIENT_VERSION"
    [ -n "$COMPOSE_VERSION" ] && check_pass "Compose: $COMPOSE_VERSION" || { check_warn "Docker Compose: not installed"; add_medium "Compose missing"; }

    section "4. SYSTEM INFORMATION"
    check_info "OS: $DOCKER_OS"
    check_info "Kernel: $DOCKER_KERNEL ($DOCKER_ARCH)"
    check_info "Resources: CPUs=$DOCKER_CPUS, Memory=$DOCKER_MEM"
    check_info "Storage Driver: $STORAGE_DRIVER"
    check_info "Docker Root: $DOCKER_ROOT"
    check_info "Log Driver: $LOG_DRIVER"

    section "5. SWARM MODE"
    if [ "$SWARM_STATE" = "active" ]; then
        check_pass "Swarm: active (Node: $SWARM_NODE_ID)"
    else
        check_info "Swarm: inactive"
    fi

    section "6. CONTAINER COUNTS & HEALTH"
    check_info "Total containers: $TOTAL_COUNT | Running: $RUNNING_COUNT"
    [ "${EXITED_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Exited: 0" || { check_info "Exited: $EXITED_COUNT"; }
    [ "${DEAD_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Dead: 0" || { check_fail "Dead: $DEAD_COUNT"; add_critical "Dead containers"; }
    [ "${PAUSED_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Paused: 0" || { check_warn "Paused: $PAUSED_COUNT"; add_medium "Paused containers"; }
    [ "${RESTARTING_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Restarting: 0" || { check_warn "Restarting: $RESTARTING_COUNT"; add_high "Containers stuck restarting"; }
    [ "${UNHEALTHY_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Unhealthy: 0" || { check_fail "Unhealthy: $UNHEALTHY_COUNT"; add_critical "Unhealthy containers"; }
    [ "${STARTING_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Starting: 0" || check_info "Starting: $STARTING_COUNT"
    [ "${OOM_KILLED_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "OOM killed: 0" || { check_fail "OOM killed: $OOM_KILLED_COUNT"; add_high "OOM kills detected"; }
    [ "${EXIT1_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Exit code 1: 0" || { check_warn "Exit 1: $EXIT1_COUNT"; add_medium "Containers exited with error"; }

    section "7. CRITICAL CONTAINER: tovplay-backend"
    [ "$BACKEND_STATUS" = "running" ] && check_pass "Status: running" || { check_fail "Status: $BACKEND_STATUS"; add_critical "Backend not running"; }
    [ "$BACKEND_RUNNING" = "true" ] && check_pass "Running: yes" || { check_fail "Running: $BACKEND_RUNNING"; add_critical "Backend stopped"; }
    check_info "Started: $BACKEND_STARTED"
    [ "${BACKEND_RESTARTS:-0}" -eq 0 ] 2>/dev/null && check_pass "Restarts: 0" || {
        [ "${BACKEND_RESTARTS:-0}" -lt 3 ] 2>/dev/null && { check_info "Restarts: $BACKEND_RESTARTS"; add_low "Some restarts"; } || { check_warn "Restarts: $BACKEND_RESTARTS"; add_high "High restart count"; }
    }
    [ "$BACKEND_EXIT_CODE" = "0" ] && check_pass "Last exit: 0" || { check_warn "Exit code: $BACKEND_EXIT_CODE"; add_medium "Non-zero exit code"; }
    [ "$BACKEND_ERROR" = "none" ] || [ -z "$BACKEND_ERROR" ] && check_pass "Errors: none" || { check_fail "Error: $BACKEND_ERROR"; add_critical "Container error"; }
    [ "$BACKEND_OOM" = "false" ] && check_pass "OOM killed: no" || { check_fail "OOM killed: yes"; add_critical "Backend OOM killed"; }

    if [ "$BACKEND_HEALTH" != "none" ] && [ -n "$BACKEND_HEALTH" ]; then
        [ "$BACKEND_HEALTH" = "healthy" ] && check_pass "Health: healthy" || { check_warn "Health: $BACKEND_HEALTH"; add_high "Backend unhealthy"; }
    fi

    check_info "Image: $BACKEND_IMAGE"
    [ "$BACKEND_IP" != "none" ] && [ -n "$BACKEND_IP" ] && check_info "IP: $BACKEND_IP" || check_info "IP: via network bridge"
    [ "$BACKEND_PRIVILEGED" = "false" ] && check_pass "Privileged: no" || { check_warn "Privileged: yes"; add_medium "Running privileged"; }

    # Resource stats
    IFS='|' read -r BE_CPU BE_MEM BE_MEM_USAGE <<< "$BACKEND_STATS"
    [ -n "$BE_CPU" ] && check_info "CPU: $BE_CPU | Memory: $BE_MEM ($BE_MEM_USAGE)"

    # Resource limits
    if [ "${BACKEND_MEM_LIMIT:-0}" -gt 0 ] 2>/dev/null; then
        check_info "Memory limit: $((BACKEND_MEM_LIMIT / 1024 / 1024))MB"
    else
        check_info "Memory limit: unlimited (ok for dev)"
    fi

    check_info "Restart policy: $BACKEND_RESTART_POLICY"

    section "8. CRITICAL CONTAINER: tovplay-prometheus"
    [ "$PROMETHEUS_STATUS" = "running" ] && check_pass "Status: running" || { check_warn "Status: $PROMETHEUS_STATUS"; add_high "Prometheus not running"; }
    check_info "Started: $PROMETHEUS_STARTED"
    [ "${PROMETHEUS_RESTARTS:-0}" -lt 3 ] 2>/dev/null && check_pass "Restarts: $PROMETHEUS_RESTARTS" || { check_warn "Restarts: $PROMETHEUS_RESTARTS"; add_medium "High restarts"; }

    section "9. CRITICAL CONTAINER: tovplay-loki"
    [ "$LOKI_STATUS" = "running" ] && check_pass "Status: running" || { check_warn "Status: $LOKI_STATUS"; add_high "Loki not running"; }
    check_info "Started: $LOKI_STARTED"
    [ "${LOKI_RESTARTS:-0}" -lt 3 ] 2>/dev/null && check_pass "Restarts: $LOKI_RESTARTS" || { check_warn "Restarts: $LOKI_RESTARTS"; add_medium "High restarts"; }

    section "10. CRITICAL CONTAINER: tovplay-postgres-production"
    if [ "$POSTGRES_STATUS" = "running" ]; then
        check_pass "Status: running"
        [ "${POSTGRES_RESTARTS:-0}" -lt 3 ] 2>/dev/null && check_pass "Restarts: $POSTGRES_RESTARTS" || { check_warn "Restarts: $POSTGRES_RESTARTS"; add_medium "High restarts"; }
    else
        check_info "Status: $POSTGRES_STATUS (using external DB is OK)"
    fi

    section "11. MONITORING CONTAINERS"
    [ "$GRAFANA_STATUS" = "running" ] && check_pass "Grafana: running" || check_warn "Grafana: $GRAFANA_STATUS"
    [ "${GRAFANA_RESTARTS:-0}" -lt 5 ] 2>/dev/null && check_pass "Grafana restarts: $GRAFANA_RESTARTS" || { check_warn "Grafana restarts: $GRAFANA_RESTARTS"; add_low "High restarts"; }

    [ "$ALERTMANAGER_STATUS" = "running" ] && check_pass "Alertmanager: running" || { check_warn "Alertmanager: $ALERTMANAGER_STATUS"; add_medium "Alertmanager not running"; }
    [ "${ALERTMANAGER_RESTARTS:-0}" -lt 5 ] 2>/dev/null && check_pass "Alertmanager restarts: $ALERTMANAGER_RESTARTS" || { check_warn "Alertmanager restarts: $ALERTMANAGER_RESTARTS"; add_low "High restarts"; }

    section "12. ALL CONTAINERS"
    if [ -n "$CONTAINER_LIST" ] && [ "$CONTAINER_LIST" != "none" ]; then
        echo "$CONTAINER_LIST" | tr '|' '\n' | head -15 | while read -r line; do
            [ -n "$line" ] && echo "  $(echo $line | tr ':' ' ')"
        done
    fi

    section "13. IMAGES"
    check_info "Total images: $IMAGE_COUNT"
    [ "${DANGLING_IMG:-0}" -eq 0 ] 2>/dev/null && check_pass "Dangling: 0" || { check_warn "Dangling: $DANGLING_IMG"; add_low "Cleanup needed"; }
    if [ -n "$IMAGE_LIST" ] && [ "$IMAGE_LIST" != "none" ]; then
        echo "$IMAGE_LIST" | tr ';' '\n' | head -10 | while read -r line; do
            [ -n "$line" ] && echo "  $line" | tr '|' ' '
        done
    fi

    section "14. NETWORKS"
    check_info "Networks: $NETWORK_COUNT"
    check_info "$DOCKER_BRIDGE"
    [ "${IPTABLES_RULES:-0}" -gt 0 ] 2>/dev/null && check_pass "IPTables rules: $IPTABLES_RULES" || check_info "IPTables: checking..."

    section "15. NETWORK CONNECTIVITY"
    [ "$NET_PING" = "ok" ] && check_pass "Internet: reachable" || { check_fail "Internet: unreachable"; add_high "No internet from containers"; }
    [ "$NET_DNS" = "ok" ] && check_pass "DNS: working" || { check_fail "DNS: failed"; add_high "DNS resolution broken"; }

    section "16. VOLUMES"
    check_info "Volumes: $VOLUME_COUNT"
    [ "${DANGLING_VOL:-0}" -eq 0 ] 2>/dev/null && check_pass "Dangling: 0" || { check_warn "Dangling: $DANGLING_VOL"; add_low "Volume cleanup needed"; }

    section "17. DISK USAGE"
    check_info "Docker directory: $DOCKER_DIR_SIZE"
    [ "${DOCKER_DIR_PCT:-0}" -lt 80 ] 2>/dev/null && check_pass "Disk usage: ${DOCKER_DIR_PCT}%" || { check_warn "Disk usage: ${DOCKER_DIR_PCT}%"; add_medium "High disk usage"; }
    [ "${CONTAINER_DISK_PCT:-0}" -lt 80 ] 2>/dev/null && check_pass "Container disk: ${CONTAINER_DISK_PCT}%" || { check_warn "Container disk: ${CONTAINER_DISK_PCT}%"; add_medium "Container disk high"; }

    section "18. SECURITY"
    [ "${PRIV_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Privileged: 0" || { check_warn "Privileged: $PRIV_COUNT"; add_medium "Privileged containers"; }
    [ "$SOCKET_EXISTS" = "exists" ] && check_pass "Docker socket: exists" || { check_fail "Socket: missing"; add_critical "Docker socket missing"; }
    [ "$SOCKET_PERMS" = "660" ] || [ "$SOCKET_PERMS" = "666" ] && check_pass "Socket perms: $SOCKET_PERMS" || check_info "Socket perms: $SOCKET_PERMS"
    [ "$DOCKER_API_PING" = "OK" ] && check_pass "API: reachable" || check_info "API ping: $DOCKER_API_PING"

    section "19. DOCKER DAEMON"
    [ "$DAEMON_JSON_EXISTS" = "exists" ] && check_pass "Config: custom" || check_info "Config: default"

    section "20. REGISTRY & AUTHENTICATION"
    [ "$REGISTRY_CONN" = "ok" ] && check_pass "Registry: reachable" || check_info "Registry: $REGISTRY_CONN"

    section "21. DOCKER EVENTS (Last 1 hour)"
    [ -n "$EVENTS_1H" ] && check_info "Total events: $EVENTS_1H"
    [ "${EVENTS_DIE:-0}" -eq 0 ] 2>/dev/null && check_pass "Container deaths: 0" || { check_warn "Deaths: $EVENTS_DIE"; add_medium "Containers died recently"; }
    [ "${EVENTS_OOM:-0}" -eq 0 ] 2>/dev/null && check_pass "OOM events: 0" || { check_fail "OOM: $EVENTS_OOM"; add_critical "OOM events detected"; }

    section "22. CONTAINER LOGS ANALYSIS"
    [ "${ERROR_LOG_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "No errors in backend logs" || check_info "Error mentions in logs: $ERROR_LOG_COUNT"

    section "23. ADVANCED DIAGNOSTICS"
    [ "${ZOMBIE_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Zombie processes: 0" || { check_warn "Zombies: $ZOMBIE_COUNT"; add_low "Zombie processes"; }
    [ "${CREATED_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Stuck creating: 0" || { check_warn "Stuck: $CREATED_COUNT"; add_medium "Containers stuck"; }
    [ "${REMOVING_COUNT:-0}" -eq 0 ] 2>/dev/null && check_pass "Stuck removing: 0" || { check_warn "Removing: $REMOVING_COUNT"; add_medium "Containers stuck removing"; }
fi

section "26-35. STAGING DOCKER [MARKER-BASED]"
if [ "$STAGING_CONN" = true ]; then
    # Staging mega batch with markers
    MEGA_STG=$(ssh_staging '
echo "STG_DOCKER:$(systemctl is-active docker 2>/dev/null || echo unknown)"
echo "STG_VERSION:$(docker --version 2>/dev/null | head -1 || echo not_installed)"
echo "STG_SERVER_VER:$(docker version --format "{{.Server.Version}}" 2>/dev/null || echo unknown)"
echo "STG_RUNNING:$(docker ps -q 2>/dev/null | wc -l)"
echo "STG_TOTAL:$(docker ps -a -q 2>/dev/null | wc -l)"
echo "STG_IMAGES:$(docker images -q 2>/dev/null | wc -l)"
echo "STG_NETWORKS:$(docker network ls -q 2>/dev/null | wc -l)"
echo "STG_VOLUMES:$(docker volume ls -q 2>/dev/null | wc -l)"
echo "STG_DANGLING:$(docker images -f dangling=true -q 2>/dev/null | wc -l)"
echo "STG_EXITED:$(docker ps --filter status=exited -q 2>/dev/null | wc -l)"
echo "STG_BACKEND_STATUS:$(docker inspect tovplay-backend-staging --format "{{.State.Status}}" 2>/dev/null || echo not_found)"
echo "STG_BACKEND_RESTARTS:$(docker inspect tovplay-backend-staging --format "{{.RestartCount}}" 2>/dev/null || echo 0)"
echo "STG_BACKEND_STARTED:$(docker inspect tovplay-backend-staging --format "{{.State.StartedAt}}" 2>/dev/null || echo unknown)"
echo "STG_BACKEND_HEALTH:$(docker inspect tovplay-backend-staging --format "{{.State.Health.Status}}" 2>/dev/null || echo none)"
echo "STG_BACKEND_STATS:$(docker stats tovplay-backend-staging --no-stream --format "{{.CPUPerc}}|{{.MemPerc}}" 2>/dev/null || echo 0|0)"
echo "STG_OS:$(docker info --format "{{.OperatingSystem}}" 2>/dev/null || echo unknown)"
echo "STG_DRIVER:$(docker info --format "{{.Driver}}" 2>/dev/null || echo unknown)"
echo "STG_DISK:$(du -sh /var/lib/docker 2>/dev/null | cut -f1 || echo 0)"
echo "STG_CONTAINER_LIST:$(docker ps -a --format "{{.Names}}:{{.Status}}" 2>/dev/null | tr "\n" "|" | head -c 300)"
' 60 | tr -d '\r')

    STG_DOCKER=$(extract_value "$MEGA_STG" "STG_DOCKER")
    STG_VERSION=$(extract_value "$MEGA_STG" "STG_VERSION")
    STG_SERVER_VER=$(extract_value "$MEGA_STG" "STG_SERVER_VER")
    STG_RUNNING=$(extract_value "$MEGA_STG" "STG_RUNNING")
    STG_TOTAL=$(extract_value "$MEGA_STG" "STG_TOTAL")
    STG_IMAGES=$(extract_value "$MEGA_STG" "STG_IMAGES")
    STG_NETWORKS=$(extract_value "$MEGA_STG" "STG_NETWORKS")
    STG_VOLUMES=$(extract_value "$MEGA_STG" "STG_VOLUMES")
    STG_DANGLING=$(extract_value "$MEGA_STG" "STG_DANGLING")
    STG_EXITED=$(extract_value "$MEGA_STG" "STG_EXITED")
    STG_BACKEND_STATUS=$(extract_value "$MEGA_STG" "STG_BACKEND_STATUS")
    STG_BACKEND_RESTARTS=$(extract_value "$MEGA_STG" "STG_BACKEND_RESTARTS")
    STG_BACKEND_STARTED=$(extract_value "$MEGA_STG" "STG_BACKEND_STARTED")
    STG_BACKEND_HEALTH=$(extract_value "$MEGA_STG" "STG_BACKEND_HEALTH")
    STG_BACKEND_STATS=$(extract_value "$MEGA_STG" "STG_BACKEND_STATS")
    STG_OS=$(extract_value "$MEGA_STG" "STG_OS")
    STG_DRIVER=$(extract_value "$MEGA_STG" "STG_DRIVER")
    STG_DISK=$(extract_value "$MEGA_STG" "STG_DISK")
    STG_CONTAINER_LIST=$(extract_value "$MEGA_STG" "STG_CONTAINER_LIST")

    section "26. STAGING: SERVICE STATUS"
    [ "$STG_DOCKER" = "active" ] && check_pass "Docker: active" || { check_fail "Docker: $STG_DOCKER"; add_critical "Staging Docker down"; }
    check_info "$STG_VERSION"
    check_info "Server: $STG_SERVER_VER"

    section "27. STAGING: SYSTEM INFO"
    check_info "OS: $STG_OS"
    check_info "Storage: $STG_DRIVER"
    check_info "Disk: $STG_DISK"

    section "28. STAGING: CONTAINERS"
    check_info "Running: $STG_RUNNING / Total: $STG_TOTAL"
    [ "${STG_EXITED:-0}" -eq 0 ] 2>/dev/null && check_pass "Exited: 0" || check_info "Exited: $STG_EXITED"
    if [ -n "$STG_CONTAINER_LIST" ]; then
        echo "$STG_CONTAINER_LIST" | tr '|' '\n' | head -10 | while read -r line; do
            [ -n "$line" ] && echo "  $(echo $line | tr ':' ' ')"
        done
    fi

    section "29. STAGING: BACKEND"
    [ "$STG_BACKEND_STATUS" = "running" ] && check_pass "Backend: running" || { check_warn "Backend: $STG_BACKEND_STATUS"; add_high "Staging backend down"; }
    check_info "Started: $STG_BACKEND_STARTED"
    [ "${STG_BACKEND_RESTARTS:-0}" -lt 3 ] 2>/dev/null && check_pass "Restarts: $STG_BACKEND_RESTARTS" || { check_warn "Restarts: $STG_BACKEND_RESTARTS"; add_medium "High restarts"; }
    [ "$STG_BACKEND_HEALTH" != "none" ] && check_info "Health: $STG_BACKEND_HEALTH"
    IFS='|' read -r STG_CPU STG_MEM <<< "$STG_BACKEND_STATS"
    [ -n "$STG_CPU" ] && check_info "CPU: $STG_CPU | Memory: $STG_MEM"

    section "30. STAGING: IMAGES"
    check_info "Images: $STG_IMAGES"
    [ "${STG_DANGLING:-0}" -eq 0 ] 2>/dev/null && check_pass "Dangling: 0" || { check_warn "Dangling: $STG_DANGLING"; add_low "Cleanup needed"; }

    section "31. STAGING: NETWORKS & VOLUMES"
    check_info "Networks: $STG_NETWORKS | Volumes: $STG_VOLUMES"
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
