# b.ps1 - TovPlay Infrastructure QUICK STATUS CHECK
# ALWAYS reads credentials from credentials.json - NEVER hardcoded
# Usage: .\b.ps1
# PowerShell v5 compatible

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
$dbUser = $creds.servers.database.user
$dbPass = $creds.servers.database.password
$dbName = $creds.servers.database.database

# =============================================================================
# HEADER
# =============================================================================
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "           TOVPLAY QUICK STATUS - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
Write-Host "  Credentials from: $credFile" -ForegroundColor DarkGray
Write-Host "================================================================" -ForegroundColor Cyan

# =============================================================================
# HELPER FUNCTIONS (base64 encoding to avoid quote escaping issues)
# =============================================================================
# Production SSH via staging jump host - uses base64 to avoid quote hell
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

# Staging SSH - uses base64 to avoid quote issues
function Run-Staging-Cmd($cmd) {
    $escapedPass = $stagingPass -replace "'", "'\''"
    $cmdBytes = [System.Text.Encoding]::UTF8.GetBytes($cmd)
    $cmdBase64 = [Convert]::ToBase64String($cmdBytes)
    $bashScript = "sshpass -p '$escapedPass' ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $stagingUser@$stagingHost 'echo $cmdBase64 | base64 -d | bash' 2>/dev/null"
    wsl -d ubuntu bash -c $bashScript 2>$null
}

# DB query with base64 encoding for quoted table names - pipe to bash for $() expansion
function Run-DB-Query($query) {
    $queryBytes = [System.Text.Encoding]::UTF8.GetBytes($query)
    $queryBase64 = [Convert]::ToBase64String($queryBytes)
    $bashCmd = "PAGER=cat PGPASSWORD=$dbPass psql -h $dbHost -U $dbUser -d $dbName -c `"`$(echo $queryBase64 | base64 -d)`""
    $bashCmd | wsl -d ubuntu bash 2>$null
}

# =============================================================================
# PRODUCTION SERVER (via staging jump host for reliability)
# =============================================================================

Write-Host "`n[PROD $prodHost] Health (via staging):" -ForegroundColor Green
Run-Prod-Cmd "uptime -p; free -h | grep Mem; df -h / | tail -1"

Write-Host "`n[PROD] Docker Containers:" -ForegroundColor Green
Run-Prod-Cmd 'docker ps -a --format "table {{.Names}}\t{{.Status}}"'

Write-Host "`n[PROD] Resource Usage:" -ForegroundColor Green
Run-Prod-Cmd 'timeout 10 docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"'

# =============================================================================
# STAGING SERVER
# =============================================================================
Write-Host "`n[STAGING $stagingHost] Health:" -ForegroundColor Blue
Run-Staging-Cmd "uptime -p; free -h | grep Mem; df -h / | tail -1"

Write-Host "`n[STAGING] Docker Containers:" -ForegroundColor Blue
Run-Staging-Cmd 'docker ps -a --format "table {{.Names}}\t{{.Status}}"'

# =============================================================================
# DATABASE SERVER
# =============================================================================
Write-Host "`n[DB $dbHost] Status:" -ForegroundColor Red
Run-DB-Query "SELECT pg_size_pretty(pg_database_size(current_database())) as size"

Write-Host "`n[DB] Tables with Data:" -ForegroundColor Red
Run-DB-Query "SELECT relname as table_name, n_live_tup as rows FROM pg_stat_user_tables WHERE n_live_tup > 0 ORDER BY n_live_tup DESC"

Write-Host "`n[DB] Connections:" -ForegroundColor Red
Run-DB-Query "SELECT client_addr as ip, count(*) as conn FROM pg_stat_activity WHERE datname = current_database() AND client_addr IS NOT NULL GROUP BY client_addr ORDER BY conn DESC"

Write-Host "`n[DB] Protection Triggers:" -ForegroundColor Red
Run-DB-Query "SELECT count(*) FROM pg_event_trigger"

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Links:" -ForegroundColor Cyan
Write-Host "  Production: $($creds.urls.production)" -ForegroundColor White
Write-Host "  Staging:    $($creds.urls.staging)" -ForegroundColor White
Write-Host "  Errors:     $($creds.urls.logs)" -ForegroundColor White
Write-Host "  DB Viewer:  $($creds.urls.db_viewer)" -ForegroundColor White
Write-Host "  Grafana:    $($creds.urls.grafana)" -ForegroundColor White
