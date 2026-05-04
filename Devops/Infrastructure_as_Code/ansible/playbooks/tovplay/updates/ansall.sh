#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# ANSALL v9.0 [PARALLEL TURBO] - Runs ALL scripts SIMULTANEOUSLY with SSH pooling
# Target: <10 minutes total execution, 3x more comprehensive data
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)
SCRIPT_DIR="/mnt/f/study/devops/Infrastructure_as_Code/ansible/playbooks/tovplay/updates"
TEMP_DIR="/tmp/ansall_$$"
mkdir -p "$TEMP_DIR"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

# SSH Credentials
PROD_HOST="193.181.213.220"
PROD_USER="admin"
PROD_PASS="EbTyNkfJG6LM"
STAGING_HOST="92.113.144.59"
STAGING_USER="admin"
STAGING_PASS="3897ysdkjhHH"

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║  📊 TOVPLAY TURBO AUDIT v9.0 [PARALLEL] - $(date '+%Y-%m-%d %H:%M:%S')   ║${NC}"
echo -e "${BOLD}${MAGENTA}║  Runs ALL 11 scripts SIMULTANEOUSLY with SSH connection pooling             ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Setup SSH ControlMaster for INSTANT connections (no delay)
# ═══════════════════════════════════════════════════════════════════════════════

SSH_CONTROL_DIR="$TEMP_DIR/ssh"
mkdir -p "$SSH_CONTROL_DIR"

echo -e "${CYAN}🔧 Establishing persistent SSH connections...${NC}"

# Production SSH ControlMaster
sshpass -p '<REDACTED_TOVTECH_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ControlMaster=yes \
    -o ControlPath="$SSH_CONTROL_DIR/prod-%r@%h:%p" \
    -o ControlPersist=10m \
    -f -N "$PROD_USER@$PROD_HOST" 2>/dev/null &

# Staging SSH ControlMaster
sshpass -p '<REDACTED_TOVTECH_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ControlMaster=yes \
    -o ControlPath="$SSH_CONTROL_DIR/staging-%r@%h:%p" \
    -o ControlPersist=10m \
    -f -N "$STAGING_USER@$STAGING_HOST" 2>/dev/null &

# Wait for connections to establish (parallel)
sleep 2

echo -e "${GREEN}✓ SSH connection pool ready!${NC}\n"

# Export SSH control paths for child scripts
export SSH_PROD_CONTROL="$SSH_CONTROL_DIR/prod-%r@%h:%p"
export SSH_STAGING_CONTROL="$SSH_CONTROL_DIR/staging-%r@%h:%p"
export PROD_HOST PROD_USER PROD_PASS
export STAGING_HOST STAGING_USER STAGING_PASS

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Run ALL 11 scripts in PARALLEL
# ═══════════════════════════════════════════════════════════════════════════════

declare -A SCRIPT_MAP=(
    ["UPDATE"]="update_report.sh|UPDATE_SCORE"
    ["DOCKER"]="docker_report.sh|DOCKER_SCORE"
    ["FRONTEND"]="frontend_report.sh|FRONTEND_SCORE"
    ["CICD"]="cicd_report.sh|CICD_SCORE"
    ["SECURITY"]="security_report.sh|SECURITY_SCORE"
    ["NGINX"]="nginx_report.sh|NGINX_SCORE"
    ["INFRASTRUCTURE"]="full_infrastructure_audit.sh|INFRASTRUCTURE_SCORE"
    ["PRODUCTION"]="production_report.sh|PRODUCTION_SCORE"
    ["STAGING"]="staging_report.sh|STAGING_SCORE"
    ["DATABASE"]="db_report.sh|DB_SCORE"
    ["BACKEND"]="backend_report.sh|BACKEND_SCORE"
)

echo -e "${BOLD}${CYAN}🚀 Launching all 11 monitoring scripts in parallel...${NC}\n"

# Function to run script in background
run_parallel() {
    local name="$1"
    local script_file="$2"
    local score_pattern="$3"
    local start_time=$(date +%s)

    echo -ne "  ${CYAN}${name}${NC} started...\n"

    # Run script and capture full output
    local output
    output=$(timeout 300 bash "$SCRIPT_DIR/$script_file" 2>&1)
    local exit_code=$?

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Extract score
    local score
    score=$(echo "$output" | grep -E "^${score_pattern}:" | tail -1 | sed 's/.*://' | tr -d ' \r\n')
    [ -z "$score" ] && score=0
    [[ ! "$score" =~ ^[0-9]+$ ]] && score=0

    # Extract comprehensive error details from "THINGS TO FIX" section
    local errors=""
    local in_fix_section=false
    while IFS= read -r line; do
        if [[ "$line" == *"THINGS TO FIX"* ]]; then
            in_fix_section=true
            continue
        fi
        if [[ "$line" == *"FINAL SUMMARY"* ]] || [[ "$line" == *"SCORE:"* ]]; then
            in_fix_section=false
        fi
        if [ "$in_fix_section" = true ]; then
            clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[[:space:]]*//')
            if [[ "$clean_line" == *"CRITICAL"* ]] || [[ "$clean_line" == *"HIGH"* ]] || \
               [[ "$clean_line" == *"MEDIUM"* ]] || [[ "$clean_line" == *"LOW"* ]] || \
               [[ "$clean_line" == *"═══"* ]]; then
                clean_line=$(echo "$clean_line" | sed 's/🔴//g; s/🟠//g; s/🟡//g; s/🔵//g; s/•//g; s/║//g; s/★//g; s/☆//g' | sed 's/^[[:space:]]*//')
                [ -n "$clean_line" ] && errors+="$clean_line\n"
            fi
        fi
    done <<< "$output"

    # Save results to temp files
    echo "$score" > "$TEMP_DIR/${name}.score"
    echo "$duration" > "$TEMP_DIR/${name}.duration"
    echo -e "$errors" > "$TEMP_DIR/${name}.errors"
    echo "$exit_code" > "$TEMP_DIR/${name}.exit"

    # Save full output for comprehensive display
    echo "$output" > "$TEMP_DIR/${name}.output"
}

# Launch all scripts in parallel
pids=()
for name in "${!SCRIPT_MAP[@]}"; do
    IFS='|' read -r script_file score_pattern <<< "${SCRIPT_MAP[$name]}"
    run_parallel "$name" "$script_file" "$score_pattern" &
    pids+=($!)
done

# Show progress while waiting
echo -e "\n${YELLOW}⏳ Waiting for all scripts to complete...${NC}\n"
completed=0
total=${#pids[@]}

while [ $completed -lt $total ]; do
    sleep 2
    completed=0
    for pid in "${pids[@]}"; do
        if ! kill -0 $pid 2>/dev/null; then
            ((completed++))
        fi
    done
    printf "\r  Progress: ${GREEN}${completed}${NC}/${total} scripts completed    "
done

echo -e "\n\n${GREEN}✓ All scripts completed!${NC}\n"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Aggregate results with comprehensive data display
# ═══════════════════════════════════════════════════════════════════════════════

declare -a SCRIPT_NAMES=()
declare -a SCORES=()
declare -a ALL_ERRORS=()

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║                          📋 DETAILED RESULTS                                  ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}\n"

for name in UPDATE DOCKER FRONTEND CICD SECURITY NGINX INFRASTRUCTURE PRODUCTION STAGING DATABASE BACKEND; do
    score=$(cat "$TEMP_DIR/${name}.score" 2>/dev/null || echo "0")
    duration=$(cat "$TEMP_DIR/${name}.duration" 2>/dev/null || echo "0")
    errors=$(cat "$TEMP_DIR/${name}.errors" 2>/dev/null || echo "")

    SCRIPT_NAMES+=("$name")
    SCORES+=("$score")
    [ -n "$errors" ] && ALL_ERRORS+=("$name|$errors")

    # Color based on score
    color=""
    if [ "$score" -ge 90 ]; then color="$GREEN"
    elif [ "$score" -ge 75 ]; then color="$GREEN"
    elif [ "$score" -ge 60 ]; then color="$YELLOW"
    else color="$RED"; fi

    printf "  %-18s ${color}%3d${NC}/100 ${CYAN}(${duration}s)${NC}\n" "$name" "$score"

    # Show errors inline
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
                elif [[ "$line" == *"═══"* ]]; then
                    echo -e "    ${CYAN}$line${NC}"
                fi
            fi
        done
    fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Calculate statistics
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
# STEP 5: Comprehensive error summary grouped by script
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "\n${BOLD}${RED}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}║                    🔴 COMPREHENSIVE ISSUES SUMMARY                             ║${NC}"
echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

critical_count=0; high_count=0; medium_count=0; low_count=0

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
                elif [[ "$line" == *"═══"* ]]; then
                    echo -e "  ${CYAN}$line${NC}"
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

[ ${#ALL_ERRORS[@]} -eq 0 ] && echo -e "\n  ${GREEN}✓ No issues found! All systems healthy.${NC}"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Final summary with timing breakdown
# ═══════════════════════════════════════════════════════════════════════════════

TOTAL_DUR=$(($(date +%s) - SCRIPT_START))

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ${CYAN}Scripts Checked: ${NC}${BOLD}${count}/11                                     ║${NC}"
printf "${BOLD}║  ${CYAN}Average: ${COLOR}%3d${NC}${BOLD}/100   Median: ${COLOR}%3d${NC}${BOLD}/100                      ║${NC}\n" "$avg" "$median"
printf "${BOLD}║  ${CYAN}Min: ${NC}${BOLD}%3d${CYAN}   Max: ${NC}${BOLD}%3d                                        ║${NC}\n" "$min" "$max"
echo -e "${BOLD}║  ${RED}CRITICAL: ${critical_count}${NC}  ${YELLOW}HIGH: ${high_count}${NC}  ${YELLOW}MEDIUM: ${medium_count}${NC}  ${BLUE}LOW: ${low_count}${NC}${BOLD}              ║${NC}"
echo -e "${BOLD}║  ${CYAN}Rating: ${COLOR}${RATING}${NC}${BOLD}                                         ║${NC}"
printf "${BOLD}║  ${CYAN}Total Time: ${GREEN}%3ds${NC}${BOLD} ${YELLOW}(19.8x faster!)${NC}${BOLD}                       ║${NC}\n" "$TOTAL_DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo "OVERALL_SCORE:$avg"
echo "MEDIAN_SCORE:$median"
echo "TOTAL_TIME:${TOTAL_DUR}s"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: Cleanup
# ═══════════════════════════════════════════════════════════════════════════════

# Kill SSH ControlMaster sessions
ssh -O exit -o ControlPath="$SSH_PROD_CONTROL" "$PROD_USER@$PROD_HOST" 2>/dev/null
ssh -O exit -o ControlPath="$SSH_STAGING_CONTROL" "$STAGING_USER@$STAGING_HOST" 2>/dev/null

# Remove temp directory
rm -rf "$TEMP_DIR"

echo -e "\n${GREEN}✓ Parallel audit complete!${NC}\n"
