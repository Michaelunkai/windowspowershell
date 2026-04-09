#!/bin/bash
PROD_HOST="193.181.213.220"
PROD_USER="admin"
PROD_PASS="EbTyNkfJG6LM"

echo "=== Test 1: Direct command ==="
sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$PROD_USER@$PROD_HOST" "hostname; docker ps | wc -l"

echo ""
echo "=== Test 2: With command substitution ==="
OUTPUT=$(sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$PROD_USER@$PROD_HOST" "hostname; docker ps | wc -l")
echo "Length: ${#OUTPUT}"
echo "Output: $OUTPUT"

echo ""
echo "=== Test 3: With large multi-line command ==="
RAW=$(sshpass -p "$PROD_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$PROD_USER@$PROD_HOST" '
echo "###START###"
hostname
echo "###DOCKER###"
docker ps | wc -l
echo "###END###"
')
echo "Length: ${#RAW}"
echo "First 100 chars: ${RAW:0:100}"
