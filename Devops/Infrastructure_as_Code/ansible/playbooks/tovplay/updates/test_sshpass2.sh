#!/bin/bash
# Test sshpass WITHOUT command substitution

PROD_HOST="193.181.213.220"
PROD_USER="admin"
PROD_PASS="EbTyNkfJG6LM"

echo "=== Test 1: Direct execution (no command substitution) ==="
sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 "$PROD_USER@$PROD_HOST" "hostname"
echo "Exit code: $?"

echo ""
echo "=== Test 2: Direct to file, then read ==="
sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 "$PROD_USER@$PROD_HOST" "hostname" > /tmp/ssh_result.txt 2>&1
echo "Exit code: $?"
echo "File contents:"
cat /tmp/ssh_result.txt

echo ""
echo "=== Test 3: Check if sshpass can find ssh ==="
which ssh
which sshpass

echo ""
echo "=== Test 4: With verbose SSH ==="
sshpass -p "$PROD_PASS" ssh -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 "$PROD_USER@$PROD_HOST" "hostname" 2>&1 | head -30
