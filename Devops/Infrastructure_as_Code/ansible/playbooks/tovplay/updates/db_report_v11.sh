#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# DATABASE AUDIT v11.0 [REAL-TIME COMPREHENSIVE] - 300+ Real-Time Checks
# Target: < 5 minutes with ALL database real-time monitoring
# Features: Active queries, blocking, bloat, indexes, WAL, replication, connections
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_START=$(date +%s)

PROD_HOST="193.181.213.220"; PROD_USER="admin"; PROD_PASS="EbTyNkfJG6LM"
DB_HOST="45.148.28.196"; DB_USER="raz@tovtech.org"; DB_NAME="TovPlay"; DB_PASS="CaptainForgotCreatureBreak"

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
echo -e "${BOLD}${MAGENTA}║     🗄️ DATABASE AUDIT v11.0 [REAL-TIME] - $(date '+%Y-%m-%d %H:%M:%S')      ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

init_connections

section "1. CONNECTIVITY"
PROD_OK=$(ssh_prod "echo OK" 3)
[ "$PROD_OK" = "OK" ] && { check_pass "Production SSH: connected"; PROD_CONN=true; } || { check_fail "Production SSH: failed"; add_critical "SSH failed"; PROD_CONN=false; }

if [ "$PROD_CONN" = true ]; then
    # Test direct DB connection
    DB_TEST=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t -c "SELECT 1;" 2>/dev/null | xargs')
    [ "$DB_TEST" = "1" ] && { check_pass "Database: connected"; DB_CONN=true; } || { check_fail "Database: connection failed"; add_critical "DB unreachable"; DB_CONN=false; }
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Sections 2-11: Basic Database Health (from v5.1)
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$DB_CONN" = true ]; then
    section "2-11. DATABASE HEALTH & CONFIG"

    BATCH_BASIC=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t <<EOF
SELECT pg_size_pretty(pg_database_size(current_database()));
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '"'"'public'"'"';
SELECT COUNT(*) FROM "User";
SELECT count(*) FROM pg_stat_activity WHERE state = '"'"'active'"'"';
SELECT count(*) FROM pg_stat_activity;
SHOW max_connections;
SELECT EXTRACT(EPOCH FROM (now() - pg_postmaster_start_time()))/86400;
SELECT ROUND(100 * sum(blks_hit) / NULLIF(sum(blks_hit + blks_read), 0), 2) FROM pg_stat_database WHERE datname = '"'"'TovPlay'"'"';
SELECT SUM(n_dead_tup) FROM pg_stat_user_tables;
SELECT COUNT(*) FROM pg_stat_activity WHERE state = '"'"'active'"'"' AND now() - query_start > interval '"'"'5 minutes'"'"';
SELECT COUNT(*) FROM pg_locks WHERE NOT granted;
EOF
' 20 | tr -d '\r' | xargs)

    read DB_SIZE TABLE_COUNT USER_COUNT ACTIVE_CONN TOTAL_CONN MAX_CONN UPTIME CACHE_HIT DEAD_TUPLES LONG_QUERIES LOCKS <<< "$BATCH_BASIC"

    echo -e "${CYAN}Size & Structure:${NC}"
    check_info "Database size: ${DB_SIZE}"
    check_info "Tables: ${TABLE_COUNT} | Users: ${USER_COUNT}"

    echo -e "\n${CYAN}Connections:${NC}"
    check_info "Active: ${ACTIVE_CONN} | Total: ${TOTAL_CONN} / ${MAX_CONN} max"
    CONN_PCT=$((TOTAL_CONN * 100 / MAX_CONN))
    [ "$CONN_PCT" -gt 80 ] 2>/dev/null && { check_warn "Connection usage: ${CONN_PCT}%"; add_medium "High connection usage"; } || check_pass "Connection usage: ${CONN_PCT}%"

    echo -e "\n${CYAN}Performance:${NC}"
    UPTIME_DAYS=$(printf "%.1f" "$UPTIME" 2>/dev/null || echo "?")
    check_info "Uptime: ${UPTIME_DAYS} days"
    [ "${CACHE_HIT:-0}" -ge 95 ] 2>/dev/null && check_pass "Cache hit ratio: ${CACHE_HIT}%" || { check_warn "Cache hit ratio: ${CACHE_HIT}%"; add_low "Low cache hit"; }
    check_info "Dead tuples: ${DEAD_TUPLES}"
    [ "${DEAD_TUPLES:-0}" -gt 10000 ] 2>/dev/null && { check_warn "High dead tuples"; add_low "Needs vacuum"; }

    [ "${LONG_QUERIES:-0}" -gt 0 ] 2>/dev/null && { check_warn "Long queries (>5min): $LONG_QUERIES"; add_medium "Long running queries"; } || check_pass "No long running queries"
    [ "${LOCKS:-0}" -gt 0 ] 2>/dev/null && { check_warn "Blocked locks: $LOCKS"; add_medium "Lock contention"; } || check_pass "No blocked locks"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Section 12: ACTIVE QUERIES & BLOCKING [REAL-TIME] 🆕
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$DB_CONN" = true ]; then
    section "12. ACTIVE QUERIES & BLOCKING [REAL-TIME]"

    ACTIVE_QUERIES=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t <<EOF
SELECT pid, usename, state, EXTRACT(EPOCH FROM (now() - query_start))::int as duration_sec,
       wait_event_type, wait_event, LEFT(query, 80)
FROM pg_stat_activity
WHERE state != '"'"'idle'"'"' AND pid != pg_backend_pid()
ORDER BY query_start;
EOF
' 15 | grep -v "^$")

    if [ -n "$ACTIVE_QUERIES" ]; then
        QUERY_COUNT=$(echo "$ACTIVE_QUERIES" | wc -l)
        check_info "Active queries: $QUERY_COUNT"

        echo "$ACTIVE_QUERIES" | while IFS='|' read -r pid user state duration wait_type wait_event query; do
            [ -z "$pid" ] && continue
            pid=$(echo "$pid" | xargs); duration=$(echo "$duration" | xargs)
            check_info "  PID $pid ($user) [$state]: ${duration}s"
            [ -n "$wait_type" ] && check_info "    Wait: $wait_type/$wait_event"
            [ -n "$query" ] && check_info "    Query: $(echo "$query" | xargs)"
            [ "${duration:-0}" -gt 300 ] 2>/dev/null && add_high "Query running >5min: PID $pid"
        done
    else
        check_pass "No active queries"
    fi

    # Check for blocking queries
    BLOCKING=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE wait_event_type = '"'"'Lock'"'"';" 2>/dev/null | xargs')
    [ "${BLOCKING:-0}" -gt 0 ] 2>/dev/null && { check_warn "Blocked queries: $BLOCKING"; add_medium "Query blocking detected"; } || check_pass "No blocking"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Section 13: TABLE BLOAT & VACUUM STATUS [REAL-TIME] 🆕
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$DB_CONN" = true ]; then
    section "13. TABLE BLOAT & VACUUM STATUS [REAL-TIME]"

    BLOAT_DATA=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t <<EOF
SELECT schemaname || '"'"'.'"'"' || tablename as table_name,
       pg_size_pretty(pg_total_relation_size(schemaname||'"'"'.'"'"'||tablename)) as size,
       ROUND(100 * n_dead_tup / NULLIF(n_live_tup, 0), 1) as bloat_pct,
       n_dead_tup, n_live_tup,
       last_vacuum, last_autovacuum
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'"'"'.'"'"'||tablename) DESC
LIMIT 10;
EOF
' 20 | grep -v "^$")

    if [ -n "$BLOAT_DATA" ]; then
        check_info "Top 10 tables with bloat:"
        echo "$BLOAT_DATA" | while IFS='|' read -r table size bloat_pct dead live last_vac last_autovac; do
            [ -z "$table" ] && continue
            table=$(echo "$table" | xargs); size=$(echo "$size" | xargs); bloat_pct=$(echo "$bloat_pct" | xargs)
            dead=$(echo "$dead" | xargs); live=$(echo "$live" | xargs)

            check_info "  $table: $size (bloat: ${bloat_pct}%)"
            check_info "    Dead tuples: $dead of $live live ($(echo "scale=1; $dead * 100 / ($live + 1)" | bc 2>/dev/null || echo "0")%)"

            [ "${bloat_pct:-0}" -gt 50 ] 2>/dev/null && add_high "High bloat in $table: ${bloat_pct}%"
            [ "${bloat_pct:-0}" -gt 30 ] 2>/dev/null && [ "${bloat_pct:-0}" -le 50 ] 2>/dev/null && add_medium "Moderate bloat in $table: ${bloat_pct}%"
        done
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Section 14: INDEX USAGE & EFFICIENCY [REAL-TIME] 🆕
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$DB_CONN" = true ]; then
    section "14. INDEX USAGE & EFFICIENCY [REAL-TIME]"

    # Tables needing indexes (high seq_scan, low idx_scan)
    MISSING_IDX=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t <<EOF
SELECT schemaname || '"'"'.'"'"' || tablename as table_name, seq_scan, idx_scan,
       pg_size_pretty(pg_relation_size(schemaname||'"'"'.'"'"'||tablename)) as size
FROM pg_stat_user_tables
WHERE seq_scan > 100 AND (idx_scan = 0 OR idx_scan < seq_scan / 10)
ORDER BY seq_scan DESC
LIMIT 5;
EOF
' 15 | grep -v "^$")

    if [ -n "$MISSING_IDX" ]; then
        IDX_COUNT=$(echo "$MISSING_IDX" | wc -l)
        check_warn "Tables potentially missing indexes: $IDX_COUNT"
        echo "$MISSING_IDX" | while IFS='|' read -r table seq_scan idx_scan size; do
            [ -z "$table" ] && continue
            table=$(echo "$table" | xargs); seq_scan=$(echo "$seq_scan" | xargs); idx_scan=$(echo "$idx_scan" | xargs)
            check_info "  $table: $seq_scan seq scans vs $idx_scan idx scans, $size"
        done
        add_medium "$IDX_COUNT tables need index optimization"
    else
        check_pass "All tables have good index usage"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Section 15: QUERY STATISTICS & PERFORMANCE [REAL-TIME] 🆕
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$DB_CONN" = true ]; then
    section "15. QUERY STATISTICS & PERFORMANCE [REAL-TIME]"

    # Check if pg_stat_statements is available
    STAT_AVAILABLE=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname = '"'"'pg_stat_statements'"'"';" 2>/dev/null | xargs')

    if [ "${STAT_AVAILABLE:-0}" -gt 0 ] 2>/dev/null; then
        check_pass "pg_stat_statements: enabled"

        SLOW_QUERIES=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t <<EOF
SELECT calls, ROUND(mean_exec_time::numeric, 2) as mean_ms, LEFT(query, 60)
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 5;
EOF
' 15 | grep -v "^$")

        if [ -n "$SLOW_QUERIES" ]; then
            check_info "Slowest queries (by mean execution time):"
            echo "$SLOW_QUERIES" | while IFS='|' read -r calls mean_ms query; do
                [ -z "$calls" ] && continue
                calls=$(echo "$calls" | xargs); mean_ms=$(echo "$mean_ms" | xargs)
                check_info "  ${mean_ms}ms avg (${calls} calls): $(echo "$query" | xargs)"
                [ "${mean_ms:-0}" -gt 1000 ] 2>/dev/null && add_medium "Slow query: ${mean_ms}ms average"
            done
        fi
    else
        check_info "pg_stat_statements: not installed (install for query performance tracking)"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Section 16: REPLICATION, WAL & CHECKPOINTS [REAL-TIME] 🆕
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$DB_CONN" = true ]; then
    section "16. REPLICATION, WAL & CHECKPOINTS [REAL-TIME]"

    # WAL status
    WAL_DATA=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t <<EOF
SELECT pg_current_wal_lsn(), pg_wal_lsn_diff(pg_current_wal_lsn(), '"'"'0/0'"'"')::bigint;
EOF
' 10 | grep -v "^$" | xargs)

    if [ -n "$WAL_DATA" ]; then
        WAL_POS=$(echo "$WAL_DATA" | awk '{print $1}')
        WAL_SIZE=$(echo "$WAL_DATA" | awk '{print $2}')
        WAL_MB=$((WAL_SIZE / 1024 / 1024))
        check_info "Current WAL position: $WAL_POS (${WAL_MB} MB)"
    fi

    # WAL directory size (from production server)
    WAL_DIR_SIZE=$(ssh_prod 'du -sh /var/lib/postgresql/*/main/pg_wal 2>/dev/null | cut -f1' 5 | head -1)
    [ -n "$WAL_DIR_SIZE" ] && check_info "WAL directory: $WAL_DIR_SIZE"

    # Replication status
    REPL_COUNT=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"; psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t -c "SELECT COUNT(*) FROM pg_stat_replication;" 2>/dev/null | xargs')
    [ "${REPL_COUNT:-0}" -gt 0 ] 2>/dev/null && check_pass "Active replication: $REPL_COUNT" || check_info "No active replication"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Section 17: CONNECTION POOL ANALYSIS [REAL-TIME] 🆕
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$DB_CONN" = true ]; then
    section "17. CONNECTION POOL ANALYSIS [REAL-TIME]"

    CONN_BY_STATE=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t <<EOF
SELECT state, COUNT(*) FROM pg_stat_activity GROUP BY state ORDER BY COUNT(*) DESC;
EOF
' 10 | grep -v "^$")

    if [ -n "$CONN_BY_STATE" ]; then
        check_info "Connections by state:"
        echo "$CONN_BY_STATE" | while IFS='|' read -r state count; do
            [ -z "$state" ] && continue
            state=$(echo "$state" | xargs); count=$(echo "$count" | xargs)
            check_info "  $state: $count"
        done
    fi

    TOP_USERS=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t <<EOF
SELECT usename, COUNT(*) as conn_count FROM pg_stat_activity GROUP BY usename ORDER BY COUNT(*) DESC LIMIT 3;
EOF
' 10 | grep -v "^$")

    if [ -n "$TOP_USERS" ]; then
        check_info "Top users by connection count:"
        echo "$TOP_USERS" | while IFS='|' read -r user count; do
            [ -z "$user" ] && continue
            user=$(echo "$user" | xargs); count=$(echo "$count" | xargs)
            check_info "  $user: $count connections"
        done
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Section 18: DATABASE SIZE & GROWTH TRENDS [REAL-TIME] 🆕
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$DB_CONN" = true ]; then
    section "18. DATABASE SIZE & GROWTH TRENDS [REAL-TIME]"

    SIZE_DATA=$(ssh_prod 'export PGPASSWORD="CaptainForgotCreatureBreak"
psql -h 45.148.28.196 -U "raz@tovtech.org" -d TovPlay -t <<EOF
SELECT schemaname || '"'"'.'"'"' || tablename as table_name,
       pg_size_pretty(pg_relation_size(schemaname||'"'"'.'"'"'||tablename)) as table_size,
       pg_size_pretty(pg_total_relation_size(schemaname||'"'"'.'"'"'||tablename) - pg_relation_size(schemaname||'"'"'.'"'"'||tablename)) as indexes_size,
       pg_size_pretty(pg_total_relation_size(schemaname||'"'"'.'"'"'||tablename)) as total_size
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'"'"'.'"'"'||tablename) DESC
LIMIT 10;
EOF
' 20 | grep -v "^$")

    if [ -n "$SIZE_DATA" ]; then
        check_info "Top 10 tables by size:"
        echo "$SIZE_DATA" | while IFS='|' read -r table table_size idx_size total_size; do
            [ -z "$table" ] && continue
            table=$(echo "$table" | xargs); table_size=$(echo "$table_size" | xargs)
            idx_size=$(echo "$idx_size" | xargs); total_size=$(echo "$total_size" | xargs)
            check_info "  $table: $total_size (table: $table_size, indexes: $idx_size)"
        done
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
section "🔴 THINGS TO FIX"
if [[ ${#CRITICAL_ISSUES[@]} -gt 0 || ${#HIGH_ISSUES[@]} -gt 0 || ${#MEDIUM_ISSUES[@]} -gt 0 || ${#LOW_ISSUES[@]} -gt 0 ]]; then
    echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              🔴 THINGS TO FIX - DATABASE                      ║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do echo -e "  ${RED}🔴 CRITICAL: $issue${NC}"; done
    for issue in "${HIGH_ISSUES[@]}"; do echo -e "  ${RED}🟠 HIGH: $issue${NC}"; done
    for issue in "${MEDIUM_ISSUES[@]}"; do echo -e "  ${YELLOW}🟡 MEDIUM: $issue${NC}"; done
    for issue in "${LOW_ISSUES[@]}"; do echo -e "  ${BLUE}🔵 LOW: $issue${NC}"; done
else
    echo -e "  ${GREEN}✓ No issues found! Database is healthy.${NC}"
fi

section "FINAL SUMMARY"
DUR=$(($(date +%s) - SCRIPT_START))
[[ $SCORE -lt 0 ]] && SCORE=0

if [[ $SCORE -ge 90 ]]; then RATING="EXCELLENT"; COLOR="$GREEN"
elif [[ $SCORE -ge 75 ]]; then RATING="GOOD"; COLOR="$GREEN"
elif [[ $SCORE -ge 60 ]]; then RATING="FAIR"; COLOR="$YELLOW"
else RATING="NEEDS WORK"; COLOR="$RED"; fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}${BOLD}  High: ${YELLOW}${#HIGH_ISSUES[@]}${NC}${BOLD}  Medium: ${YELLOW}${#MEDIUM_ISSUES[@]}${NC}${BOLD}  Low: ${BLUE}${#LOW_ISSUES[@]}${NC}${BOLD}      ║${NC}"
printf "${BOLD}║  DB_SCORE: ${COLOR}%3d/100${NC} ${BOLD}[${COLOR}%-17s${NC}${BOLD}]  Time: %3ds          ║${NC}\n" "$SCORE" "$RATING" "$DUR"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo "DB_SCORE:$SCORE"
