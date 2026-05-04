# a.ps1 - TovPlay Infrastructure COMPLETE DATA DUMP
# Combines ALL data from: d.ps1, b.ps1, architecture.ps1, db.ps1, debug.ps1
# ALWAYS reads credentials from credentials.json - NEVER hardcoded
# Usage: .\a.ps1
# Run time: ~60-90s
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
$dbPort = $creds.servers.database.port
$dbUser = $creds.servers.database.user
$dbPass = $creds.servers.database.password
$dbName = $creds.servers.database.database

# Load backend .env for Discord/Email info
$backendEnv = "F:\tovplay\tovplay-backend\.env"
$envVars = @{}
if (Test-Path $backendEnv) {
    Get-Content $backendEnv | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $envVars[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
}

# =============================================================================
# HELPER FUNCTIONS (base64 encoding to avoid quote escaping issues)
# =============================================================================

# URL health check
function Test-Endpoint($url, $name) {
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        $status = $response.StatusCode
        $color = if ($status -eq 200) { "Green" } else { "Yellow" }
        Write-Host "  [OK $status] $name - $url" -ForegroundColor $color
    } catch {
        Write-Host "  [FAIL] $name - $url - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Port check
function Test-Port($hostName, $port) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $result = $tcp.BeginConnect($hostName, $port, $null, $null)
        $wait = $result.AsyncWaitHandle.WaitOne(2000, $false)
        if ($wait -and $tcp.Connected) { $tcp.Close(); return $true }
        $tcp.Close(); return $false
    } catch { return $false }
}
# Production SSH via staging jump host - uses base64 to avoid quote hell
function Run-Prod-Cmd($cmd) {
    $escapedStagingPass = $stagingPass -replace "'", "'\''"
    $escapedProdPass = $prodPass -replace "'", "'\''"
    $cmdBytes = [System.Text.Encoding]::UTF8.GetBytes($cmd)
    $cmdBase64 = [Convert]::ToBase64String($cmdBytes)
    $innerCmd = "echo $cmdBase64 | base64 -d | bash"
    $escapedInnerCmd = $innerCmd -replace "'", "'\''"
    $bashScript = "sshpass -p '<REDACTED_TOVTECH_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $stagingUser@$stagingHost 'sshpass -p '\''$escapedProdPass'\'' ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR admin@$prodHost '\''$escapedInnerCmd'\''' 2>/dev/null"
    wsl -d ubuntu bash -c $bashScript 2>$null
}

# Staging SSH - uses base64 to avoid quote issues
function Run-Staging-Cmd($cmd) {
    $escapedPass = $stagingPass -replace "'", "'\''"
    $cmdBytes = [System.Text.Encoding]::UTF8.GetBytes($cmd)
    $cmdBase64 = [Convert]::ToBase64String($cmdBytes)
    $bashScript = "sshpass -p '<REDACTED_TOVTECH_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $stagingUser@$stagingHost 'echo $cmdBase64 | base64 -d | bash' 2>/dev/null"
    wsl -d ubuntu bash -c $bashScript 2>$null
}

# DB query with base64 encoding for quoted table names - pipe to bash for $() expansion
function Run-DB-Query($query) {
    $queryBytes = [System.Text.Encoding]::UTF8.GetBytes($query)
    $queryBase64 = [Convert]::ToBase64String($queryBytes)
    $bashCmd = "PAGER=cat PGPASSWORD=<REDACTED_TOVTECH_DB_PASSWORD> psql -h $dbHost -U '$dbUser' -d $dbName -c `"`$(echo $queryBase64 | base64 -d)`""
    $bashCmd | wsl -d ubuntu bash 2>$null
}

# =============================================================================
# HEADER
# =============================================================================
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         TOVPLAY INFRASTRUCTURE - COMPLETE DATA DUMP                  " -ForegroundColor Cyan
Write-Host "         Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')         " -ForegroundColor Cyan
Write-Host "  Credentials loaded from: $credFile" -ForegroundColor DarkGray
Write-Host "======================================================================" -ForegroundColor Cyan

# =============================================================================
# SECTION 0: CREDENTIALS & REFERENCE DATA (from d.ps1)
# =============================================================================
Write-Host "`n##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 0: CREDENTIALS & REFERENCE DATA                  #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[SERVERS]" -ForegroundColor Green
$prod = $creds.servers.production
$stag = $creds.servers.staging
$db = $creds.servers.database
Write-Host "Production: $($prod.host) | $($prod.user) / $($prod.password)" -ForegroundColor White
Write-Host "Staging:    $($stag.host) | $($stag.user) / $($stag.password)" -ForegroundColor White
Write-Host "Database:   $($db.host):$($db.port) | $($db.user) / $($db.password) | $($db.database)" -ForegroundColor White

Write-Host "`n[SSH COMMANDS]" -ForegroundColor Green
Write-Host "# Staging (direct):" -ForegroundColor DarkGray
Write-Host "wsl -d ubuntu bash -c 'sshpass -p `"$($stag.password)`" ssh -o StrictHostKeyChecking=no $($stag.user)@$($stag.host)'" -ForegroundColor Cyan
Write-Host "# Production (via staging):" -ForegroundColor DarkGray
Write-Host "wsl -d ubuntu bash -c 'sshpass -p `"$($stag.password)`" ssh -tt $($stag.user)@$($stag.host) `"sshpass -p $($prod.password) ssh admin@$($prod.host)`"'" -ForegroundColor Cyan
Write-Host "# Database:" -ForegroundColor DarkGray
Write-Host "wsl -d ubuntu bash -c 'PAGER=cat PGPASSWORD=`"$($db.password)`" psql -h $($db.host) -U `"$($db.user)`" -d $($db.database)'" -ForegroundColor Cyan

Write-Host "`n[AWS S3]" -ForegroundColor Green
$aws = $creds.aws
Write-Host "console: $($aws.console)" -ForegroundColor White
Write-Host "user: $($aws.user) | pass: $($aws.password)" -ForegroundColor White
Write-Host "access: $($aws.access_key)" -ForegroundColor White
Write-Host "secret: $($aws.secret_key)" -ForegroundColor White

Write-Host "`n[DOCKER HUB]" -ForegroundColor Green
$docker = $creds.docker_hub
Write-Host "user: $($docker.user) | pass: $($docker.password)" -ForegroundColor White

Write-Host "`n[EMAIL SMTP]" -ForegroundColor Green
Write-Host "server: $($envVars['SMTP_SERVER']):$($envVars['SMTP_PORT'])" -ForegroundColor White
Write-Host "sender: $($envVars['EMAIL_SENDER']) | pass: $($envVars['EMAIL_PASSWORD'])" -ForegroundColor White

Write-Host "`n[DISCORD BOT]" -ForegroundColor Green
Write-Host "client_id: $($envVars['DISCORD_CLIENT_ID'])" -ForegroundColor White
Write-Host "client_secret: <REDACTED_TOVTECH_CLIENT_SECRET>CLIENT_SECRET'])" -ForegroundColor White
Write-Host "token: $($envVars['DISCORD_TOKEN'])" -ForegroundColor White
Write-Host "guild_id: $($envVars['DISCORD_GUILD_ID'])" -ForegroundColor White
Write-Host "invite: $($envVars['DISCORD_INVITE_LINK'])" -ForegroundColor White

Write-Host "`n[TEST USERS]" -ForegroundColor Green
foreach ($user in $creds.test_users) {
    Write-Host "$($user.email) / $($user.username) / $($user.password)" -ForegroundColor White
}

Write-Host "`n[APP URLS]" -ForegroundColor Green
Write-Host "Production:  $($creds.urls.production)" -ForegroundColor White
Write-Host "Staging:     $($creds.urls.staging)" -ForegroundColor White
Write-Host "Logs:        $($creds.urls.logs)" -ForegroundColor White
Write-Host "Grafana:     $($creds.urls.grafana)" -ForegroundColor White
Write-Host "Prometheus:  $($creds.urls.prometheus)" -ForegroundColor White
Write-Host "DB Viewer:   $($creds.urls.db_viewer)" -ForegroundColor White
Write-Host "GitHub BE:   $($creds.urls.github_backend)" -ForegroundColor White
Write-Host "GitHub FE:   $($creds.urls.github_frontend)" -ForegroundColor White
Write-Host "Jira:        $($creds.urls.jira)" -ForegroundColor White

Write-Host "`n[TEAM]" -ForegroundColor Green
foreach ($member in $creds.team) {
    if ($member.email) {
        Write-Host "$($member.name) ($($member.email))" -ForegroundColor White
    } else {
        Write-Host "$($member.name)" -ForegroundColor White
    }
}

# =============================================================================
# SECTION 1: ENDPOINT HEALTH & PORT CONNECTIVITY (from debug.ps1)
# =============================================================================
Write-Host "`n##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 1: ENDPOINT HEALTH & CONNECTIVITY                #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[PRODUCTION ENDPOINTS]" -ForegroundColor Green
Test-Endpoint "$($creds.urls.production)" "Frontend"
Test-Endpoint "$($creds.urls.production)/api/health" "Backend API"
Test-Endpoint "$($creds.urls.logs)" "Error Dashboard"
Test-Endpoint "$($creds.urls.grafana)" "Grafana"
Test-Endpoint "$($creds.urls.prometheus)" "Prometheus"
Test-Endpoint "$($creds.urls.db_viewer)" "DB Viewer"

Write-Host "`n[STAGING ENDPOINTS]" -ForegroundColor Green
Test-Endpoint "$($creds.urls.staging)" "Staging Frontend"
Test-Endpoint "$($creds.urls.staging)/api/health" "Staging API"

Write-Host "`n[PORT CONNECTIVITY]" -ForegroundColor Green
$ports = @(
    @{ Host = $prodHost; Port = 22; Name = "Production SSH" },
    @{ Host = $prodHost; Port = 443; Name = "Production HTTPS" },
    @{ Host = $prodHost; Port = 80; Name = "Production HTTP" },
    @{ Host = $stagingHost; Port = 22; Name = "Staging SSH" },
    @{ Host = $stagingHost; Port = 443; Name = "Staging HTTPS" },
    @{ Host = $dbHost; Port = 5432; Name = "Database PostgreSQL" }
)
foreach ($p in $ports) {
    $open = Test-Port $p.Host $p.Port
    $status = if ($open) { "[OPEN]" } else { "[CLOSED]" }
    $color = if ($open) { "Green" } else { "Red" }
    Write-Host "  $status $($p.Name) - $($p.Host):$($p.Port)" -ForegroundColor $color
}

# =============================================================================
# SECTION 2: PRODUCTION SERVER (via staging jump host)
# =============================================================================
Write-Host "`n##############################################################################" -ForegroundColor Green
Write-Host "#                   SECTION 2: PRODUCTION SERVER ($prodHost)                  #" -ForegroundColor Green
Write-Host "##############################################################################" -ForegroundColor Green
Write-Host "[PROD] Running commands via staging jump host..." -ForegroundColor Yellow

Write-Host "`n=== PROD System Info ===" -ForegroundColor Cyan
Run-Prod-Cmd "uname -a && cat /etc/os-release"

Write-Host "`n=== PROD Uptime ===" -ForegroundColor Cyan
Run-Prod-Cmd "uptime"

Write-Host "`n=== PROD Memory ===" -ForegroundColor Cyan
Run-Prod-Cmd "free -h"

Write-Host "`n=== PROD Disk ===" -ForegroundColor Cyan
Run-Prod-Cmd "df -h"

Write-Host "`n=== PROD Disk Inodes ===" -ForegroundColor Cyan
Run-Prod-Cmd "df -i"

Write-Host "`n=== PROD Top 20 Dirs ===" -ForegroundColor Cyan
Run-Prod-Cmd "du -hx / 2>/dev/null | sort -rh | head -20"

Write-Host "`n=== PROD CPU ===" -ForegroundColor Cyan
Run-Prod-Cmd "lscpu | head -20"

Write-Host "`n=== PROD Network ===" -ForegroundColor Cyan
Run-Prod-Cmd "ip addr"

Write-Host "`n=== PROD Listening Ports ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo ss -tlnp 2>/dev/null"

Write-Host "`n=== PROD Active Connections ===" -ForegroundColor Cyan
Run-Prod-Cmd "ss -an | grep ESTAB | head -30"

Write-Host "`n=== PROD Processes ===" -ForegroundColor Cyan
Run-Prod-Cmd "ps aux --sort=-%mem | head -30"

Write-Host "`n=== PROD Systemd ===" -ForegroundColor Cyan
Run-Prod-Cmd "systemctl list-units --type=service --state=running --no-pager"

Write-Host "`n=== PROD Docker Version ===" -ForegroundColor Cyan
Run-Prod-Cmd "docker version 2>&1 | head -20"

Write-Host "`n=== PROD Docker Info ===" -ForegroundColor Cyan
Run-Prod-Cmd "docker info 2>&1 | head -40"

Write-Host "`n=== PROD Docker Containers ===" -ForegroundColor Cyan
Run-Prod-Cmd "docker ps -a 2>&1"

Write-Host "`n=== PROD Docker Stats ===" -ForegroundColor Cyan
Run-Prod-Cmd "timeout 10 docker stats --no-stream 2>&1"

Write-Host "`n=== PROD Docker Images ===" -ForegroundColor Cyan
Run-Prod-Cmd "docker images 2>&1"

Write-Host "`n=== PROD Docker Volumes ===" -ForegroundColor Cyan
Run-Prod-Cmd "docker volume ls 2>&1"

Write-Host "`n=== PROD Docker Networks ===" -ForegroundColor Cyan
Run-Prod-Cmd "docker network ls 2>&1"

Write-Host "`n=== PROD Docker Compose ===" -ForegroundColor Cyan
Run-Prod-Cmd "cat /home/admin/tovplay/docker-compose.yml 2>/dev/null"

Write-Host "`n=== PROD Nginx Status ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo nginx -t 2>&1 && sudo systemctl status nginx --no-pager 2>&1 | head -20"

Write-Host "`n=== PROD Nginx Config ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo cat /etc/nginx/sites-enabled/* 2>/dev/null | head -200"

Write-Host "`n=== PROD SSL Certificates ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo ls -la /etc/letsencrypt/live/ 2>/dev/null"

Write-Host "`n=== PROD SSL Certificate Expiry ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo certbot certificates 2>/dev/null | grep -A3 'Domains\|Expiry' || echo 'Check manually'"

Write-Host "`n=== PROD System Crontab ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo cat /etc/crontab"

Write-Host "`n=== PROD Root Crontab ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo crontab -l 2>/dev/null"

Write-Host "`n=== PROD Admin Crontab ===" -ForegroundColor Cyan
Run-Prod-Cmd "crontab -l 2>/dev/null"

Write-Host "`n=== PROD Env ===" -ForegroundColor Cyan
Run-Prod-Cmd "cat /home/admin/tovplay/.env 2>/dev/null | head -50"

Write-Host "`n=== PROD Backend Logs ===" -ForegroundColor Cyan
Run-Prod-Cmd "timeout 5 docker logs tovplay-backend --tail 50 2>&1"

Write-Host "`n=== PROD Nginx Error ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo tail -30 /var/log/nginx/error.log 2>/dev/null"

Write-Host "`n=== PROD Syslog ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo tail -30 /var/log/syslog 2>/dev/null"

Write-Host "`n=== PROD Auth Log ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo tail -30 /var/log/auth.log 2>/dev/null"

Write-Host "`n=== PROD Firewall ===" -ForegroundColor Cyan
Run-Prod-Cmd "sudo ufw status verbose 2>/dev/null"

Write-Host "`n=== PROD Prometheus ===" -ForegroundColor Cyan
Run-Prod-Cmd "curl -s --max-time 5 http://localhost:9090/api/v1/targets 2>/dev/null | head -100"

Write-Host "`n=== PROD Loki ===" -ForegroundColor Cyan
Run-Prod-Cmd "curl -s --max-time 5 http://localhost:3100/ready 2>/dev/null"

Write-Host "`n=== PROD pgBouncer ===" -ForegroundColor Cyan
Run-Prod-Cmd "timeout 3 docker logs tovplay-pgbouncer --tail 20 2>&1"

Write-Host "`n=== PROD Grafana ===" -ForegroundColor Cyan
Run-Prod-Cmd "curl -s --max-time 5 http://localhost:3002/api/health 2>/dev/null"

Write-Host "`n=== PROD Container Health ===" -ForegroundColor Cyan
Run-Prod-Cmd "docker ps --format 'Container: {{.Names}} - Status: {{.Status}}' 2>/dev/null"

# =============================================================================
# SECTION 3: STAGING SERVER
# =============================================================================
Write-Host "`n##############################################################################" -ForegroundColor Blue
Write-Host "#                   SECTION 3: STAGING SERVER ($stagingHost)                  #" -ForegroundColor Blue
Write-Host "##############################################################################" -ForegroundColor Blue
Write-Host "[STAGING] Running commands..." -ForegroundColor Yellow

Write-Host "`n=== STAGING System Info ===" -ForegroundColor Cyan
Run-Staging-Cmd "uname -a && cat /etc/os-release"

Write-Host "`n=== STAGING Uptime ===" -ForegroundColor Cyan
Run-Staging-Cmd "uptime"

Write-Host "`n=== STAGING Memory ===" -ForegroundColor Cyan
Run-Staging-Cmd "free -h"

Write-Host "`n=== STAGING Disk ===" -ForegroundColor Cyan
Run-Staging-Cmd "df -h"

Write-Host "`n=== STAGING Disk Inodes ===" -ForegroundColor Cyan
Run-Staging-Cmd "df -i"

Write-Host "`n=== STAGING Top 20 Dirs ===" -ForegroundColor Cyan
Run-Staging-Cmd "du -hx / 2>/dev/null | sort -rh | head -20"

Write-Host "`n=== STAGING CPU ===" -ForegroundColor Cyan
Run-Staging-Cmd "lscpu | head -20"

Write-Host "`n=== STAGING Network ===" -ForegroundColor Cyan
Run-Staging-Cmd "ip addr"

Write-Host "`n=== STAGING Listening Ports ===" -ForegroundColor Cyan
Run-Staging-Cmd "sudo ss -tlnp 2>/dev/null"

Write-Host "`n=== STAGING Active Connections ===" -ForegroundColor Cyan
Run-Staging-Cmd "ss -an | grep ESTAB | head -30"

Write-Host "`n=== STAGING Processes ===" -ForegroundColor Cyan
Run-Staging-Cmd "ps aux --sort=-%mem | head -30"

Write-Host "`n=== STAGING Systemd ===" -ForegroundColor Cyan
Run-Staging-Cmd "systemctl list-units --type=service --state=running --no-pager"

Write-Host "`n=== STAGING Docker Version ===" -ForegroundColor Cyan
Run-Staging-Cmd "docker version 2>&1 | head -20"

Write-Host "`n=== STAGING Docker Containers ===" -ForegroundColor Cyan
Run-Staging-Cmd "docker ps -a 2>&1"

Write-Host "`n=== STAGING Docker Stats ===" -ForegroundColor Cyan
Run-Staging-Cmd "timeout 10 docker stats --no-stream 2>&1"

Write-Host "`n=== STAGING Docker Images ===" -ForegroundColor Cyan
Run-Staging-Cmd "docker images 2>&1"

Write-Host "`n=== STAGING Docker Volumes ===" -ForegroundColor Cyan
Run-Staging-Cmd "docker volume ls 2>&1"

Write-Host "`n=== STAGING Docker Networks ===" -ForegroundColor Cyan
Run-Staging-Cmd "docker network ls 2>&1"

Write-Host "`n=== STAGING Docker Compose ===" -ForegroundColor Cyan
Run-Staging-Cmd "cat /home/admin/tovplay/docker-compose.yml 2>/dev/null"

Write-Host "`n=== STAGING Nginx Status ===" -ForegroundColor Cyan
Run-Staging-Cmd "sudo nginx -t 2>&1 && sudo systemctl status nginx --no-pager 2>&1 | head -20"

Write-Host "`n=== STAGING Nginx Config ===" -ForegroundColor Cyan
Run-Staging-Cmd "sudo cat /etc/nginx/sites-enabled/* 2>/dev/null | head -200"

Write-Host "`n=== STAGING SSL ===" -ForegroundColor Cyan
Run-Staging-Cmd "sudo ls -la /etc/letsencrypt/live/ 2>/dev/null"

Write-Host "`n=== STAGING Crontab ===" -ForegroundColor Cyan
Run-Staging-Cmd "sudo cat /etc/crontab && sudo crontab -l 2>/dev/null && crontab -l 2>/dev/null"

Write-Host "`n=== STAGING Env ===" -ForegroundColor Cyan
Run-Staging-Cmd "cat /home/admin/tovplay/.env 2>/dev/null | head -50"

Write-Host "`n=== STAGING Backend Logs ===" -ForegroundColor Cyan
Run-Staging-Cmd "timeout 5 docker logs tovplay-backend-staging --tail 50 2>&1"

Write-Host "`n=== STAGING Nginx Error ===" -ForegroundColor Cyan
Run-Staging-Cmd "sudo tail -30 /var/log/nginx/error.log 2>/dev/null"

Write-Host "`n=== STAGING Firewall ===" -ForegroundColor Cyan
Run-Staging-Cmd "sudo ufw status verbose 2>/dev/null"

Write-Host "`n=== STAGING Container Health ===" -ForegroundColor Cyan
Run-Staging-Cmd "docker ps --format 'Container: {{.Names}} - Status: {{.Status}}' 2>/dev/null"

# =============================================================================
# SECTION 4: DATABASE SERVER
# =============================================================================
Write-Host "`n##############################################################################" -ForegroundColor Red
Write-Host "#                   SECTION 4: DATABASE SERVER ($dbHost)                      #" -ForegroundColor Red
Write-Host "##############################################################################" -ForegroundColor Red
Write-Host "[DB] Running queries..." -ForegroundColor Yellow

Write-Host "`n=== DB Version ===" -ForegroundColor Cyan
Run-DB-Query "SELECT version()"

Write-Host "`n=== DB Size ===" -ForegroundColor Cyan
Run-DB-Query "SELECT pg_size_pretty(pg_database_size(current_database())) as db_size"

Write-Host "`n=== DB Tables ===" -ForegroundColor Cyan
Run-DB-Query "SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT LIKE 'pg_%' AND schemaname <> 'information_schema' ORDER BY tablename"

Write-Host "`n=== DB Row Counts ===" -ForegroundColor Cyan
Run-DB-Query "SELECT relname as table_name, n_live_tup as row_count FROM pg_stat_user_tables ORDER BY n_live_tup DESC"

Write-Host "`n=== DB Active Connections ===" -ForegroundColor Cyan
Run-DB-Query "SELECT pid, usename, client_addr, state, query_start FROM pg_stat_activity WHERE datname IS NOT NULL ORDER BY query_start DESC NULLS LAST LIMIT 20"

Write-Host "`n=== DB Connections by IP ===" -ForegroundColor Cyan
Run-DB-Query "SELECT client_addr, count(*) as connections FROM pg_stat_activity WHERE datname = current_database() AND client_addr IS NOT NULL GROUP BY client_addr ORDER BY connections DESC"

Write-Host "`n=== DB Long Running Queries ===" -ForegroundColor Cyan
Run-DB-Query "SELECT pid, usename, state, query_start FROM pg_stat_activity WHERE state IN ('active', 'idle in transaction') ORDER BY query_start"

Write-Host "`n=== DB Roles ===" -ForegroundColor Cyan
Run-DB-Query "SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin FROM pg_roles ORDER BY rolname"

Write-Host "`n=== DB Settings ===" -ForegroundColor Cyan
Run-DB-Query "SELECT name, setting, unit FROM pg_settings WHERE name IN ('max_connections', 'shared_buffers', 'work_mem')"

Write-Host "`n=== DB Event Triggers ===" -ForegroundColor Cyan
Run-DB-Query "SELECT evtname, evtevent, evtenabled FROM pg_event_trigger"

Write-Host "`n=== DB Index Stats ===" -ForegroundColor Cyan
Run-DB-Query "SELECT relname, indexrelname, idx_scan FROM pg_stat_user_indexes ORDER BY idx_scan DESC LIMIT 20"

Write-Host "`n=== DB Table Stats ===" -ForegroundColor Cyan
Run-DB-Query "SELECT relname, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum FROM pg_stat_user_tables ORDER BY n_live_tup DESC"

Write-Host "`n=== DB Replication ===" -ForegroundColor Cyan
Run-DB-Query "SELECT * FROM pg_stat_replication"

Write-Host "`n=== DB HBA Rules ===" -ForegroundColor Cyan
Run-DB-Query "SELECT * FROM pg_hba_file_rules"

Write-Host "`n=== DB Extensions ===" -ForegroundColor Cyan
Run-DB-Query "SELECT extname, extversion FROM pg_extension"

Write-Host "`n=== DB Users ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT id, username, email, created_at FROM public."User" ORDER BY created_at DESC LIMIT 10'

Write-Host "`n=== DB Games ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."Game" LIMIT 20'

Write-Host "`n=== DB Sessions ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."ScheduledSession" ORDER BY created_at DESC LIMIT 10'

Write-Host "`n=== DB Game Requests ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."GameRequest" ORDER BY created_at DESC LIMIT 10'

Write-Host "`n=== DB Notifications ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."UserNotifications" ORDER BY created_at DESC LIMIT 10'

Write-Host "`n=== DB Backup Log ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."BackupLog" ORDER BY backup_time DESC LIMIT 10'

Write-Host "`n=== DB Protection Status ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."ProtectionStatus"'

Write-Host "`n=== DB Connection Audit ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."ConnectionAuditLog" ORDER BY connection_time DESC LIMIT 10'

Write-Host "`n=== DB Delete Audit ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."DeleteAuditLog" ORDER BY deleted_at DESC LIMIT 10'

Write-Host "`n=== DB User Profiles ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."UserProfile" LIMIT 10'

Write-Host "`n=== DB User Availability ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."UserAvailability" LIMIT 10'

Write-Host "`n=== DB User Friends ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."UserFriends" LIMIT 10'

Write-Host "`n=== DB Game Preferences ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."UserGamePreference" LIMIT 10'

Write-Host "`n=== DB Email Verification ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."EmailVerification" ORDER BY created_at DESC LIMIT 10'

Write-Host "`n=== DB User Sessions ===" -ForegroundColor Cyan
Run-DB-Query 'SELECT * FROM public."UserSession" ORDER BY last_activity DESC NULLS LAST LIMIT 10'

Write-Host "`n=== DB Password Reset Tokens ===" -ForegroundColor Cyan
Run-DB-Query "SELECT * FROM password_reset_tokens ORDER BY created_at DESC LIMIT 10"

Write-Host "`n=== DB Alembic Version ===" -ForegroundColor Cyan
Run-DB-Query "SELECT * FROM alembic_version"

Write-Host "`n=== DB Performance: Cache Hit Ratio ===" -ForegroundColor Cyan
Run-DB-Query "SELECT round(100.0 * sum(blks_hit) / nullif(sum(blks_hit) + sum(blks_read), 0), 2) as cache_hit_pct FROM pg_stat_database WHERE datname = current_database()"

Write-Host "`n=== DB Performance: Deadlocks ===" -ForegroundColor Cyan
Run-DB-Query "SELECT deadlocks FROM pg_stat_database WHERE datname = current_database()"

Write-Host "`n=== DB Performance: Table Bloat (dead tuples) ===" -ForegroundColor Cyan
Run-DB-Query "SELECT relname, n_live_tup, n_dead_tup, round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 2) as dead_pct FROM pg_stat_user_tables WHERE n_dead_tup > 100 ORDER BY n_dead_tup DESC LIMIT 10"

Write-Host "`n=== DB Indexes: All Indexes ===" -ForegroundColor Cyan
Run-DB-Query "SELECT schemaname, tablename, indexname FROM pg_indexes WHERE schemaname = 'public' ORDER BY tablename, indexname"

Write-Host "`n=== DB Indexes: Unused (0 scans) ===" -ForegroundColor Cyan
Run-DB-Query "SELECT relname, indexrelname, pg_size_pretty(pg_relation_size(indexrelid)) as size FROM pg_stat_user_indexes WHERE idx_scan = 0 AND indexrelname NOT LIKE '%_pkey' ORDER BY pg_relation_size(indexrelid) DESC"

Write-Host "`n=== DB Triggers: Event Triggers ===" -ForegroundColor Cyan
Run-DB-Query "SELECT evtname, evtevent, evtenabled, evtowner::regrole as owner FROM pg_event_trigger"

Write-Host "`n=== DB Triggers: Table Triggers ===" -ForegroundColor Cyan
Run-DB-Query "SELECT trigger_schema, trigger_name, event_manipulation, event_object_table FROM information_schema.triggers WHERE trigger_schema = 'public' ORDER BY event_object_table"

Write-Host "`n=== DB Functions ===" -ForegroundColor Cyan
Run-DB-Query "SELECT routine_name, routine_type, data_type as return_type FROM information_schema.routines WHERE routine_schema = 'public' ORDER BY routine_name"

Write-Host "`n=== DB Foreign Keys ===" -ForegroundColor Cyan
Run-DB-Query "SELECT tc.table_name, kcu.column_name, ccu.table_name AS foreign_table, ccu.column_name AS foreign_column FROM information_schema.table_constraints AS tc JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name WHERE tc.constraint_type = 'FOREIGN KEY' ORDER BY tc.table_name"

# =============================================================================
# SECTION 5: LOCAL DEVELOPMENT (from debug.ps1)
# =============================================================================
Write-Host "`n##############################################################################" -ForegroundColor Green
Write-Host "#                   SECTION 5: LOCAL DEVELOPMENT                             #" -ForegroundColor Green
Write-Host "##############################################################################" -ForegroundColor Green

Write-Host "`n[LOCAL ENV FILES]" -ForegroundColor Green
$envFiles = @(
    "F:\tovplay\tovplay-backend\.env",
    "F:\tovplay\tovplay-frontend\.env",
    "F:\tovplay\tovplay-backend\.env.template",
    "F:\tovplay\tovplay-frontend\.env.template"
)
foreach ($ef in $envFiles) {
    if (Test-Path $ef) {
        $lastMod = (Get-Item $ef).LastWriteTime
        Write-Host "  [OK] $ef (modified: $lastMod)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $ef" -ForegroundColor Red
    }
}

Write-Host "`n[GIT STATUS - Backend]" -ForegroundColor Green
$backendPath = "F:\tovplay\tovplay-backend"
if (Test-Path "$backendPath\.git") {
    Push-Location $backendPath
    $branch = git branch --show-current 2>$null
    $status = git status --short 2>$null
    $ahead = git rev-list --count "@{u}..HEAD" 2>$null
    $behind = git rev-list --count "HEAD..@{u}" 2>$null
    Pop-Location
    Write-Host "  Branch: $branch" -ForegroundColor White
    if ($ahead) { Write-Host "  Commits ahead: $ahead" -ForegroundColor Yellow }
    if ($behind) { Write-Host "  Commits behind: $behind" -ForegroundColor Yellow }
    if ($status) {
        Write-Host "  Changed files:" -ForegroundColor Yellow
        Write-Host $status -ForegroundColor Gray
    } else {
        Write-Host "  Working tree clean" -ForegroundColor Green
    }
}

Write-Host "`n[GIT STATUS - Frontend]" -ForegroundColor Green
$frontendPath = "F:\tovplay\tovplay-frontend"
if (Test-Path "$frontendPath\.git") {
    Push-Location $frontendPath
    $branch = git branch --show-current 2>$null
    $status = git status --short 2>$null
    $ahead = git rev-list --count "@{u}..HEAD" 2>$null
    $behind = git rev-list --count "HEAD..@{u}" 2>$null
    Pop-Location
    Write-Host "  Branch: $branch" -ForegroundColor White
    if ($ahead) { Write-Host "  Commits ahead: $ahead" -ForegroundColor Yellow }
    if ($behind) { Write-Host "  Commits behind: $behind" -ForegroundColor Yellow }
    if ($status) {
        Write-Host "  Changed files:" -ForegroundColor Yellow
        Write-Host $status -ForegroundColor Gray
    } else {
        Write-Host "  Working tree clean" -ForegroundColor Green
    }
}

Write-Host "`n[NODE_MODULES STATUS]" -ForegroundColor Green
$nmPath = "F:\tovplay\tovplay-frontend\node_modules"
if (Test-Path $nmPath) {
    $nmSize = [math]::Round((Get-ChildItem -Path $nmPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
    Write-Host "  [OK] node_modules exists ($nmSize MB)" -ForegroundColor Green
} else {
    Write-Host "  [MISSING] node_modules - run: npm install" -ForegroundColor Red
}

Write-Host "`n[PYTHON VENV STATUS]" -ForegroundColor Green
$venvPath = "F:\tovplay\tovplay-backend\venv"
if (Test-Path $venvPath) {
    Write-Host "  [OK] venv exists" -ForegroundColor Green
} else {
    Write-Host "  [MISSING] venv - run: python -m venv venv" -ForegroundColor Red
}

Write-Host "`n[LOCAL PROCESSES ON DEV PORTS]" -ForegroundColor Green
$devPorts = @(3000, 5001, 5000, 8000)
foreach ($port in $devPorts) {
    $proc = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($proc) {
        $pid = $proc.OwningProcess | Select-Object -First 1
        $procName = (Get-Process -Id $pid -ErrorAction SilentlyContinue).ProcessName
        Write-Host "  Port $port : $procName (PID: $pid)" -ForegroundColor Yellow
    } else {
        Write-Host "  Port $port : Not in use" -ForegroundColor Gray
    }
}

# =============================================================================
# SECTION 6: CI/CD STATUS (from debug.ps1)
# =============================================================================
Write-Host "`n##############################################################################" -ForegroundColor Cyan
Write-Host "#                   SECTION 6: CI/CD STATUS                                  #" -ForegroundColor Cyan
Write-Host "##############################################################################" -ForegroundColor Cyan

Write-Host "`n[GITHUB WORKFLOWS]" -ForegroundColor Green
$workflowPaths = @(
    "F:\tovplay\tovplay-backend\.github\workflows",
    "F:\tovplay\tovplay-frontend\.github\workflows"
)
foreach ($wp in $workflowPaths) {
    if (Test-Path $wp) {
        Write-Host "  Workflows in $wp :" -ForegroundColor White
        $workflows = Get-ChildItem -Path $wp -Filter "*.yml"
        foreach ($wf in $workflows) {
            Write-Host "    - $($wf.Name)" -ForegroundColor Gray
        }
    }
}

Write-Host "`n[DOCKER HUB IMAGES]" -ForegroundColor Green
Write-Host "  Backend:  tovtech/tovplaybackend:latest" -ForegroundColor White
Write-Host "  Frontend: tovtech/tovplayfrontend:latest" -ForegroundColor White
Write-Host "  Check: https://hub.docker.com/r/tovtech" -ForegroundColor DarkGray

# =============================================================================
# SECTION 7: TECH STACK SUMMARY (from architecture.ps1/d.ps1)
# =============================================================================
Write-Host "`n##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 7: TECH STACK SUMMARY                            #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[TECH STACK]" -ForegroundColor Green
Write-Host "Backend:    Python 3.11, Flask, PostgreSQL, Socket.IO, Gunicorn" -ForegroundColor White
Write-Host "Frontend:   React 18, Vite 6, Redux Toolkit, Tailwind, shadcn/ui" -ForegroundColor White
Write-Host "DevOps:     Docker multi-stage, GitHub Actions, Cloudflare" -ForegroundColor White
Write-Host "Monitoring: Prometheus, Grafana, Loki, Node Exporter, cAdvisor" -ForegroundColor White
Write-Host "Database:   PostgreSQL 17.4 + pgBouncer (connection pooling)" -ForegroundColor White

Write-Host "`n[LOCAL DEVELOPMENT COMMANDS]" -ForegroundColor Green
Write-Host "Start Dev:  cd F:\tovplay; .\tovrun.ps1" -ForegroundColor Cyan
Write-Host "Backend:    http://localhost:5001" -ForegroundColor White
Write-Host "Frontend:   http://localhost:3000" -ForegroundColor White

# =============================================================================
# SECTION 8: QUICK FIX COMMANDS (from debug.ps1)
# =============================================================================
Write-Host "`n##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 8: QUICK FIX COMMANDS                            #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[RESTART PRODUCTION BACKEND]" -ForegroundColor Green
Write-Host "  wsl -d ubuntu bash -c `"sshpass -p '<REDACTED_TOVTECH_SSH_PASSWORD>' ssh -tt $stagingUser@$stagingHost 'sshpass -p $prodPass ssh admin@$prodHost `\"docker restart tovplay-backend`\"'`"" -ForegroundColor Cyan

Write-Host "`n[RESTART PRODUCTION NGINX]" -ForegroundColor Green
Write-Host "  wsl -d ubuntu bash -c `"sshpass -p '<REDACTED_TOVTECH_SSH_PASSWORD>' ssh -tt $stagingUser@$stagingHost 'sshpass -p $prodPass ssh admin@$prodHost `\"sudo systemctl restart nginx`\"'`"" -ForegroundColor Cyan

Write-Host "`n[REBUILD & DEPLOY BACKEND]" -ForegroundColor Green
Write-Host "  1. cd F:\tovplay\tovplay-backend" -ForegroundColor Cyan
Write-Host "  2. docker build -t tovtech/tovplaybackend:latest ." -ForegroundColor Cyan
Write-Host "  3. docker push tovtech/tovplaybackend:latest" -ForegroundColor Cyan
Write-Host "  4. SSH to production and: docker pull && docker-compose up -d" -ForegroundColor Cyan

Write-Host "`n[KILL STUCK DB CONNECTIONS]" -ForegroundColor Green
Write-Host "  wsl -d ubuntu bash -c `"PAGER=cat PGPASSWORD=<REDACTED_TOVTECH_DB_PASSWORD> psql -h $dbHost -U '$dbUser' -d $dbName -c 'SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = ''idle'' AND query_start < now() - interval ''1 hour'''`"" -ForegroundColor Cyan

Write-Host "`n[CLEAR DOCKER LOGS (PRODUCTION)]" -ForegroundColor Green
Write-Host "  Run on prod: sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log" -ForegroundColor Cyan

Write-Host "`n[VACUUM ANALYZE ALL TABLES]" -ForegroundColor Green
Write-Host "  wsl -d ubuntu bash -c `"PAGER=cat PGPASSWORD=<REDACTED_TOVTECH_DB_PASSWORD> psql -h $dbHost -U '$dbUser' -d $dbName -c 'VACUUM ANALYZE'`"" -ForegroundColor Cyan

Write-Host "`n[DATABASE BACKUP]" -ForegroundColor Green
Write-Host "  `$f=`"F:\backup\tovplay\DB\tovplay_`$(Get-Date -Format 'yyyyMMdd_HHmmss').sql`"; wsl -d ubuntu bash -c 'PGPASSWORD=`"$dbPass`" pg_dump -h $dbHost -U `"$dbUser`" -d $dbName' > `$f" -ForegroundColor Cyan

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "                         SUMMARY                                      " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Full infrastructure dump completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host "Servers checked: Production, Staging, Database" -ForegroundColor Green
Write-Host "Review any RED or ERROR messages above for issues." -ForegroundColor Yellow
Write-Host "" -ForegroundColor White
Write-Host "Links:" -ForegroundColor Cyan
Write-Host "  Production: $($creds.urls.production)" -ForegroundColor White
Write-Host "  Staging:    $($creds.urls.staging)" -ForegroundColor White
Write-Host "  Errors:     $($creds.urls.logs)" -ForegroundColor White
Write-Host "  Grafana:    $($creds.urls.grafana)" -ForegroundColor White
Write-Host "  Prometheus: $($creds.urls.prometheus)" -ForegroundColor White
Write-Host "  DB Viewer:  $($creds.urls.db_viewer)" -ForegroundColor White
