#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# ANSALL - Master Aggregator v5.1 [3X SPEED OPTIMIZED]
# Runs ALL 11 monitoring scripts and aggregates results
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="/mnt/f/study/Devops/Infrastructure_as_Code/ansible/playbooks/tovplay/updates"

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     📊 TOVPLAY MASTER AUDIT v5.1 [3X SPEED] - $(date '+%Y-%m-%d %H:%M:%S')     ║${NC}"
echo -e "${BOLD}${MAGENTA}║     Running ALL 11 Monitoring Scripts                                         ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

declare -a SCORES=()
declare -a SCRIPT_NAMES=()
declare -a SCRIPT_TIMES=()
TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0

# Scripts to run in order
SCRIPTS=(
    "update_report.sh:UPDATE"
    "docker_report.sh:DOCKER"
    "frontend_report.sh:FRONTEND"
    "cicd_report.sh:CICD"
    "deep_security_report.sh:SECURITY"
    "nginx_report.sh:NGINX"
    "full_infrastructure_audit.sh:INFRASTRUCTURE"
    "production_report.sh:PRODUCTION"
    "staging_report.sh:STAGING"
    "db_report.sh:DATABASE"
    "backend_report.sh:BACKEND"
)

run_script() {
    local script="$1"
    local name="$2"
    local start_time=$(date +%s)

    echo -e "\n${BOLD}${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  Running: ${name} (${script})${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"

    if [ -f "$SCRIPT_DIR/$script" ]; then
        # Run script and capture output
        output=$(bash "$SCRIPT_DIR/$script" 2>&1)
        echo "$output"

        # Extract score from output (looks for SCORE_NAME:XX pattern)
        score=$(echo "$output" | grep -oE "${name}_SCORE:[0-9]+" | tail -1 | cut -d: -f2)
        # Also try generic patterns
        if [ -z "$score" ]; then
            score=$(echo "$output" | grep -oE "[A-Z_]+_SCORE:[0-9]+" | tail -1 | cut -d: -f2)
        fi

        if [ -n "$score" ]; then
            SCORES+=("$score")
            SCRIPT_NAMES+=("$name")
        fi

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        SCRIPT_TIMES+=("$duration")

        echo -e "\n${CYAN}  ⏱️ ${name} completed in ${duration}s${NC}"
    else
        echo -e "${RED}  ✗ Script not found: $script${NC}"
        SCORES+=("0")
        SCRIPT_NAMES+=("$name")
        SCRIPT_TIMES+=("0")
    fi
}

# Run all scripts
for entry in "${SCRIPTS[@]}"; do
    script="${entry%%:*}"
    name="${entry##*:}"
    run_script "$script" "$name"
done

# ═══════════════════════════════════════════════════════════════════════════════
# AGGREGATE RESULTS
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "\n\n${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║                        📊 AGGREGATE RESULTS                                    ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

# Calculate statistics
total=0
count=0
min=100
max=0

for score in "${SCORES[@]}"; do
    if [ -n "$score" ] && [ "$score" -gt 0 ] 2>/dev/null; then
        total=$((total + score))
        count=$((count + 1))
        [ "$score" -lt "$min" ] && min=$score
        [ "$score" -gt "$max" ] && max=$score
    fi
done

if [ $count -gt 0 ]; then
    avg=$((total / count))

    # Sort scores for median
    sorted_scores=($(printf '%s\n' "${SCORES[@]}" | sort -n))
    mid=$((count / 2))
    if [ $((count % 2)) -eq 0 ]; then
        median=$(( (sorted_scores[mid-1] + sorted_scores[mid]) / 2 ))
    else
        median=${sorted_scores[mid]}
    fi
else
    avg=0
    median=0
    min=0
    max=0
fi

# Print individual scores
echo -e "\n${BOLD}${CYAN}Individual Scores:${NC}"
echo -e "  ${BOLD}Script              Score   Time${NC}"
echo -e "  ─────────────────────────────────"
for i in "${!SCRIPT_NAMES[@]}"; do
    name="${SCRIPT_NAMES[$i]}"
    score="${SCORES[$i]}"
    time="${SCRIPT_TIMES[$i]}"

    if [ "${score:-0}" -ge 90 ] 2>/dev/null; then
        color="$GREEN"
    elif [ "${score:-0}" -ge 75 ] 2>/dev/null; then
        color="$GREEN"
    elif [ "${score:-0}" -ge 60 ] 2>/dev/null; then
        color="$YELLOW"
    else
        color="$RED"
    fi

    printf "  %-18s ${color}%3s${NC}     %3ss\n" "$name" "${score:-?}" "${time:-?}"
done

# Overall rating
if [ $avg -ge 90 ]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [ $avg -ge 75 ]; then RATING="GOOD"; COLOR="$GREEN"
elif [ $avg -ge 60 ]; then RATING="FAIR"; COLOR="$YELLOW"
else RATING="NEEDS WORK"; COLOR="$RED"; fi

TOTAL_DUR=$(($(date +%s) - SCRIPT_START))

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ${CYAN}Scripts Run: ${NC}${BOLD}${count}/11                                        ║${NC}"
echo -e "${BOLD}║  ${CYAN}Average: ${COLOR}${avg}/100${NC}${BOLD}   Median: ${COLOR}${median}/100${NC}${BOLD}                      ║${NC}"
echo -e "${BOLD}║  ${CYAN}Min: ${min}${NC}${BOLD}   Max: ${max}                                        ║${NC}"
echo -e "${BOLD}║  ${CYAN}Rating: ${COLOR}${RATING}${NC}${BOLD}                                         ║${NC}"
echo -e "${BOLD}║  ${CYAN}Total Time: ${TOTAL_DUR}s${NC}${BOLD}                                        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo "OVERALL_SCORE:$avg"
echo "TOTAL_TIME:${TOTAL_DUR}s"
