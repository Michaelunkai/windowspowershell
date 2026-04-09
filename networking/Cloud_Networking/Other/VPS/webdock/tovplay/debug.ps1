# debug.ps1 - TovPlay COMPREHENSIVE DEBUG & TROUBLESHOOTING SCRIPT
# Outputs EVERYTHING a DevOps engineer needs to debug/fix issues
# Real-time data from: Production, Staging, Database, Local
# ALWAYS reads credentials from credentials.json - NEVER hardcoded
# PowerShell v5 compatible
# Usage: .\debug.ps1

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
# Base64 encoding helper for psql queries with quoted table names - pipe to bash for $() expansion
function Run-DB-Query($query) {
    $queryBytes = [System.Text.Encoding]::UTF8.GetBytes($query)
    $queryBase64 = [Convert]::ToBase64String($queryBytes)
    $bashCmd = "PAGER=cat PGPASSWORD='$dbPass' psql -h $dbHost -U '$dbUser' -d $dbName -c `"`$(echo $queryBase64 | base64 -d)`""
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

# =============================================================================
# HEADER
# =============================================================================
Write-Host "======================================================================" -ForegroundColor Red
Write-Host "         TOVPLAY - DEBUG & TROUBLESHOOTING DASHBOARD                  " -ForegroundColor Red
Write-Host "         Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')         " -ForegroundColor Red
Write-Host "  Credentials from: $credFile" -ForegroundColor DarkGray
Write-Host "======================================================================" -ForegroundColor Red

# =============================================================================
# SECTION 1: ENDPOINT HEALTH CHECK
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 1: ENDPOINT HEALTH CHECK                         #" -ForegroundColor Yellow
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
# SECTION 2: PRODUCTION SERVER DEBUG
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Magenta
Write-Host "#                   SECTION 2: PRODUCTION SERVER DEBUG                       #" -ForegroundColor Magenta
Write-Host "##############################################################################" -ForegroundColor Magenta

Write-Host "`n[PRODUCTION SSH TEST]" -ForegroundColor Green
$prodSSH = Run-Prod-Cmd "echo 'SSH OK'"
if ($prodSSH -match "SSH OK") {
    Write-Host "  [OK] SSH connection via staging jump host working" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] SSH connection failed - check staging or production server" -ForegroundColor Red
}

Write-Host "`n[SYSTEM LOAD]" -ForegroundColor Green
Run-Prod-Cmd "uptime"

Write-Host "`n[MEMORY USAGE]" -ForegroundColor Green
Run-Prod-Cmd "free -h"

Write-Host "`n[DISK USAGE]" -ForegroundColor Green
Run-Prod-Cmd "df -h"

Write-Host "`n[DISK INODES]" -ForegroundColor Green
Run-Prod-Cmd "df -i | head -5"

Write-Host "`n[TOP 10 DIRECTORIES BY SIZE]" -ForegroundColor Green
Run-Prod-Cmd "du -hx / 2>/dev/null | sort -rh | head -10"

Write-Host "`n[DOCKER CONTAINERS]" -ForegroundColor Green
Run-Prod-Cmd "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

Write-Host "`n[DOCKER CONTAINER HEALTH]" -ForegroundColor Green
Run-Prod-Cmd "docker inspect --format='{{.Name}}: {{.State.Health.Status}}' \$(docker ps -q) 2>/dev/null || echo 'No health checks configured'"

Write-Host "`n[DOCKER RESOURCE USAGE]" -ForegroundColor Green
Run-Prod-Cmd "timeout 10 docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}'"

Write-Host "`n[BACKEND CONTAINER LOGS (last 50)]" -ForegroundColor Green
Run-Prod-Cmd "docker logs tovplay-backend --tail 50 2>&1 | tail -50"

Write-Host "`n[BACKEND CONTAINER ERRORS (last 30)]" -ForegroundColor Green
Run-Prod-Cmd "docker logs tovplay-backend 2>&1 | grep -iE 'error|exception|traceback|failed|critical' | tail -30"

Write-Host "`n[NGINX ERROR LOG (last 30)]" -ForegroundColor Green
Run-Prod-Cmd "sudo tail -30 /var/log/nginx/error.log 2>/dev/null || echo 'No nginx error log'"

Write-Host "`n[NGINX ACCESS LOG (last 20 4xx/5xx)]" -ForegroundColor Green
Run-Prod-Cmd "sudo grep -E ' [45][0-9]{2} ' /var/log/nginx/access.log 2>/dev/null | tail -20 || echo 'No error responses'"

Write-Host "`n[NGINX STATUS]" -ForegroundColor Green
Run-Prod-Cmd "sudo nginx -t 2>&1"
Run-Prod-Cmd "sudo systemctl status nginx --no-pager | head -15"

Write-Host "`n[DOCKER SERVICE STATUS]" -ForegroundColor Green
Run-Prod-Cmd "sudo systemctl status docker --no-pager | head -15"

Write-Host "`n[SYSLOG ERRORS (last 30)]" -ForegroundColor Green
Run-Prod-Cmd "sudo grep -iE 'error|fail|critical' /var/log/syslog 2>/dev/null | tail -30 || echo 'No syslog errors'"

Write-Host "`n[AUTH LOG (last 20 failures)]" -ForegroundColor Green
Run-Prod-Cmd "sudo grep -iE 'fail|invalid|denied' /var/log/auth.log 2>/dev/null | tail -20 || echo 'No auth failures'"

Write-Host "`n[OOM KILLER EVENTS]" -ForegroundColor Green
Run-Prod-Cmd "sudo dmesg | grep -i 'oom\|killed' | tail -10 || echo 'No OOM events'"

Write-Host "`n[LISTENING PORTS]" -ForegroundColor Green
Run-Prod-Cmd "sudo ss -tlnp"

Write-Host "`n[ACTIVE CONNECTIONS BY STATE]" -ForegroundColor Green
Run-Prod-Cmd "ss -s"

Write-Host "`n[FIREWALL STATUS]" -ForegroundColor Green
Run-Prod-Cmd "sudo ufw status verbose 2>/dev/null || echo 'UFW not installed'"

Write-Host "`n[SSL CERTIFICATE EXPIRY]" -ForegroundColor Green
Run-Prod-Cmd "sudo certbot certificates 2>/dev/null | grep -A3 'Domains\|Expiry' || echo 'Check manually'"

Write-Host "`n[CRON JOBS]" -ForegroundColor Green
Run-Prod-Cmd "crontab -l 2>/dev/null || echo 'No user crontab'"
Run-Prod-Cmd "sudo crontab -l 2>/dev/null || echo 'No root crontab'"

Write-Host "`n[FAILED SYSTEMD SERVICES]" -ForegroundColor Green
Run-Prod-Cmd "systemctl --failed 2>/dev/null || echo 'No failed services'"

# =============================================================================
# SECTION 3: STAGING SERVER DEBUG
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Blue
Write-Host "#                   SECTION 3: STAGING SERVER DEBUG                          #" -ForegroundColor Blue
Write-Host "##############################################################################" -ForegroundColor Blue

Write-Host "`n[STAGING SSH TEST]" -ForegroundColor Green
$stagSSH = Run-Staging-Cmd "echo 'SSH OK'"
if ($stagSSH -match "SSH OK") {
    Write-Host "  [OK] SSH connection working" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] SSH connection failed" -ForegroundColor Red
}

Write-Host "`n[SYSTEM LOAD]" -ForegroundColor Green
Run-Staging-Cmd "uptime"

Write-Host "`n[MEMORY USAGE]" -ForegroundColor Green
Run-Staging-Cmd "free -h"

Write-Host "`n[DISK USAGE]" -ForegroundColor Green
Run-Staging-Cmd "df -h"

Write-Host "`n[TOP 10 DIRECTORIES BY SIZE]" -ForegroundColor Green
Run-Staging-Cmd "du -hx / 2>/dev/null | sort -rh | head -10"

Write-Host "`n[DOCKER CONTAINERS]" -ForegroundColor Green
Run-Staging-Cmd "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null"

Write-Host "`n[DOCKER RESOURCE USAGE]" -ForegroundColor Green
Run-Staging-Cmd "timeout 10 docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' 2>/dev/null"

Write-Host "`n[STAGING BACKEND LOGS (last 30)]" -ForegroundColor Green
Run-Staging-Cmd "docker logs tovplay-backend-staging --tail 30 2>&1 | tail -30"

Write-Host "`n[STAGING BACKEND ERRORS (last 20)]" -ForegroundColor Green
Run-Staging-Cmd "docker logs tovplay-backend-staging 2>&1 | grep -iE 'error|exception|traceback|failed' | tail -20"

Write-Host "`n[NGINX ERROR LOG (last 20)]" -ForegroundColor Green
Run-Staging-Cmd "sudo tail -20 /var/log/nginx/error.log 2>/dev/null || echo 'No nginx error log'"

Write-Host "`n[NGINX STATUS]" -ForegroundColor Green
Run-Staging-Cmd "sudo nginx -t 2>&1"
Run-Staging-Cmd "sudo systemctl status nginx --no-pager | head -15"

Write-Host "`n[LISTENING PORTS]" -ForegroundColor Green
Run-Staging-Cmd "sudo ss -tlnp"

Write-Host "`n[FAILED SYSTEMD SERVICES]" -ForegroundColor Green
Run-Staging-Cmd "systemctl --failed 2>/dev/null || echo 'No failed services'"

# =============================================================================
# SECTION 4: DATABASE DEBUG
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Red
Write-Host "#                   SECTION 4: DATABASE DEBUG                                #" -ForegroundColor Red
Write-Host "##############################################################################" -ForegroundColor Red

Write-Host "`n[DATABASE CONNECTIVITY]" -ForegroundColor Green
$dbOpen = Test-Port $dbHost $dbPort
if ($dbOpen) {
    Write-Host "  [OK] PostgreSQL port $dbPort is open" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] PostgreSQL port $dbPort is closed" -ForegroundColor Red
}

Write-Host "`n[DATABASE VERSION]" -ForegroundColor Green
Run-DB-Query "SELECT version()"

Write-Host "`n[DATABASE SIZE]" -ForegroundColor Green
Run-DB-Query "SELECT pg_size_pretty(pg_database_size(current_database())) as size"

Write-Host "`n[ACTIVE CONNECTIONS]" -ForegroundColor Green
Run-DB-Query "SELECT pid, usename, client_addr, state, query_start, wait_event_type FROM pg_stat_activity WHERE datname = current_database() ORDER BY query_start DESC NULLS LAST"

Write-Host "`n[CONNECTIONS BY STATE]" -ForegroundColor Green
Run-DB-Query "SELECT state, count(*) FROM pg_stat_activity WHERE datname = current_database() GROUP BY state ORDER BY count DESC"

Write-Host "`n[CONNECTIONS BY IP]" -ForegroundColor Green
Run-DB-Query "SELECT client_addr, count(*) as conn FROM pg_stat_activity WHERE datname = current_database() AND client_addr IS NOT NULL GROUP BY client_addr ORDER BY conn DESC"

Write-Host "`n[LONG RUNNING QUERIES (>5s)]" -ForegroundColor Green
Run-DB-Query "SELECT pid, usename, state, EXTRACT(EPOCH FROM (now() - query_start))::int as seconds, substring(query, 1, 80) as query FROM pg_stat_activity WHERE datname = current_database() AND state != 'idle' AND query_start < now() - interval '5 seconds' ORDER BY query_start"

Write-Host "`n[BLOCKED QUERIES]" -ForegroundColor Green
Run-DB-Query "SELECT blocked.pid AS blocked_pid, substring(blocked.query, 1, 50) AS blocked_query, blocking.pid AS blocking_pid FROM pg_stat_activity blocked JOIN pg_locks blocked_locks ON blocked.pid = blocked_locks.pid JOIN pg_locks blocking_locks ON blocked_locks.locktype = blocking_locks.locktype AND blocked.pid != blocking_locks.pid JOIN pg_stat_activity blocking ON blocking_locks.pid = blocking.pid WHERE NOT blocked_locks.granted"

Write-Host "`n[IDLE IN TRANSACTION (potential issues)]" -ForegroundColor Green
Run-DB-Query "SELECT pid, usename, client_addr, EXTRACT(EPOCH FROM (now() - query_start))::int as seconds FROM pg_stat_activity WHERE state = 'idle in transaction' ORDER BY query_start"

Write-Host "`n[DEADLOCKS]" -ForegroundColor Green
Run-DB-Query "SELECT deadlocks FROM pg_stat_database WHERE datname = current_database()"

Write-Host "`n[TABLE BLOAT (dead tuples)]" -ForegroundColor Green
Run-DB-Query "SELECT relname, n_live_tup, n_dead_tup, round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 2) as dead_pct FROM pg_stat_user_tables WHERE n_dead_tup > 100 ORDER BY n_dead_tup DESC LIMIT 10"

Write-Host "`n[CACHE HIT RATIO]" -ForegroundColor Green
Run-DB-Query "SELECT round(100.0 * sum(blks_hit) / nullif(sum(blks_hit) + sum(blks_read), 0), 2) as cache_hit_pct FROM pg_stat_database WHERE datname = current_database()"

Write-Host "`n[TABLE ROW COUNTS]" -ForegroundColor Green
Run-DB-Query "SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC"

Write-Host "`n[RECENT ERRORS - Connection Audit]" -ForegroundColor Green
Run-DB-Query 'SELECT * FROM public."ConnectionAuditLog" ORDER BY connection_time DESC LIMIT 5'

Write-Host "`n[RECENT ERRORS - Delete Audit]" -ForegroundColor Green
Run-DB-Query 'SELECT * FROM public."DeleteAuditLog" ORDER BY deleted_at DESC LIMIT 5'

# =============================================================================
# SECTION 5: LOCAL DEVELOPMENT DEBUG
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Green
Write-Host "#                   SECTION 5: LOCAL DEVELOPMENT DEBUG                       #" -ForegroundColor Green
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

Write-Host "`n[BACKEND .ENV VALIDATION]" -ForegroundColor Green
$backendEnv = "F:\tovplay\tovplay-backend\.env"
if (Test-Path $backendEnv) {
    $requiredVars = @("DATABASE_URL", "SECRET_KEY", "FLASK_ENV", "DISCORD_CLIENT_ID", "SMTP_SERVER")
    $envContent = Get-Content $backendEnv -Raw
    foreach ($var in $requiredVars) {
        if ($envContent -match "^$var=") {
            Write-Host "  [OK] $var is set" -ForegroundColor Green
        } else {
            Write-Host "  [MISSING] $var" -ForegroundColor Red
        }
    }
}

Write-Host "`n[FRONTEND .ENV VALIDATION]" -ForegroundColor Green
$frontendEnv = "F:\tovplay\tovplay-frontend\.env"
if (Test-Path $frontendEnv) {
    $requiredVars = @("VITE_API_BASE_URL", "VITE_DISCORD_CLIENT_ID")
    $envContent = Get-Content $frontendEnv -Raw
    foreach ($var in $requiredVars) {
        if ($envContent -match "^$var=") {
            Write-Host "  [OK] $var is set" -ForegroundColor Green
        } else {
            Write-Host "  [MISSING] $var" -ForegroundColor Red
        }
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
$ports = @(3000, 5001, 5000, 8000)
foreach ($port in $ports) {
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
# SECTION 6: GITHUB ACTIONS / CI-CD
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Cyan
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
# SECTION 7: QUICK FIX COMMANDS
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "##############################################################################" -ForegroundColor Yellow
Write-Host "#                   SECTION 7: QUICK FIX COMMANDS                            #" -ForegroundColor Yellow
Write-Host "##############################################################################" -ForegroundColor Yellow

Write-Host "`n[RESTART PRODUCTION BACKEND]" -ForegroundColor Green
Write-Host "  wsl -d ubuntu bash -c `"sshpass -p '$stagingPass' ssh -tt $stagingUser@$stagingHost 'sshpass -p $prodPass ssh admin@$prodHost `\"docker restart tovplay-backend`\"'`"" -ForegroundColor Cyan

Write-Host "`n[RESTART PRODUCTION NGINX]" -ForegroundColor Green
Write-Host "  wsl -d ubuntu bash -c `"sshpass -p '$stagingPass' ssh -tt $stagingUser@$stagingHost 'sshpass -p $prodPass ssh admin@$prodHost `\"sudo systemctl restart nginx`\"'`"" -ForegroundColor Cyan

Write-Host "`n[REBUILD & DEPLOY BACKEND]" -ForegroundColor Green
Write-Host "  1. cd F:\tovplay\tovplay-backend" -ForegroundColor Cyan
Write-Host "  2. docker build -t tovtech/tovplaybackend:latest ." -ForegroundColor Cyan
Write-Host "  3. docker push tovtech/tovplaybackend:latest" -ForegroundColor Cyan
Write-Host "  4. SSH to production and: docker pull && docker-compose up -d" -ForegroundColor Cyan

Write-Host "`n[KILL STUCK DB CONNECTIONS]" -ForegroundColor Green
Write-Host "  wsl -d ubuntu bash -c `"PAGER=cat PGPASSWORD='$dbPass' psql -h $dbHost -U '$dbUser' -d $dbName -c 'SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = ''idle'' AND query_start < now() - interval ''1 hour'''`"" -ForegroundColor Cyan

Write-Host "`n[CLEAR DOCKER LOGS (PRODUCTION)]" -ForegroundColor Green
Write-Host "  Run on prod: sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log" -ForegroundColor Cyan

Write-Host "`n[VACUUM ANALYZE ALL TABLES]" -ForegroundColor Green
Write-Host "  wsl -d ubuntu bash -c `"PAGER=cat PGPASSWORD='$dbPass' psql -h $dbHost -U '$dbUser' -d $dbName -c 'VACUUM ANALYZE'`"" -ForegroundColor Cyan

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n======================================================================" -ForegroundColor Red
Write-Host "                      DEBUG DASHBOARD COMPLETE                        " -ForegroundColor Red
Write-Host "======================================================================" -ForegroundColor Red
Write-Host "Script completed at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
Write-Host "Look for [FAIL] or Red text for issues that need attention" -ForegroundColor Yellow
Write-Host "Use SECTION 7 commands for quick fixes" -ForegroundColor DarkGray
