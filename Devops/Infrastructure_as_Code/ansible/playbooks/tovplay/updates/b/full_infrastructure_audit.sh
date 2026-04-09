#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# INFRASTRUCTURE AUDIT v5.1 [3X SPEED OPTIMIZED] - SSH Batching Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"; STAGING_USER="admin"; STAGING_PASS="3897ysdkjhHH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
SCORE=100

SSH_CTRL="/tmp/tovplay_infra_$$"
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
echo -e "${BOLD}${MAGENTA}║     🖥️ INFRASTRUCTURE AUDIT v5.1 [3X SPEED] - $(date '+%Y-%m-%d %H:%M:%S')    ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

init_connections

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 3); STAGING_OK=$(ssh_staging "echo OK" 3)
[ "$PROD_OK" = "OK" ] && { check_pass "Production: connected"; PROD_CONN=true; } || { check_fail "Production: failed"; add_critical "SSH failed"; PROD_CONN=false; }
[ "$STAGING_OK" = "OK" ] && { check_pass "Staging: connected"; STAGING_CONN=true; } || { STAGING_CONN=false; }

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 1: SYSTEM INFO, CPU, MEMORY, DISK
# ═══════════════════════════════════════════════════════════════════════════════
section "2-8. SYSTEM RESOURCES"
if [ "$PROD_CONN" = true ]; then
    BATCH1=$(ssh_prod 'echo ":::HOSTNAME:::"; hostname
echo ":::OS:::"; cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d"\"" -f2
echo ":::KERNEL:::"; uname -r
echo ":::UPTIME:::"; uptime -p
echo ":::LOAD:::"; cat /proc/loadavg | cut -d" " -f1-3
echo ":::CPU_CORES:::"; nproc
echo ":::CPU_MODEL:::"; grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2
echo ":::MEM_TOTAL:::"; free -h | awk "/Mem:/{print \$2}"
echo ":::MEM_USED:::"; free -h | awk "/Mem:/{print \$3}"
echo ":::MEM_AVAIL:::"; free -h | awk "/Mem:/{print \$7}"
echo ":::MEM_PCT:::"; free | awk "/Mem:/{printf \"%.0f\", \$3/\$2*100}"
echo ":::SWAP_TOTAL:::"; free -h | awk "/Swap:/{print \$2}"
echo ":::SWAP_USED:::"; free -h | awk "/Swap:/{print \$3}"
echo ":::DISK_ROOT:::"; df -h / | awk "NR==2{print \$2,\$3,\$4,\$5}"
echo ":::DISK_PCT:::"; df -h / | awk "NR==2{print \$5}" | tr -d "%"
echo ":::INODES:::"; df -i / | awk "NR==2{print \$5}"
echo ":::TOP_DIRS:::"; du -sh /var/log /var/www /root /tmp 2>/dev/null | head -4
echo ":::PROCESSES:::"; ps aux | wc -l
echo ":::ZOMBIE:::"; ps aux | awk "\$8~/Z/{print}" | wc -l
echo ":::TOP_CPU:::"; ps aux --sort=-%cpu | head -3 | tail -2 | awk "{print \$11,\$3\"%\"}"
echo ":::TOP_MEM:::"; ps aux --sort=-%mem | head -3 | tail -2 | awk "{print \$11,\$4\"%\"}"' 15)

    HOSTNAME=$(echo "$BATCH1" | sed -n '/:::HOSTNAME:::/,/:::OS:::/p' | tail -1)
    OS=$(echo "$BATCH1" | sed -n '/:::OS:::/,/:::KERNEL:::/p' | tail -1)
    KERNEL=$(echo "$BATCH1" | sed -n '/:::KERNEL:::/,/:::UPTIME:::/p' | tail -1)
    UPTIME=$(echo "$BATCH1" | sed -n '/:::UPTIME:::/,/:::LOAD:::/p' | tail -1)
    LOAD=$(echo "$BATCH1" | sed -n '/:::LOAD:::/,/:::CPU_CORES:::/p' | tail -1)
    CPU_CORES=$(echo "$BATCH1" | sed -n '/:::CPU_CORES:::/,/:::CPU_MODEL:::/p' | tail -1)
    MEM_TOTAL=$(echo "$BATCH1" | sed -n '/:::MEM_TOTAL:::/,/:::MEM_USED:::/p' | tail -1)
    MEM_USED=$(echo "$BATCH1" | sed -n '/:::MEM_USED:::/,/:::MEM_AVAIL:::/p' | tail -1)
    MEM_PCT=$(echo "$BATCH1" | sed -n '/:::MEM_PCT:::/,/:::SWAP_TOTAL:::/p' | tail -1)
    DISK_ROOT=$(echo "$BATCH1" | sed -n '/:::DISK_ROOT:::/,/:::DISK_PCT:::/p' | tail -1)
    DISK_PCT=$(echo "$BATCH1" | sed -n '/:::DISK_PCT:::/,/:::INODES:::/p' | tail -1)
    INODES=$(echo "$BATCH1" | sed -n '/:::INODES:::/,/:::TOP_DIRS:::/p' | tail -1)
    PROCESSES=$(echo "$BATCH1" | sed -n '/:::PROCESSES:::/,/:::ZOMBIE:::/p' | tail -1)
    ZOMBIE=$(echo "$BATCH1" | sed -n '/:::ZOMBIE:::/,/:::TOP_CPU:::/p' | tail -1)
    TOP_CPU=$(echo "$BATCH1" | sed -n '/:::TOP_CPU:::/,/:::TOP_MEM:::/p' | grep -v ':::')
    TOP_MEM=$(echo "$BATCH1" | sed -n '/:::TOP_MEM:::/,$p' | grep -v ':::')

    echo -e "${CYAN}System:${NC}"
    check_info "Host: $HOSTNAME | OS: $OS | Kernel: $KERNEL"
    check_info "Uptime: $UPTIME"

    echo -e "\n${CYAN}CPU:${NC}"
    check_info "Cores: $CPU_CORES | Load: $LOAD"
    LOAD1=$(echo "$LOAD" | cut -d' ' -f1)
    [ "$(echo "$LOAD1 > $CPU_CORES" | bc 2>/dev/null)" = "1" ] && { check_warn "High load: $LOAD"; add_high "CPU overloaded"; } || check_pass "CPU load: OK"

    echo -e "\n${CYAN}Memory:${NC}"
    check_info "Total: $MEM_TOTAL | Used: $MEM_USED | Usage: ${MEM_PCT}%"
    [ "${MEM_PCT:-0}" -gt 90 ] 2>/dev/null && { check_fail "Memory critical: ${MEM_PCT}%"; add_critical "Memory >90%"; } || \
    [ "${MEM_PCT:-0}" -gt 80 ] 2>/dev/null && { check_warn "Memory high: ${MEM_PCT}%"; add_high "Memory >80%"; } || check_pass "Memory usage: OK"

    echo -e "\n${CYAN}Disk:${NC}"
    check_info "Root: $DISK_ROOT | Inodes: $INODES"
    [ "${DISK_PCT:-0}" -gt 90 ] 2>/dev/null && { check_fail "Disk critical: ${DISK_PCT}%"; add_critical "Disk >90%"; } || \
    [ "${DISK_PCT:-0}" -gt 80 ] 2>/dev/null && { check_warn "Disk high: ${DISK_PCT}%"; add_high "Disk >80%"; } || check_pass "Disk usage: OK"

    echo -e "\n${CYAN}Processes:${NC}"
    check_info "Running: $PROCESSES | Zombie: $ZOMBIE"
    [ "${ZOMBIE:-0}" -gt 5 ] 2>/dev/null && { check_warn "Zombie processes: $ZOMBIE"; add_low "Zombie processes"; }
    echo -e "  Top CPU: $TOP_CPU"
    echo -e "  Top MEM: $TOP_MEM"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 2: SERVICES & NETWORK
# ═══════════════════════════════════════════════════════════════════════════════
section "9-14. SERVICES & NETWORK"
if [ "$PROD_CONN" = true ]; then
    BATCH2=$(ssh_prod 'echo ":::DOCKER:::"; systemctl is-active docker
echo ":::NGINX:::"; systemctl is-active nginx
echo ":::CRON:::"; systemctl is-active cron
echo ":::SSH:::"; systemctl is-active sshd || systemctl is-active ssh
echo ":::OPEN_PORTS:::"; ss -tlnp | grep LISTEN | awk "{print \$4}" | cut -d: -f2 | sort -u | head -10 | tr "\n" " "
echo ":::CONNECTIONS:::"; ss -s | grep "estab" | head -1
echo ":::INTERFACES:::"; ip -br addr | head -5
echo ":::DNS:::"; cat /etc/resolv.conf 2>/dev/null | grep nameserver | head -2' 10)

    DOCKER=$(echo "$BATCH2" | sed -n '/:::DOCKER:::/,/:::NGINX:::/p' | tail -1)
    NGINX=$(echo "$BATCH2" | sed -n '/:::NGINX:::/,/:::CRON:::/p' | tail -1)
    CRON=$(echo "$BATCH2" | sed -n '/:::CRON:::/,/:::SSH:::/p' | tail -1)
    SSHD=$(echo "$BATCH2" | sed -n '/:::SSH:::/,/:::OPEN_PORTS:::/p' | tail -1)
    PORTS=$(echo "$BATCH2" | sed -n '/:::OPEN_PORTS:::/,/:::CONNECTIONS:::/p' | tail -1)
    CONNECTIONS=$(echo "$BATCH2" | sed -n '/:::CONNECTIONS:::/,/:::INTERFACES:::/p' | tail -1)

    echo -e "${CYAN}Services:${NC}"
    [ "$DOCKER" = "active" ] && check_pass "Docker: active" || { check_fail "Docker: $DOCKER"; add_critical "Docker down"; }
    [ "$NGINX" = "active" ] && check_pass "Nginx: active" || { check_fail "Nginx: $NGINX"; add_critical "Nginx down"; }
    [ "$CRON" = "active" ] && check_pass "Cron: active" || check_warn "Cron: $CRON"
    [ "$SSHD" = "active" ] && check_pass "SSH: active" || check_warn "SSH: $SSHD"

    echo -e "\n${CYAN}Network:${NC}"
    check_info "Open ports: $PORTS"
    check_info "$CONNECTIONS"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STAGING
# ═══════════════════════════════════════════════════════════════════════════════
section "15-16. STAGING"
if [ "$STAGING_CONN" = true ]; then
    BATCH3=$(ssh_staging 'echo ":::LOAD:::"; cat /proc/loadavg | cut -d" " -f1-3
echo ":::MEM:::"; free | awk "/Mem:/{printf \"%.0f\", \$3/\$2*100}"
echo ":::DISK:::"; df -h / | awk "NR==2{print \$5}" | tr -d "%"
echo ":::DOCKER:::"; systemctl is-active docker
echo ":::NGINX:::"; systemctl is-active nginx' 10)

    STG_LOAD=$(echo "$BATCH3" | sed -n '/:::LOAD:::/,/:::MEM:::/p' | tail -1)
    STG_MEM=$(echo "$BATCH3" | sed -n '/:::MEM:::/,/:::DISK:::/p' | tail -1)
    STG_DISK=$(echo "$BATCH3" | sed -n '/:::DISK:::/,/:::DOCKER:::/p' | tail -1)
    STG_DOCKER=$(echo "$BATCH3" | sed -n '/:::DOCKER:::/,/:::NGINX:::/p' | tail -1)
    STG_NGINX=$(echo "$BATCH3" | sed -n '/:::NGINX:::/,$p' | tail -1)

    check_info "Load: $STG_LOAD | Memory: ${STG_MEM}% | Disk: ${STG_DISK}%"
    [ "$STG_DOCKER" = "active" ] && check_pass "Docker: active" || check_warn "Docker: $STG_DOCKER"
    [ "$STG_NGINX" = "active" ] && check_pass "Nginx: active" || check_warn "Nginx: $STG_NGINX"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# COMPARISON
# ═══════════════════════════════════════════════════════════════════════════════
section "17. COMPARISON"
echo -e "  ${BOLD}Metric              Production    Staging${NC}"
echo -e "  ─────────────────────────────────────────────"
printf "  %-18s %-13s %s\n" "Memory" "${MEM_PCT:-?}%" "${STG_MEM:-?}%"
printf "  %-18s %-13s %s\n" "Disk" "${DISK_PCT:-?}%" "${STG_DISK:-?}%"
printf "  %-18s %-13s %s\n" "Docker" "${DOCKER:-?}" "${STG_DOCKER:-?}"
printf "  %-18s %-13s %s\n" "Nginx" "${NGINX:-?}" "${STG_NGINX:-?}"

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
printf "${BOLD}║  INFRA_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds      ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "INFRASTRUCTURE_SCORE:$SCORE"
