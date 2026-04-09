#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║     TOVPLAY SEQUENTIAL REALTIME INFRASTRUCTURE AUDIT - 10 SCRIPTS             ║
# ║         Run ONE AT A TIME with FULL REALTIME OUTPUT to Console               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="/mnt/f/study/Devops/Infrastructure_as_Code/ansible/playbooks/tovplay/updates"
AUDIT_START=$(date +%s)

# Scripts to run (in order)
declare -a SCRIPTS=(
    "frontend_report.sh:Frontend"
    "backend_report.sh:Backend"
    "docker_report.sh:Docker"
    "nginx_report.sh:Nginx"
    "db_report.sh:Database"
    "cicd_report.sh:CI/CD"
    "production_report.sh:Production"
    "staging_report.sh:Staging"
    "deep_security_report.sh:Security"
    "full_infrastructure_audit.sh:Infrastructure"
)

# ═══════════════════════════════════════════════════════════════════════════════
# HEADER
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║  🚀 TOVPLAY SEQUENTIAL REALTIME INFRASTRUCTURE AUDIT - 10 SCRIPTS             ║"
echo "║     $(date '+%Y-%m-%d %H:%M:%S') - Each script shows full output instantly          ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

declare -a SCORES
declare -a NAMES
total_score=0
count=0

# ═══════════════════════════════════════════════════════════════════════════════
# RUN SCRIPTS SEQUENTIALLY WITH REALTIME OUTPUT
# ═══════════════════════════════════════════════════════════════════════════════

for item in "${SCRIPTS[@]}"; do
    IFS=':' read -r script name <<<"$item"
    
    # Show which script is running
    echo -e "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}▶ Running: ${name}${NC} (${script})"
    echo -e "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Run script with FULL REALTIME output (not buffered)
    script_start=$(date +%s)
    timeout 600 bash "$SCRIPT_DIR/$script" 2>&1
    script_end=$(date +%s)
    script_duration=$((script_end - script_start))
    
    # Extract score from last few lines (after full output)
    output=$(timeout 600 bash "$SCRIPT_DIR/$script" 2>&1)
    score=$(echo "$output" | grep -oP '[A-Z_]+SCORE:\K[0-9]+' | head -1)
    
    if [ -z "$score" ]; then
        score="N/A"
    fi
    
    SCORES+=("$score")
    NAMES+=("$name")
    
    if [ "$score" != "N/A" ]; then
        total_score=$((total_score + score))
        count=$((count + 1))
    fi
    
    # Show completion status
    if [ "$score" != "N/A" ]; then
        if [ "$score" -ge 90 ]; then
            color="$GREEN"
            status="EXCELLENT"
        elif [ "$score" -ge 75 ]; then
            color="$GREEN"
            status="GOOD"
        elif [ "$score" -ge 60 ]; then
            color="$YELLOW"
            status="FAIR"
        else
            color="$RED"
            status="NEEDS IMPROVEMENT"
        fi
        echo -e "\n${color}✓ ${name} Complete${NC} | Score: ${color}${score}/100${NC} (${status}) | Duration: ${script_duration}s\n"
    else
        echo -e "\n${YELLOW}⚠ ${name} Complete${NC} | Duration: ${script_duration}s\n"
    fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# AGGREGATED RESULTS
# ═══════════════════════════════════════════════════════════════════════════════

AUDIT_END=$(date +%s)
TOTAL_TIME=$((AUDIT_END - AUDIT_START))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}                    📊 COMPREHENSIVE AUDIT SUMMARY                           ${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Display results
for i in "${!NAMES[@]}"; do
    score="${SCORES[$i]}"
    name="${NAMES[$i]}"
    
    if [ "$score" != "N/A" ]; then
        if [ "$score" -ge 90 ]; then
            color="$GREEN"
            status="EXCELLENT"
        elif [ "$score" -ge 75 ]; then
            color="$GREEN"
            status="GOOD"
        elif [ "$score" -ge 60 ]; then
            color="$YELLOW"
            status="FAIR"
        else
            color="$RED"
            status="NEEDS IMPROVEMENT"
        fi
        printf "%-20s │ ${color}%3d/100${NC} %-18s\n" "$name" "$score" "$status"
    else
        printf "%-20s │ N/A\n" "$name"
    fi
done

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"

# Calculate statistics
if [ "$count" -gt 0 ]; then
    average=$((total_score / count))
    
    if [ "$average" -ge 90 ]; then
        overall_color="$GREEN"
        overall_status="EXCELLENT"
    elif [ "$average" -ge 75 ]; then
        overall_color="$GREEN"
        overall_status="GOOD"
    elif [ "$average" -ge 60 ]; then
        overall_color="$YELLOW"
        overall_status="FAIR"
    else
        overall_color="$RED"
        overall_status="NEEDS IMPROVEMENT"
    fi
    
    echo ""
    echo -e "${BOLD}Aggregate Results:${NC}"
    echo -e "  Average Score: ${BLUE}${average}/100${NC}"
    echo -e "  Overall Status: ${overall_color}${overall_status}${NC}"
    echo ""
fi

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}⚡ Execution Performance:${NC}"
echo -e "  Total Time: ${BOLD}${MINUTES}m ${SECONDS}s${NC}"
echo -e "  Scripts Run: ${BLUE}${#SCRIPTS[@]}${NC} (sequentially, full realtime output)"
echo ""

echo -e "${GREEN}✓ All audits complete!${NC}\n"

exit 0
