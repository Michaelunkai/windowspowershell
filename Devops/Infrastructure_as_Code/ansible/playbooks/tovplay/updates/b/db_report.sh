#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# DATABASE AUDIT v5.1 [3X SPEED OPTIMIZED] - Query Batching Edition
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
DB_HOST="45.148.28.196"; DB_USER="raz@tovtech.org"; DB_NAME="database"; DB_PASS="CaptainForgotCreatureBreak"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

declare -a CRITICAL_ISSUES=() HIGH_ISSUES=() MEDIUM_ISSUES=() LOW_ISSUES=()
SCORE=100

SSH_CTRL="/tmp/tovplay_db_$$"
mkdir -p "$SSH_CTRL"
cleanup() { ssh -S "$SSH_CTRL/prod" -O exit $PROD_USER@$PROD_HOST 2>/dev/null; rm -rf "$SSH_CTRL"; }
trap cleanup EXIT

init_connections() {
    sshpass -p "$PROD_PASS" ssh -fNM -S "$SSH_CTRL/prod" -o ControlPersist=90 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
        $PROD_USER@$PROD_HOST 2>/dev/null
}

ssh_prod() { timeout ${2:-5}s ssh -S "$SSH_CTRL/prod" -o StrictHostKeyChecking=no $PROD_USER@$PROD_HOST "$1" 2>/dev/null; }

section() { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }
check_pass() { echo -e "  ${GREEN}✓${NC} $1"; }
check_fail() { echo -e "  ${RED}✗${NC} $1"; }
check_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
check_info() { echo -e "  ${BLUE}ℹ${NC} $1"; }

add_critical() { CRITICAL_ISSUES+=("$1"); SCORE=$((SCORE - 20)); }
add_high() { HIGH_ISSUES+=("$1"); SCORE=$((SCORE - 10)); }
add_medium() { MEDIUM_ISSUES+=("$1"); SCORE=$((SCORE - 5)); }
add_low() { LOW_ISSUES+=("$1"); SCORE=$((SCORE - 2)); }

echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║     🗄️ DATABASE AUDIT v5.1 [3X SPEED] - $(date '+%Y-%m-%d %H:%M:%S')          ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

init_connections

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 3)
[ "$PROD_OK" = "OK" ] && { check_pass "Production SSH: connected"; PROD_CONN=true; } || { check_fail "Production SSH: failed"; add_critical "SSH failed"; PROD_CONN=false; }

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 1: ALL DATABASE INFO IN ONE QUERY
# ═══════════════════════════════════════════════════════════════════════════════
section "2-10. DATABASE HEALTH"
if [ "$PROD_CONN" = true ]; then
    BATCH1=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
echo ":::DB_CONN:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT 1;" 2>/dev/null | xargs
echo ":::VERSION:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT version();" 2>/dev/null | head -1
echo ":::SSL:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SHOW ssl;" 2>/dev/null | xargs
echo ":::DB_SIZE:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT pg_size_pretty(pg_database_size(current_database()));" 2>/dev/null | xargs
echo ":::TABLE_COUNT:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '"'"'public'"'"';" 2>/dev/null | xargs
echo ":::USER_COUNT:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT COUNT(*) FROM \"User\";" 2>/dev/null | xargs
echo ":::ACTIVE_CONN:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = '"'"'active'"'"';" 2>/dev/null | xargs
echo ":::TOTAL_CONN:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs
echo ":::MAX_CONN:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SHOW max_connections;" 2>/dev/null | xargs
echo ":::UPTIME:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT EXTRACT(EPOCH FROM (now() - pg_postmaster_start_time()))/86400;" 2>/dev/null | xargs
echo ":::CACHE_HIT:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT ROUND(100 * sum(blks_hit) / NULLIF(sum(blks_hit + blks_read), 0), 2) FROM pg_stat_database WHERE datname = '"'"'database'"'"';" 2>/dev/null | xargs
echo ":::INDEX_USAGE:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT ROUND(100 * idx_scan / NULLIF(seq_scan + idx_scan, 0), 2) FROM pg_stat_user_tables WHERE seq_scan + idx_scan > 0 ORDER BY seq_scan DESC LIMIT 1;" 2>/dev/null | xargs
echo ":::DEAD_TUPLES:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT SUM(n_dead_tup) FROM pg_stat_user_tables;" 2>/dev/null | xargs
echo ":::LAST_VACUUM:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT MAX(last_autovacuum)::date FROM pg_stat_user_tables;" 2>/dev/null | xargs
echo ":::AUDIT_TABLE:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT COUNT(*) FROM \"DeleteAuditLog\";" 2>/dev/null | xargs 2>/dev/null || echo "0"
echo ":::BACKUP_LOG:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT COUNT(*) FROM \"BackupLog\";" 2>/dev/null | xargs 2>/dev/null || echo "0"
echo ":::LONG_QUERIES:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE state = '"'"'active'"'"' AND now() - query_start > interval '"'"'5 minutes'"'"';" 2>/dev/null | xargs
echo ":::LOCKS:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT COUNT(*) FROM pg_locks WHERE NOT granted;" 2>/dev/null | xargs
echo ":::INDEX_COUNT:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = '"'"'public'"'"';" 2>/dev/null | xargs
echo ":::TRIGGERS:::"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = '"'"'public'"'"';" 2>/dev/null | xargs
echo ":::BACKUP_DIR:::"; test -d /opt/tovplay_backups && echo yes || echo no
echo ":::RECENT_BACKUPS:::"; find /opt/tovplay_backups -type f -name "*.sql*" -mtime -1 2>/dev/null | wc -l
echo ":::BACKUP_SIZE:::"; du -sh /opt/tovplay_backups 2>/dev/null | cut -f1' 25)

    DB_CONN=$(echo "$BATCH1" | sed -n '/:::DB_CONN:::/,/:::VERSION:::/p' | tail -1)
    VERSION=$(echo "$BATCH1" | sed -n '/:::VERSION:::/,/:::SSL:::/p' | tail -1)
    SSL=$(echo "$BATCH1" | sed -n '/:::SSL:::/,/:::DB_SIZE:::/p' | tail -1)
    DB_SIZE=$(echo "$BATCH1" | sed -n '/:::DB_SIZE:::/,/:::TABLE_COUNT:::/p' | tail -1)
    TABLE_COUNT=$(echo "$BATCH1" | sed -n '/:::TABLE_COUNT:::/,/:::USER_COUNT:::/p' | tail -1)
    USER_COUNT=$(echo "$BATCH1" | sed -n '/:::USER_COUNT:::/,/:::ACTIVE_CONN:::/p' | tail -1)
    ACTIVE_CONN=$(echo "$BATCH1" | sed -n '/:::ACTIVE_CONN:::/,/:::TOTAL_CONN:::/p' | tail -1)
    TOTAL_CONN=$(echo "$BATCH1" | sed -n '/:::TOTAL_CONN:::/,/:::MAX_CONN:::/p' | tail -1)
    MAX_CONN=$(echo "$BATCH1" | sed -n '/:::MAX_CONN:::/,/:::UPTIME:::/p' | tail -1)
    UPTIME=$(echo "$BATCH1" | sed -n '/:::UPTIME:::/,/:::CACHE_HIT:::/p' | tail -1)
    CACHE_HIT=$(echo "$BATCH1" | sed -n '/:::CACHE_HIT:::/,/:::INDEX_USAGE:::/p' | tail -1)
    INDEX_USAGE=$(echo "$BATCH1" | sed -n '/:::INDEX_USAGE:::/,/:::DEAD_TUPLES:::/p' | tail -1)
    DEAD_TUPLES=$(echo "$BATCH1" | sed -n '/:::DEAD_TUPLES:::/,/:::LAST_VACUUM:::/p' | tail -1)
    LAST_VACUUM=$(echo "$BATCH1" | sed -n '/:::LAST_VACUUM:::/,/:::AUDIT_TABLE:::/p' | tail -1)
    AUDIT_COUNT=$(echo "$BATCH1" | sed -n '/:::AUDIT_TABLE:::/,/:::BACKUP_LOG:::/p' | tail -1)
    BACKUP_LOG=$(echo "$BATCH1" | sed -n '/:::BACKUP_LOG:::/,/:::LONG_QUERIES:::/p' | tail -1)
    LONG_QUERIES=$(echo "$BATCH1" | sed -n '/:::LONG_QUERIES:::/,/:::LOCKS:::/p' | tail -1)
    LOCKS=$(echo "$BATCH1" | sed -n '/:::LOCKS:::/,/:::INDEX_COUNT:::/p' | tail -1)
    INDEX_COUNT=$(echo "$BATCH1" | sed -n '/:::INDEX_COUNT:::/,/:::TRIGGERS:::/p' | tail -1)
    TRIGGERS=$(echo "$BATCH1" | sed -n '/:::TRIGGERS:::/,/:::BACKUP_DIR:::/p' | tail -1)
    BACKUP_DIR=$(echo "$BATCH1" | sed -n '/:::BACKUP_DIR:::/,/:::RECENT_BACKUPS:::/p' | tail -1)
    RECENT_BACKUPS=$(echo "$BATCH1" | sed -n '/:::RECENT_BACKUPS:::/,/:::BACKUP_SIZE:::/p' | tail -1)
    BACKUP_SIZE=$(echo "$BATCH1" | sed -n '/:::BACKUP_SIZE:::/,$p' | tail -1)

    echo -e "${CYAN}Connection:${NC}"
    [ "${DB_CONN:-0}" = "1" ] && check_pass "Database: connected" || { check_fail "Database: connection failed"; add_critical "DB unreachable"; }
    check_info "Version: $VERSION"
    [ "$SSL" = "on" ] && check_pass "SSL: enabled" || check_info "SSL: off (external managed)"

    echo -e "\n${CYAN}Size & Structure:${NC}"
    check_info "Database size: $DB_SIZE"
    check_info "Tables: $TABLE_COUNT | Indexes: $INDEX_COUNT | Triggers: $TRIGGERS"
    check_info "Users: $USER_COUNT"

    echo -e "\n${CYAN}Connections:${NC}"
    check_info "Active: $ACTIVE_CONN | Total: $TOTAL_CONN / $MAX_CONN max"
    CONN_PCT=$((TOTAL_CONN * 100 / MAX_CONN))
    [ "$CONN_PCT" -gt 80 ] 2>/dev/null && { check_warn "Connection usage: ${CONN_PCT}%"; add_medium "High connection usage"; } || check_pass "Connection usage: ${CONN_PCT}%"

    echo -e "\n${CYAN}Performance:${NC}"
    UPTIME_DAYS=$(printf "%.1f" "$UPTIME" 2>/dev/null || echo "?")
    check_info "Uptime: ${UPTIME_DAYS} days"
    [ "${CACHE_HIT:-0}" -ge 95 ] 2>/dev/null && check_pass "Cache hit ratio: ${CACHE_HIT}%" || { check_warn "Cache hit ratio: ${CACHE_HIT}%"; add_low "Low cache hit"; }
    check_info "Index usage: ${INDEX_USAGE:-N/A}%"
    check_info "Dead tuples: $DEAD_TUPLES | Last vacuum: $LAST_VACUUM"
    [ "${DEAD_TUPLES:-0}" -gt 10000 ] 2>/dev/null && { check_warn "High dead tuples"; add_low "Needs vacuum"; }

    echo -e "\n${CYAN}Active Queries:${NC}"
    [ "${LONG_QUERIES:-0}" -gt 0 ] 2>/dev/null && { check_warn "Long queries (>5min): $LONG_QUERIES"; add_medium "Long running queries"; } || check_pass "No long running queries"
    [ "${LOCKS:-0}" -gt 0 ] 2>/dev/null && { check_warn "Blocked locks: $LOCKS"; add_medium "Lock contention"; } || check_pass "No blocked locks"

    echo -e "\n${CYAN}Audit & Protection:${NC}"
    [ "${AUDIT_COUNT:-0}" -gt 0 ] 2>/dev/null && check_pass "Delete audit log: $AUDIT_COUNT entries" || check_info "Delete audit: no entries"
    [ "${BACKUP_LOG:-0}" -gt 0 ] 2>/dev/null && check_pass "Backup log: $BACKUP_LOG entries" || check_info "Backup log: no entries"

    echo -e "\n${CYAN}Backups:${NC}"
    [ "$BACKUP_DIR" = "yes" ] && check_pass "Backup directory: exists" || { check_warn "No backup directory"; add_medium "Setup backups"; }
    [ "${RECENT_BACKUPS:-0}" -gt 0 ] 2>/dev/null && check_pass "Recent backups (24h): $RECENT_BACKUPS" || { check_warn "No recent backups"; add_high "Backup not running"; }
    check_info "Backup storage: $BACKUP_SIZE"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH 2: TABLE DETAILS
# ═══════════════════════════════════════════════════════════════════════════════
section "11. TABLE STATISTICS"
if [ "$PROD_CONN" = true ]; then
    TABLES=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d database -t -c "SELECT tablename || '"'"': '"'"' || pg_size_pretty(pg_total_relation_size(schemaname||'"'"'.'"'"'||tablename)) FROM pg_tables WHERE schemaname='"'"'public'"'"' ORDER BY pg_total_relation_size(schemaname||'"'"'.'"'"'||tablename) DESC LIMIT 8;" 2>/dev/null' 10)

    if [ -n "$TABLES" ]; then
        echo "$TABLES" | while read -r line; do
            [ -n "$line" ] && check_info "$line"
        done
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
section "FINAL SUMMARY"
DUR=$(($(date +%s) - SCRIPT_START))
[[ $SCORE -lt 0 ]] && SCORE=0

if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 ]]; then
    echo -e "\n${RED}Issues:${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${YELLOW}🟠 HIGH: $issue${NC}"; done
fi

if [[ $SCORE -ge 90 ]]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [[ $SCORE -ge 75 ]]; then RATING="GOOD"; COLOR="$GREEN"
elif [[ $SCORE -ge 60 ]]; then RATING="FAIR"; COLOR="$YELLOW"
else RATING="NEEDS WORK"; COLOR="$RED"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  DB_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds          ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "DB_SCORE:$SCORE"
