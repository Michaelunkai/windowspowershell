# db.ps1 - TovPlay COMPREHENSIVE DATABASE SCRIPT
# Outputs ALL database-related data from: DB server, repos, local, servers
# Real-time data - always fresh from source
# ALWAYS reads credentials from credentials.json - NEVER hardcoded
# PowerShell v5 compatible
# Usage: .\db.ps1

$ErrorActionPreference = "Continue"

# =============================================================================
# LOAD CREDENTIALS FROM SINGLE SOURCE OF TRUTH
# =============================================================================
$credFile = "F:\tovplay\.claude\credentials.json"
if (-not (Test-Path $credFile)) {
    Write-Host "ERROR: credentials.json not found at $credFile" -ForegroundColor Red
    Write-Host "Please ensure credentials.json exists with server credentials." -ForegroundColor Yellow
    exit 1
}

try {
    $creds = Get-Content $credFile -Raw -ErrorAction Stop | ConvertFrom-Json
} catch {
    Write-Host "ERROR: Failed to parse credentials.json: $_" -ForegroundColor Red
    exit 1
}

# Extract credentials
$prodHost = $creds.servers.production.host
$prodUser = $creds.servers.production.user
$prodPass = $creds.servers.production.password

$stagingHost = $creds.servers.staging.host
$stagingUser = $creds.servers.staging.user
$stagingPass = $creds.servers.staging.password

$dbHost = $creds.servers.database.host
$dbPort = $creds.servers.database.port
$dbUser = $creds.servers.database.user
$dbPass = $creds.servers.database.password
$dbName = $creds.servers.database.database

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
# Run psql with base64-encoded query - pipe to bash for $() expansion
function Run-DB-Query($query) {
    $queryBytes = [System.Text.Encoding]::UTF8.GetBytes($query)
    $queryBase64 = [Convert]::ToBase64String($queryBytes)
    $bashCmd = "PAGER=cat PGPASSWORD='$dbPass' psql -h $dbHost -U '$dbUser' -d $dbName -c `"`$(echo $queryBase64 | base64 -d)`""
    $bashCmd | wsl -d ubuntu bash 2>$null
}

function Run-DB-Query-Tuple($query) {
    $queryBytes = [System.Text.Encoding]::UTF8.GetBytes($query)
    $queryBase64 = [Convert]::ToBase64String($queryBytes)
    $bashCmd = "PAGER=cat PGPASSWORD='$dbPass' psql -h $dbHost -U '$dbUser' -d $dbName -t -c `"`$(echo $queryBase64 | base64 -d)`""
    $bashCmd | wsl -d ubuntu bash 2>$null
}

# SSH helper for production (via staging jump host) - base64 encoding to avoid quote issues
function Run-Prod-Cmd($cmd) {
    $escapedStagingPass = $stagingPass -replace "'", "'\''"
    $escapedProdPass = $prodPass -replace "'", "'\''"
    $cmdBytes = [System.Text.Encoding]::UTF8.GetBytes($cmd)
    $cmdBase64 = [Convert]::ToBase64String($cmdBytes)
    $innerCmd = "echo $cmdBase64 | base64 -d | bash"
    $escapedInnerCmd = $innerCmd -replace "'", "'\''"
    $bashScript = "sshpass -p '$escapedStagingPass' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $stagingUser@$stagingHost 'sshpass -p '\''$escapedProdPass'\'' ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR admin@$prodHost '\''$escapedInnerCmd'\''' 2>/dev/null"
    wsl -d ubuntu bash -c $bashScript 2>$null
}

# SSH helper for staging - uses base64 to avoid quote issues
function Run-Staging-Cmd($cmd) {
    $escapedPass = $stagingPass -replace "'", "'\''"
    $cmdBytes = [System.Text.Encoding]::UTF8.GetBytes($cmd)
    $cmdBase64 = [Convert]::ToBase64String($cmdBytes)
    $bashScript = "sshpass -p '$escapedPass' ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $stagingUser@$stagingHost 'echo $cmdBase64 | base64 -d | bash' 2>/dev/null"
    wsl -d ubuntu bash -c $bashScript 2>$null
}

# =============================================================================
# HEADER
# =============================================================================
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         TOVPLAY - COMPREHENSIVE DATABASE DATA                        " -ForegroundColor Cyan
Write-Host "         Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')         " -ForegroundColor Cyan
Write-Host "  Credentials from: $credFile" -ForegroundColor DarkGray
Write-Host "======================================================================" -ForegroundColor Cyan

# =============================================================================
# SECTION 1: DATABASE CONNECTION INFO
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 1: DATABASE CONNECTION INFO                      #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[CONNECTION DETAILS]" -ForegroundColor Green
Write-Host "Host:      $dbHost" -ForegroundColor White
Write-Host "Port:      $dbPort" -ForegroundColor White
Write-Host "Database:  $dbName" -ForegroundColor White
Write-Host "User:      $dbUser" -ForegroundColor White
Write-Host "Schema:    public" -ForegroundColor White

Write-Host "`n[CONNECT COMMANDS]" -ForegroundColor Green
Write-Host "# Interactive psql:" -ForegroundColor DarkGray
Write-Host "wsl -d ubuntu bash -c `"PGPASSWORD='$dbPass' psql -h $dbHost -U '$dbUser' -d $dbName`"" -ForegroundColor Cyan
Write-Host "# Quick query:" -ForegroundColor DarkGray
Write-Host "wsl -d ubuntu bash -c `"PAGER=cat PGPASSWORD='$dbPass' psql -h $dbHost -U '$dbUser' -d $dbName -c 'SELECT version()'`"" -ForegroundColor Cyan

# =============================================================================
# SECTION 2: DATABASE SERVER STATUS
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 2: DATABASE SERVER STATUS                        #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[VERSION & CONFIG]" -ForegroundColor Green
Run-DB-Query "SELECT version()"
Run-DB-Query "SELECT pg_size_pretty(pg_database_size(current_database())) as database_size"

Write-Host "`n[SERVER SETTINGS]" -ForegroundColor Green
Run-DB-Query "SELECT name, setting, unit, category FROM pg_settings WHERE name IN ('max_connections', 'shared_buffers', 'work_mem', 'effective_cache_size', 'maintenance_work_mem', 'wal_buffers', 'checkpoint_completion_target', 'random_page_cost', 'effective_io_concurrency', 'timezone', 'log_timezone', 'log_statement', 'log_min_duration_statement', 'idle_in_transaction_session_timeout', 'statement_timeout') ORDER BY name"

Write-Host "`n[EXTENSIONS]" -ForegroundColor Green
Run-DB-Query "SELECT extname, extversion FROM pg_extension ORDER BY extname"

# =============================================================================
# SECTION 3: CONNECTION ANALYSIS
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 3: CONNECTION ANALYSIS                           #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[CURRENT CONNECTIONS]" -ForegroundColor Green
Run-DB-Query "SELECT pid, usename, client_addr, client_port, state, backend_start, query_start, wait_event_type, wait_event FROM pg_stat_activity WHERE datname = current_database() ORDER BY query_start DESC NULLS LAST"

Write-Host "`n[CONNECTIONS BY IP]" -ForegroundColor Green
Run-DB-Query "SELECT client_addr as ip, count(*) as connections, string_agg(DISTINCT state, ', ') as states FROM pg_stat_activity WHERE datname = current_database() AND client_addr IS NOT NULL GROUP BY client_addr ORDER BY connections DESC"

Write-Host "`n[CONNECTIONS BY STATE]" -ForegroundColor Green
Run-DB-Query "SELECT state, count(*) as count FROM pg_stat_activity WHERE datname = current_database() GROUP BY state ORDER BY count DESC"

Write-Host "`n[CONNECTIONS BY USER]" -ForegroundColor Green
Run-DB-Query "SELECT usename, count(*) as connections FROM pg_stat_activity WHERE datname = current_database() GROUP BY usename ORDER BY connections DESC"

Write-Host "`n[LONG RUNNING QUERIES (>5s)]" -ForegroundColor Green
Run-DB-Query 'SELECT pid, usename, state, EXTRACT(EPOCH FROM (now() - query_start))::integer as seconds, substring(query, 1, 100) as query_preview FROM pg_stat_activity WHERE datname = current_database() AND state != ''idle'' AND query_start < now() - interval ''5 seconds'' ORDER BY query_start'

Write-Host "`n[BLOCKED QUERIES]" -ForegroundColor Green
Run-DB-Query "SELECT blocked.pid AS blocked_pid, blocked.query AS blocked_query, blocking.pid AS blocking_pid, blocking.query AS blocking_query FROM pg_stat_activity blocked JOIN pg_locks blocked_locks ON blocked.pid = blocked_locks.pid JOIN pg_locks blocking_locks ON blocked_locks.locktype = blocking_locks.locktype AND blocked_locks.database IS NOT DISTINCT FROM blocking_locks.database AND blocked_locks.relation IS NOT DISTINCT FROM blocking_locks.relation AND blocked_locks.page IS NOT DISTINCT FROM blocking_locks.page AND blocked_locks.tuple IS NOT DISTINCT FROM blocking_locks.tuple AND blocked_locks.virtualxid IS NOT DISTINCT FROM blocking_locks.virtualxid AND blocked_locks.transactionid IS NOT DISTINCT FROM blocking_locks.transactionid AND blocked_locks.classid IS NOT DISTINCT FROM blocking_locks.classid AND blocked_locks.objid IS NOT DISTINCT FROM blocking_locks.objid AND blocked_locks.objsubid IS NOT DISTINCT FROM blocking_locks.objsubid AND blocked.pid != blocking_locks.pid JOIN pg_stat_activity blocking ON blocking_locks.pid = blocking.pid WHERE NOT blocked_locks.granted"

# =============================================================================
# SECTION 4: SCHEMA & TABLES
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 4: SCHEMA & TABLES                               #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[ALL TABLES]" -ForegroundColor Green
Run-DB-Query "SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT LIKE 'pg_%' AND schemaname <> 'information_schema' ORDER BY schemaname, tablename"

Write-Host "`n[TABLE SIZES]" -ForegroundColor Green
Run-DB-Query 'SELECT schemaname || ''.'' || relname as table_name, pg_size_pretty(pg_total_relation_size(relid)) as total_size, pg_size_pretty(pg_relation_size(relid)) as table_size, pg_size_pretty(pg_indexes_size(relid)) as index_size, n_live_tup as row_count FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC'

Write-Host "`n[TABLE STATISTICS]" -ForegroundColor Green
Run-DB-Query "SELECT relname as table_name, n_live_tup as live_rows, n_dead_tup as dead_rows, n_mod_since_analyze as mods_since_analyze, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze FROM pg_stat_user_tables ORDER BY n_live_tup DESC"

Write-Host "`n[SEQUENCES]" -ForegroundColor Green
Run-DB-Query "SELECT sequence_schema, sequence_name FROM information_schema.sequences ORDER BY sequence_name"

Write-Host "`n[VIEWS]" -ForegroundColor Green
Run-DB-Query "SELECT schemaname, viewname FROM pg_views WHERE schemaname NOT LIKE 'pg_%' AND schemaname <> 'information_schema' ORDER BY viewname"

# =============================================================================
# SECTION 5: INDEXES
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 5: INDEXES                                       #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[ALL INDEXES]" -ForegroundColor Green
Run-DB-Query "SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'public' ORDER BY tablename, indexname"

Write-Host "`n[INDEX USAGE]" -ForegroundColor Green
Run-DB-Query "SELECT relname as table_name, indexrelname as index_name, idx_scan as scans, idx_tup_read as tuples_read, idx_tup_fetch as tuples_fetched, pg_size_pretty(pg_relation_size(indexrelid)) as index_size FROM pg_stat_user_indexes ORDER BY idx_scan DESC"

Write-Host "`n[UNUSED INDEXES (0 scans)]" -ForegroundColor Green
Run-DB-Query "SELECT relname as table_name, indexrelname as index_name, pg_size_pretty(pg_relation_size(indexrelid)) as index_size FROM pg_stat_user_indexes WHERE idx_scan = 0 AND indexrelname NOT LIKE '%_pkey' ORDER BY pg_relation_size(indexrelid) DESC"

# =============================================================================
# SECTION 6: TABLE DATA PREVIEW
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 6: TABLE DATA PREVIEW                            #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[Users - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT id, username, email, created_at, is_verified FROM public."User" ORDER BY created_at DESC LIMIT 10'

Write-Host "`n[User Profiles - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT user_id, bio, location, created_at, updated_at FROM public."UserProfile" ORDER BY updated_at DESC NULLS LAST LIMIT 10'

Write-Host "`n[Games - All]" -ForegroundColor Green
Run-DB-Query 'SELECT * FROM public."Game" ORDER BY id'

Write-Host "`n[Game Requests - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT id, sender_id, receiver_id, game_id, status, created_at FROM public."GameRequest" ORDER BY created_at DESC LIMIT 10'

Write-Host "`n[Scheduled Sessions - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT id, host_id, guest_id, game_id, status, scheduled_time, created_at FROM public."ScheduledSession" ORDER BY created_at DESC LIMIT 10'

Write-Host "`n[User Availability - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT * FROM public."UserAvailability" LIMIT 10'

Write-Host "`n[User Friends - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT * FROM public."UserFriends" ORDER BY created_at DESC NULLS LAST LIMIT 10'

Write-Host "`n[User Game Preferences - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT * FROM public."UserGamePreference" LIMIT 10'

Write-Host "`n[User Notifications - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT id, user_id, type, message, is_read, created_at FROM public."UserNotifications" ORDER BY created_at DESC LIMIT 10'

Write-Host "`n[User Sessions - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT id, user_id, session_token, ip_address, last_activity FROM public."UserSession" ORDER BY last_activity DESC NULLS LAST LIMIT 10'

Write-Host "`n[Email Verification - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT id, user_id, is_verified, created_at, verified_at FROM public."EmailVerification" ORDER BY created_at DESC LIMIT 10'

Write-Host "`n[Password Reset Tokens - Recent 10]" -ForegroundColor Green
Run-DB-Query "SELECT * FROM password_reset_tokens ORDER BY created_at DESC LIMIT 10"

# =============================================================================
# SECTION 7: AUDIT & PROTECTION TABLES
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 7: AUDIT & PROTECTION                            #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[Backup Log - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT * FROM public."BackupLog" ORDER BY backup_time DESC LIMIT 10'

Write-Host "`n[Protection Status]" -ForegroundColor Green
Run-DB-Query 'SELECT * FROM public."ProtectionStatus"'

Write-Host "`n[Connection Audit Log - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT * FROM public."ConnectionAuditLog" ORDER BY connection_time DESC LIMIT 10'

Write-Host "`n[Delete Audit Log - Recent 10]" -ForegroundColor Green
Run-DB-Query 'SELECT * FROM public."DeleteAuditLog" ORDER BY deleted_at DESC LIMIT 10'

Write-Host "`n[Alembic Version (Migrations)]" -ForegroundColor Green
Run-DB-Query "SELECT * FROM alembic_version"

# =============================================================================
# SECTION 8: TRIGGERS & FUNCTIONS
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 8: TRIGGERS & FUNCTIONS                          #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[EVENT TRIGGERS]" -ForegroundColor Green
Run-DB-Query "SELECT evtname, evtevent, evtenabled, evtowner::regrole as owner FROM pg_event_trigger"

Write-Host "`n[TABLE TRIGGERS]" -ForegroundColor Green
Run-DB-Query "SELECT trigger_schema, trigger_name, event_manipulation, event_object_table, action_statement FROM information_schema.triggers WHERE trigger_schema = 'public' ORDER BY event_object_table, trigger_name"

Write-Host "`n[FUNCTIONS]" -ForegroundColor Green
Run-DB-Query "SELECT routine_name, routine_type, data_type as return_type FROM information_schema.routines WHERE routine_schema = 'public' ORDER BY routine_name"

Write-Host "`n[FOREIGN KEYS]" -ForegroundColor Green
Run-DB-Query "SELECT tc.table_name, kcu.column_name, ccu.table_name AS foreign_table, ccu.column_name AS foreign_column FROM information_schema.table_constraints AS tc JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name WHERE tc.constraint_type = 'FOREIGN KEY' ORDER BY tc.table_name"

# =============================================================================
# SECTION 9: ROLES & PERMISSIONS
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 9: ROLES & PERMISSIONS                           #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[DATABASE ROLES]" -ForegroundColor Green
Run-DB-Query "SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin, rolconnlimit, rolvaliduntil FROM pg_roles ORDER BY rolname"

Write-Host "`n[TABLE PRIVILEGES]" -ForegroundColor Green
Run-DB-Query "SELECT grantee, table_name, privilege_type FROM information_schema.table_privileges WHERE table_schema = 'public' ORDER BY table_name, grantee, privilege_type"

Write-Host "`n[HBA RULES (access control)]" -ForegroundColor Green
Run-DB-Query "SELECT line_number, type, database, user_name, address, auth_method FROM pg_hba_file_rules ORDER BY line_number"

# =============================================================================
# SECTION 10: REPLICATION & WAL
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 10: REPLICATION & WAL                            #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[REPLICATION STATUS]" -ForegroundColor Green
Run-DB-Query "SELECT * FROM pg_stat_replication"

Write-Host "`n[WAL STATS]" -ForegroundColor Green
Run-DB-Query "SELECT * FROM pg_stat_wal"

Write-Host "`n[ARCHIVER STATUS]" -ForegroundColor Green
Run-DB-Query "SELECT * FROM pg_stat_archiver"

# =============================================================================
# SECTION 11: PERFORMANCE METRICS
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 11: PERFORMANCE METRICS                          #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[DATABASE STATS]" -ForegroundColor Green
Run-DB-Query "SELECT datname, numbackends, xact_commit, xact_rollback, blks_read, blks_hit, tup_returned, tup_fetched, tup_inserted, tup_updated, tup_deleted, conflicts, deadlocks FROM pg_stat_database WHERE datname = current_database()"

Write-Host "`n[CACHE HIT RATIO]" -ForegroundColor Green
Run-DB-Query "SELECT round(100.0 * sum(blks_hit) / nullif(sum(blks_hit) + sum(blks_read), 0), 2) as cache_hit_ratio_percent FROM pg_stat_database WHERE datname = current_database()"

Write-Host "`n[TABLE I/O]" -ForegroundColor Green
Run-DB-Query "SELECT relname, heap_blks_read, heap_blks_hit, idx_blks_read, idx_blks_hit FROM pg_statio_user_tables ORDER BY heap_blks_read DESC LIMIT 10"

Write-Host "`n[SEQUENTIAL VS INDEX SCANS]" -ForegroundColor Green
Run-DB-Query "SELECT relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch FROM pg_stat_user_tables ORDER BY seq_scan DESC LIMIT 10"

Write-Host "`n[LOCK STATS]" -ForegroundColor Green
Run-DB-Query "SELECT locktype, mode, count(*) FROM pg_locks GROUP BY locktype, mode ORDER BY count DESC"

# =============================================================================
# SECTION 12: PGBOUNCER STATUS (SERVERS)
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 12: PGBOUNCER STATUS                             #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[PRODUCTION PGBOUNCER]" -ForegroundColor Green
$prodPgb = Run-Prod-Cmd "docker ps --filter name=pgbouncer --format '{{.Names}}: {{.Status}}' 2>/dev/null || echo 'Not running'"
if ($prodPgb) { Write-Host $prodPgb -ForegroundColor White }

Write-Host "`n[PRODUCTION PGBOUNCER LOGS (last 20)]" -ForegroundColor Green
$prodPgbLogs = Run-Prod-Cmd "docker logs tovplay-pgbouncer --tail 20 2>&1 || echo 'No logs available'"
if ($prodPgbLogs) { Write-Host $prodPgbLogs -ForegroundColor Gray }

Write-Host "`n[STAGING PGBOUNCER]" -ForegroundColor Green
$stagPgb = Run-Staging-Cmd "docker ps --filter name=pgbouncer --format '{{.Names}}: {{.Status}}' 2>/dev/null || echo 'Not running'"
if ($stagPgb) { Write-Host $stagPgb -ForegroundColor White }

# =============================================================================
# SECTION 13: LOCAL DATABASE CONFIG FILES
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 13: LOCAL DATABASE CONFIG                        #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[BACKEND .ENV DATABASE SETTINGS]" -ForegroundColor Green
$backendEnv = "F:\tovplay\tovplay-backend\.env"
if (Test-Path $backendEnv) {
    $envContent = Get-Content $backendEnv
    $dbVars = $envContent | Where-Object { $_ -match '^(DATABASE|DB_|POSTGRES|SQLALCHEMY)' }
    foreach ($line in $dbVars) {
        Write-Host $line -ForegroundColor White
    }
} else {
    Write-Host "Backend .env not found at $backendEnv" -ForegroundColor Red
}

Write-Host "`n[BACKEND DATABASE MODELS]" -ForegroundColor Green
$modelsPath = "F:\tovplay\tovplay-backend\src\database\models"
if (Test-Path $modelsPath) {
    $models = Get-ChildItem -Path $modelsPath -Filter "*.py" | Select-Object -ExpandProperty Name
    Write-Host "Models directory: $modelsPath" -ForegroundColor DarkGray
    foreach ($model in $models) {
        Write-Host "  - $model" -ForegroundColor White
    }
} else {
    Write-Host "Models directory not found" -ForegroundColor Red
}

Write-Host "`n[ALEMBIC MIGRATIONS]" -ForegroundColor Green
$migrationsPath = "F:\tovplay\tovplay-backend\migrations\versions"
if (Test-Path $migrationsPath) {
    $migrations = Get-ChildItem -Path $migrationsPath -Filter "*.py" | Sort-Object LastWriteTime -Descending | Select-Object -First 10
    Write-Host "Migrations directory: $migrationsPath" -ForegroundColor DarkGray
    Write-Host "Recent migrations:" -ForegroundColor White
    foreach ($m in $migrations) {
        Write-Host "  - $($m.Name) ($($m.LastWriteTime))" -ForegroundColor Gray
    }
} else {
    Write-Host "Migrations directory not found" -ForegroundColor Red
}

# =============================================================================
# SECTION 14: DATABASE BACKUP INFO
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 14: DATABASE BACKUP INFO                         #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[LOCAL BACKUPS]" -ForegroundColor Green
$backupPath = "F:\backup\tovplay\DB"
if (Test-Path $backupPath) {
    $backups = Get-ChildItem -Path $backupPath -Filter "*.sql" | Sort-Object LastWriteTime -Descending | Select-Object -First 10
    Write-Host "Backup directory: $backupPath" -ForegroundColor DarkGray
    Write-Host "Recent backups:" -ForegroundColor White
    foreach ($b in $backups) {
        $sizeMB = [math]::Round($b.Length / 1MB, 2)
        Write-Host "  - $($b.Name) (${sizeMB}MB, $($b.LastWriteTime))" -ForegroundColor Gray
    }
} else {
    Write-Host "Backup directory not found at $backupPath" -ForegroundColor Red
}

Write-Host "`n[BACKUP COMMAND]" -ForegroundColor Green
Write-Host "# Create backup:" -ForegroundColor DarkGray
Write-Host "`$f=`"F:\backup\tovplay\DB\tovplay_`$(Get-Date -Format 'yyyyMMdd_HHmmss').sql`"; wsl -d ubuntu bash -c 'PGPASSWORD=`"$dbPass`" pg_dump -h $dbHost -U `"$dbUser`" -d $dbName' > `$f" -ForegroundColor Cyan
Write-Host "# Or use backdb function from profile" -ForegroundColor DarkGray

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "                      DATABASE DATA COMPLETE                          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Script completed at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
Write-Host "Database: $dbName @ $dbHost" -ForegroundColor White
Write-Host "For specific table queries, use psql interactively" -ForegroundColor DarkGray
