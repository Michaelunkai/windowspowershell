#!/bin/bash
# Test sshpass with different methods

PROD_HOST="193.181.213.220"
PROD_USER="admin"
PROD_PASS="EbTyNkfJG6LM"

echo "=== Test 1: Using SSHPASS env var with -e flag ==="
export SSHPASS="$PROD_PASS"
RESULT=$(sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 "$PROD_USER@$PROD_HOST" "hostname" 2>/dev/null)
echo "Exit code: $?"
echo "Length: ${#RESULT}"
echo "Result: [$RESULT]"

echo ""
echo "=== Test 2: Using -p flag directly ==="
RESULT2=$(sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 "$PROD_USER@$PROD_HOST" "hostname" 2>/dev/null)
echo "Exit code: $?"
echo "Length: ${#RESULT2}"
echo "Result: [$RESULT2]"

echo ""
echo "=== Test 3: Using -p flag with full docker command ==="
RAW=$(sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30 "$PROD_USER@$PROD_HOST" '
echo "###SERVICE###"
systemctl is-active docker
docker ps -q | wc -l
echo "###END###"
' 2>/dev/null)
echo "Exit code: $?"
echo "Length: ${#RAW}"
echo "Output:"
echo "$RAW"
