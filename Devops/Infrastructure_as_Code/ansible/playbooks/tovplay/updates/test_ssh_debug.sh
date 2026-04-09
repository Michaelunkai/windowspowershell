#!/bin/bash
cd /mnt/f/study/devops/Infrastructure_as_Code/ansible/playbooks/tovplay/updates

# Source helpers
source ./fast_ssh_helpers.sh 2>/dev/null || true

# Check if function exists
if declare -f ssh_prod > /dev/null; then
    echo "ssh_prod function loaded"
else
    echo "ssh_prod function NOT loaded - defining locally"
    PROD_HOST="193.181.213.220"
    PROD_USER="admin"
    PROD_PASS="EbTyNkfJG6LM"

    ssh_prod() {
        local cmd="$1"
        local timeout_val="${2:-15}"
        sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout="$timeout_val" \
            "$PROD_USER@$PROD_HOST" "$cmd" 2>/dev/null
    }
fi

echo "=== TESTING SSH CONNECTIVITY ==="
RESULT=$(ssh_prod "echo OK" 15)
echo "Result: [$RESULT]"

echo ""
echo "=== TESTING FULL DOCKER COMMAND ==="
RAW=$(ssh_prod 'echo "###SERVICE###"; systemctl is-active docker; docker ps -q | wc -l; echo "###END###"' 30)
echo "Raw output:"
echo "$RAW"
echo "Length: ${#RAW}"
