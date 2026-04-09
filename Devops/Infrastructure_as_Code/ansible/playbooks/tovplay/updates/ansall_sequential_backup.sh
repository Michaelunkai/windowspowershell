#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# ANSALL v8.1 [ACCURATE] - Runs ALL actual scripts and extracts REAL scores
# Target: <5 minutes total execution
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)
SCRIPT_DIR="/mnt/f/study/devops/Infrastructure_as_Code/ansible/playbooks/tovplay/updates"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     📊 TOVPLAY MASTER AUDIT v8.1 [ACCURATE] - $(date '+%Y-%m-%d %H:%M:%S')    ║${NC}"
echo -e "${BOLD}${MAGENTA}║     Runs ALL scripts and extracts REAL scores + ALL errors                    ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Arrays to store results
declare -a SCRIPT_NAMES=()
declare -a SCORES=()
declare -a ALL_ERRORS=()

# Function to run script and extract score + errors
run_script() {
    local script_name="$1"
    local script_file="$2"
    local score_pattern="$3"

    echo -ne "  Running ${CYAN}${script_name}${NC}..."

    # Run script and capture output
    local output
    output=$(bash "$SCRIPT_DIR/$script_file" 2>/dev/null)

    # Extract score - look for pattern like "SCORE:XX" or "SCORE: XX"
    local score
    score=$(echo "$output" | grep -E "^${score_pattern}:" | tail -1 | sed 's/.*://' | tr -d ' \r\n')

    # Default to 0 if no score found
    [ -z "$score" ] && score=0
    [[ ! "$score" =~ ^[0-9]+$ ]] && score=0

    # Extract errors from "THINGS TO FIX" section
    local errors=""
    local in_fix_section=false
    while IFS= read -r line; do
        # Check if we're entering the THINGS TO FIX section
        if [[ "$line" == *"THINGS TO FIX"* ]]; then
            in_fix_section=true
            continue
        fi
        # Check if we're exiting (FINAL SUMMARY)
        if [[ "$line" == *"FINAL SUMMARY"* ]]; then
            in_fix_section=false
        fi
        # Extract errors in the section
        if [ "$in_fix_section" = true ]; then
            # Clean ANSI codes
            clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[[:space:]]*//')
            if [[ "$clean_line" == *"CRITICAL"* ]] || [[ "$clean_line" == *"HIGH"* ]] || [[ "$clean_line" == *"MEDIUM"* ]] || [[ "$clean_line" == *"LOW"* ]]; then
                # Remove emoji and extra spaces
                clean_line=$(echo "$clean_line" | sed 's/🔴//g; s/🟠//g; s/🟡//g; s/🔵//g; s/•//g' | sed 's/^[[:space:]]*//')
                if [ -n "$clean_line" ]; then
                    errors+="$clean_line\n"
                fi
            fi
        fi
    done <<< "$output"

    # Store results
    SCRIPT_NAMES+=("$script_name")
    SCORES+=("$score")
    [ -n "$errors" ] && ALL_ERRORS+=("$script_name|$errors")

    # Determine color based on score
    local color
    if [ "$score" -ge 90 ] 2>/dev/null; then color="$GREEN"
    elif [ "$score" -ge 75 ] 2>/dev/null; then color="$GREEN"
    elif [ "$score" -ge 60 ] 2>/dev/null; then color="$YELLOW"
    else color="$RED"; fi

    # Clear the "Running..." line and print result
    echo -ne "\r\033[K"
    printf "  %-18s ${color}%3d${NC}/100\n" "$script_name" "$score"

    # Print errors under the score in RED
    if [ -n "$errors" ]; then
        echo -e "$errors" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                if [[ "$line" == *"CRITICAL"* ]]; then
                    echo -e "    ${RED}🔴 $line${NC}"
                elif [[ "$line" == *"HIGH"* ]]; then
                    echo -e "    ${RED}🟠 $line${NC}"
                elif [[ "$line" == *"MEDIUM"* ]]; then
                    echo -e "    ${YELLOW}🟡 $line${NC}"
                elif [[ "$line" == *"LOW"* ]]; then
                    echo -e "    ${BLUE}🔵 $line${NC}"
                fi
            fi
        done
    fi
}

echo -e "${BOLD}${CYAN}Running all monitoring scripts...${NC}\n"

# Run each script and extract its actual score
run_script "UPDATE" "update_report.sh" "UPDATE_SCORE"
run_script "DOCKER" "docker_report.sh" "DOCKER_SCORE"
run_script "FRONTEND" "frontend_report.sh" "FRONTEND_SCORE"
run_script "CICD" "cicd_report.sh" "CICD_SCORE"
run_script "SECURITY" "deep_security_report.sh" "SECURITY_SCORE"
run_script "NGINX" "nginx_report.sh" "NGINX_SCORE"
run_script "INFRASTRUCTURE" "full_infrastructure_audit.sh" "INFRASTRUCTURE_SCORE"
run_script "PRODUCTION" "production_report.sh" "PRODUCTION_SCORE"
run_script "STAGING" "staging_report.sh" "STAGING_SCORE"
run_script "DATABASE" "db_report.sh" "DB_SCORE"
run_script "BACKEND" "backend_report.sh" "BACKEND_SCORE"

# ═══════════════════════════════════════════════════════════════════════════════
# CALCULATE STATISTICS
# ═══════════════════════════════════════════════════════════════════════════════

total=0; count=0; min=100; max=0

for score in "${SCORES[@]}"; do
    if [ -n "$score" ] && [ "$score" -ge 0 ] 2>/dev/null; then
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
    avg=0; median=0; min=0; max=0
fi

# Overall rating
if [ $avg -ge 90 ]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [ $avg -ge 75 ]; then RATING="GOOD"; COLOR="$GREEN"
elif [ $avg -ge 60 ]; then RATING="FAIR"; COLOR="$YELLOW"
else RATING="NEEDS WORK"; COLOR="$RED"; fi

# ═══════════════════════════════════════════════════════════════════════════════
# FULL ERROR SUMMARY (ALL RED ISSUES)
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "\n${BOLD}${RED}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}║                    🔴 ALL ISSUES SUMMARY                                       ║${NC}"
echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

critical_count=0
high_count=0
medium_count=0
low_count=0

# Display all issues grouped by script
for item in "${ALL_ERRORS[@]}"; do
    script="${item%%|*}"
    errors="${item#*|}"

    if [ -n "$errors" ]; then
        echo -e "\n${BOLD}${CYAN}$script:${NC}"
        echo -e "$errors" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                if [[ "$line" == *"CRITICAL"* ]]; then
                    echo -e "  ${RED}🔴 $line${NC}"
                elif [[ "$line" == *"HIGH"* ]]; then
                    echo -e "  ${RED}🟠 $line${NC}"
                elif [[ "$line" == *"MEDIUM"* ]]; then
                    echo -e "  ${YELLOW}🟡 $line${NC}"
                elif [[ "$line" == *"LOW"* ]]; then
                    echo -e "  ${BLUE}🔵 $line${NC}"
                fi
            fi
        done
    fi
done

# Count issues
for item in "${ALL_ERRORS[@]}"; do
    errors="${item#*|}"
    while IFS= read -r line; do
        [[ "$line" == *"CRITICAL"* ]] && ((critical_count++))
        [[ "$line" == *"HIGH"* ]] && ((high_count++))
        [[ "$line" == *"MEDIUM"* ]] && ((medium_count++))
        [[ "$line" == *"LOW"* ]] && ((low_count++))
    done <<< "$errors"
done

if [ ${#ALL_ERRORS[@]} -eq 0 ]; then
    echo -e "\n  ${GREEN}✓ No issues found! All systems healthy.${NC}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY BOX
# ═══════════════════════════════════════════════════════════════════════════════

TOTAL_DUR=$(($(date +%s) - SCRIPT_START))

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ${CYAN}Scripts Checked: ${NC}${BOLD}${count}/11                                     ║${NC}"
printf "${BOLD}║  ${CYAN}Average: ${COLOR}%3d${NC}${BOLD}/100   Median: ${COLOR}%3d${NC}${BOLD}/100                      ║${NC}\n" "$avg" "$median"
printf "${BOLD}║  ${CYAN}Min: ${NC}${BOLD}%3d${CYAN}   Max: ${NC}${BOLD}%3d                                        ║${NC}\n" "$min" "$max"
echo -e "${BOLD}║  ${RED}CRITICAL: ${critical_count}${NC}  ${YELLOW}HIGH: ${high_count}${NC}  ${YELLOW}MEDIUM: ${medium_count}${NC}  ${BLUE}LOW: ${low_count}${NC}${BOLD}              ║${NC}"
echo -e "${BOLD}║  ${CYAN}Rating: ${COLOR}${RATING}${NC}${BOLD}                                         ║${NC}"
printf "${BOLD}║  ${CYAN}Total Time: ${NC}${BOLD}%3ds${NC}${BOLD}                                       ║${NC}\n" "$TOTAL_DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo "OVERALL_SCORE:$avg"
echo "MEDIAN_SCORE:$median"
echo "TOTAL_TIME:${TOTAL_DUR}s"
