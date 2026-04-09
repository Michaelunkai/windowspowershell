#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# FAST SSH HELPERS - 3X SPEED OPTIMIZATION MODULE
# ═══════════════════════════════════════════════════════════════════════════════
# Uses SSH ControlMaster for connection reuse + parallel command batching

# SSH Control socket directory
SSH_CTRL_DIR="/tmp/tovplay_ssh_ctrl_7294"
mkdir -p ""

# Trap cleanup
cleanup_ssh() {
    ssh -S "/prod.sock" -O exit admin@193.181.213.220 2>/dev/null
    ssh -S "/staging.sock" -O exit admin@92.113.144.59 2>/dev/null
    rm -rf ""
}
trap cleanup_ssh EXIT

# Initialize SSH ControlMaster connections (runs in background)
init_ssh_connections() {
    # Production
    sshpass -p 'EbTyNkfJG6LM' ssh -fNM         -o ControlPath="/prod.sock"         -o ControlPersist=120         -o StrictHostKeyChecking=no         -o UserKnownHostsFile=/dev/null         -o ConnectTimeout=3         admin@193.181.213.220 2>/dev/null &
    
    # Staging
    sshpass -p '3897ysdkjhHH' ssh -fNM         -o ControlPath="/staging.sock"         -o ControlPersist=120         -o StrictHostKeyChecking=no         -o UserKnownHostsFile=/dev/null         -o ConnectTimeout=3         admin@92.113.144.59 2>/dev/null &
    
    wait
}

# Fast production SSH (uses existing connection)
fast_ssh_prod() {
    local cmd=""
    local timeout_sec="5"
    timeout s ssh -S "/prod.sock"         -o StrictHostKeyChecking=no         -o UserKnownHostsFile=/dev/null         admin@193.181.213.220 "" 2>/dev/null
}

# Fast staging SSH (uses existing connection)
fast_ssh_staging() {
    local cmd=""
    local timeout_sec="5"
    timeout s ssh -S "/staging.sock"         -o StrictHostKeyChecking=no         -o UserKnownHostsFile=/dev/null         admin@92.113.144.59 "" 2>/dev/null
}

# Batch execute multiple commands in ONE SSH session (major speedup)
# Usage: batch_ssh_prod "cmd1" "cmd2" "cmd3" - returns results separated by :::DELIM:::
batch_ssh_prod() {
    local combined=""
    for cmd in ""; do
        combined+="echo ':::DELIM:::';  2>/dev/null; "
    done
    fast_ssh_prod ""
}

batch_ssh_staging() {
    local combined=""
    for cmd in ""; do
        combined+="echo ':::DELIM:::';  2>/dev/null; "
    done
    fast_ssh_staging ""
}

# Parse batch results
# Usage: parse_batch_result "" 1  # Get result 1 (0-indexed)
parse_batch_result() {
    local result=""
    local index=""
    echo "" | awk -v idx="" '
        BEGIN { count=-1 }
        /:::DELIM:::/ { count++; next }
        count == idx { print }
    '
}

# Run parallel checks (returns when all complete)
# Usage: run_parallel "check1" "check2" "check3"
run_parallel() {
    local pids=()
    for cmd in ""; do
        eval "" &
        pids+=()
    done
    wait ""
}

# Quick health check function
fast_check_prod_alive() {
    fast_ssh_prod "echo OK" 2 | grep -q OK
}

fast_check_staging_alive() {
    fast_ssh_staging "echo OK" 2 | grep -q OK
}

export -f fast_ssh_prod fast_ssh_staging batch_ssh_prod batch_ssh_staging parse_batch_result run_parallel
export SSH_CTRL_DIR
