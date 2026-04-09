#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# ULTRA-FAST SSH HELPERS v10.0 - ZERO DELAY with ControlMaster Integration
# Works seamlessly with ansall.sh's SSH pool OR standalone - ALWAYS FAST!
# ═══════════════════════════════════════════════════════════════════════════════

# Server credentials
PROD_HOST="${PROD_HOST:-193.181.213.220}"
PROD_USER="${PROD_USER:-admin}"
PROD_PASS="${PROD_PASS:-EbTyNkfJG6LM}"
STAGING_HOST="${STAGING_HOST:-92.113.144.59}"
STAGING_USER="${STAGING_USER:-admin}"
STAGING_PASS="${STAGING_PASS:-3897ysdkjhHH}"

# Ultra-fast SSH to production - uses ansall.sh ControlMaster if available
ssh_prod() {
    local cmd="$1"
    local timeout_val="${2:-15}"

    # Check if ansall.sh has set up ControlMaster (INSTANT connection!)
    if [ -n "$SSH_PROD_CONTROL" ]; then
        # Use existing ControlMaster - NO DELAY!
        sshpass -p "$PROD_PASS" ssh -o ControlPath="$SSH_PROD_CONTROL" \
            -o ConnectTimeout="$timeout_val" \
            "$PROD_USER@$PROD_HOST" "$cmd" 2>/dev/null
    else
        # Standalone mode - direct connection, NO RETRIES, NO SLEEP
        sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout="$timeout_val" \
            -o ServerAliveInterval=10 \
            "$PROD_USER@$PROD_HOST" "$cmd" 2>/dev/null
    fi
}

# Ultra-fast SSH to staging - uses ansall.sh ControlMaster if available
ssh_staging() {
    local cmd="$1"
    local timeout_val="${2:-15}"

    # Check if ansall.sh has set up ControlMaster (INSTANT connection!)
    if [ -n "$SSH_STAGING_CONTROL" ]; then
        # Use existing ControlMaster - NO DELAY!
        sshpass -p "$STAGING_PASS" ssh -o ControlPath="$SSH_STAGING_CONTROL" \
            -o ConnectTimeout="$timeout_val" \
            "$STAGING_USER@$STAGING_HOST" "$cmd" 2>/dev/null
    else
        # Standalone mode - direct connection, NO RETRIES, NO SLEEP
        sshpass -p "$STAGING_PASS" ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout="$timeout_val" \
            -o ServerAliveInterval=10 \
            "$STAGING_USER@$STAGING_HOST" "$cmd" 2>/dev/null
    fi
}

# Batch SSH commands for maximum speed (executes multiple commands in ONE SSH session)
batch_ssh_prod() {
    local timeout_val="${1:-30}"
    shift
    local combined_cmd=""

    # Build single command that runs all checks
    for cmd in "$@"; do
        combined_cmd+="echo '===SPLIT==='; $cmd; "
    done

    ssh_prod "$combined_cmd" "$timeout_val"
}

batch_ssh_staging() {
    local timeout_val="${1:-30}"
    shift
    local combined_cmd=""

    # Build single command that runs all checks
    for cmd in "$@"; do
        combined_cmd+="echo '===SPLIT==='; $cmd; "
    done

    ssh_staging "$combined_cmd" "$timeout_val"
}

# Parse batch results
parse_batch_index() {
    local data="$1"
    local index="$2"
    echo "$data" | awk -v idx="$index" 'BEGIN{RS="===SPLIT==="; count=0} {if(count==idx) print $0; count++}'
}

# Export functions
export -f ssh_prod ssh_staging batch_ssh_prod batch_ssh_staging parse_batch_index
