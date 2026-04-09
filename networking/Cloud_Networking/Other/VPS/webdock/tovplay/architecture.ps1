# architecture.ps1 - Real-time Architecture Scanner for TovPlay
# 4 Sections: LOCAL (Backend/Frontend), PRODUCTION, STAGING, DATABASE
# ALWAYS reads credentials from credentials.json - NEVER hardcoded

param(
    [switch]$NoColor,
    [switch]$Brief
)

$ErrorActionPreference = 'SilentlyContinue'

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
function Write-C($text, $color) {
    if ($NoColor) { Write-Host $text } else { Write-Host $text -ForegroundColor $color }
}

function Get-TreeStructure($path, $depth = 0, $maxDepth = 3) {
    if ($depth -ge $maxDepth) { return @() }
    $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^(node_modules|__pycache__|\.git|\.venv|venv|dist|build|\.next|coverage|logs)$' } | Sort-Object { -not $_.PSIsContainer }, Name
    $result = @()
    foreach ($item in $items) {
        $indent = "      " + ("  " * $depth)
        $prefix = if ($item.PSIsContainer) { "[D] " } else { "    " }
        $size = if (-not $item.PSIsContainer) { " ({0:N0}KB)" -f ($item.Length/1KB) } else { "" }
        $result += "$indent$prefix$($item.FullName)$size"
        if ($item.PSIsContainer) {
            $result += Get-TreeStructure $item.FullName ($depth + 1) $maxDepth
        }
    }
    return $result
}

function Get-DirStats($path) {
    $files = Get-ChildItem -Path $path -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.DirectoryName -notmatch '(node_modules|__pycache__|\.git|\.venv|dist|build)' }
    $size = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
    $count = $files.Count
    return @{ Files = $count; SizeMB = [math]::Round($size, 1) }
}

function Test-Port($hostName, $port, $timeout = 2000) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $result = $tcp.BeginConnect($hostName, $port, $null, $null)
        $wait = $result.AsyncWaitHandle.WaitOne($timeout, $false)
        if ($wait -and $tcp.Connected) { $tcp.Close(); return $true }
        $tcp.Close(); return $false
    } catch { return $false }
}

function Get-UrlStatus($url, $timeout = 5) {
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec $timeout -UseBasicParsing -ErrorAction Stop
        return $response.StatusCode
    } catch { return "ERR" }
}

function Run-SSH-Staging($cmd) {
    # Uses base64 to avoid quote escaping issues
    $escapedPass = $stagingPass -replace "'", "'\''"
    $cmdBytes = [System.Text.Encoding]::UTF8.GetBytes($cmd)
    $cmdBase64 = [Convert]::ToBase64String($cmdBytes)
    $bashScript = "sshpass -p '$escapedPass' ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $stagingUser@$stagingHost 'echo $cmdBase64 | base64 -d | bash' 2>/dev/null"
    try {
        $result = wsl -d ubuntu bash -c $bashScript 2>$null
        return $result
    } catch {
        return $null
    }
}

function Run-SSH-Production($cmd) {
    # Production SSH via staging jump host - uses base64 to avoid quote hell
    $escapedStagingPass = $stagingPass -replace "'", "'\''"
    $escapedProdPass = $prodPass -replace "'", "'\''"
    $cmdBytes = [System.Text.Encoding]::UTF8.GetBytes($cmd)
    $cmdBase64 = [Convert]::ToBase64String($cmdBytes)
    $innerCmd = "echo $cmdBase64 | base64 -d | bash"
    $escapedInnerCmd = $innerCmd -replace "'", "'\''"
    $bashScript = "sshpass -p '$escapedStagingPass' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $stagingUser@$stagingHost 'sshpass -p '\''$escapedProdPass'\'' ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR admin@$prodHost '\''$escapedInnerCmd'\''' 2>/dev/null"
    try {
        $result = wsl -d ubuntu bash -c $bashScript 2>$null
        return $result
    } catch {
        return $null
    }
}

# SSH status check functions (separate for staging and production)
function Get-SSHStatus-Staging {
    $result = Run-SSH-Staging "echo OK"
    return ($result -and $result.Trim() -eq "OK")
}

function Get-SSHStatus-Production {
    $result = Run-SSH-Production "echo OK"
    return ($result -and $result.Trim() -eq "OK")
}

# Staging server functions
function Get-ServerContainers-Staging {
    $result = Run-SSH-Staging 'docker ps -a --format "{{.Names}}|{{.Status}}|{{.Ports}}"'
    if ($result) { return $result -split "`n" | Where-Object { $_.Trim() } }
    return @()
}

function Get-ServerDisk-Staging {
    $result = Run-SSH-Staging "df -h / | tail -1"
    if ($result) {
        $parts = $result -split '\s+'
        if ($parts.Count -ge 5) { return "$($parts[2])/$($parts[1]) ($($parts[4]))" }
    }
    return "N/A"
}

function Get-ServerRam-Staging {
    $result = Run-SSH-Staging "free -h | grep Mem"
    if ($result) {
        $parts = $result -split '\s+'
        if ($parts.Count -ge 4) { return "$($parts[2])/$($parts[1])" }
    }
    return "N/A"
}

function Get-ServerFiles-Staging($path) {
    $result = Run-SSH-Staging "ls -la $path 2>/dev/null"
    if ($result) { return $result -split "`n" | Where-Object { $_ -and $_ -notmatch '^total' } }
    return @()
}

function Get-DockerImages-Staging {
    $result = Run-SSH-Staging 'docker images --format "{{.Repository}}:{{.Tag}}|{{.Size}}"'
    if ($result) { return $result -split "`n" | Where-Object { $_.Trim() } }
    return @()
}

function Get-CronJobs-Staging {
    $result = Run-SSH-Staging 'crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$"'
    if ($result) { return $result -split "`n" | Where-Object { $_.Trim() } }
    return @()
}

# Production server functions (via staging jump host)
function Get-ServerContainers-Production {
    $result = Run-SSH-Production 'docker ps -a --format "{{.Names}}|{{.Status}}|{{.Ports}}"'
    if ($result) { return $result -split "`n" | Where-Object { $_.Trim() } }
    return @()
}

function Get-ServerDisk-Production {
    $result = Run-SSH-Production "df -h / | tail -1"
    if ($result) {
        $parts = $result -split '\s+'
        if ($parts.Count -ge 5) { return "$($parts[2])/$($parts[1]) ($($parts[4]))" }
    }
    return "N/A"
}

function Get-ServerRam-Production {
    $result = Run-SSH-Production "free -h | grep Mem"
    if ($result) {
        $parts = $result -split '\s+'
        if ($parts.Count -ge 4) { return "$($parts[2])/$($parts[1])" }
    }
    return "N/A"
}

function Get-ServerFiles-Production($path) {
    $result = Run-SSH-Production "ls -la $path 2>/dev/null"
    if ($result) { return $result -split "`n" | Where-Object { $_ -and $_ -notmatch '^total' } }
    return @()
}

function Get-DockerImages-Production {
    $result = Run-SSH-Production 'docker images --format "{{.Repository}}:{{.Tag}}|{{.Size}}"'
    if ($result) { return $result -split "`n" | Where-Object { $_.Trim() } }
    return @()
}

function Get-CronJobs-Production {
    $result = Run-SSH-Production 'crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$"'
    if ($result) { return $result -split "`n" | Where-Object { $_.Trim() } }
    return @()
}

function Run-DB($query) {
    # Uses base64 encoding for queries with special characters - pipe to bash for $() expansion
    $queryBytes = [System.Text.Encoding]::UTF8.GetBytes($query)
    $queryBase64 = [Convert]::ToBase64String($queryBytes)
    $bashCmd = "PAGER=cat PGPASSWORD='$dbPass' psql -h $dbHost -U '$dbUser' -d $dbName -t -c `"`$(echo $queryBase64 | base64 -d)`""
    try {
        $result = $bashCmd | wsl -d ubuntu bash 2>$null
        if ($result) { return $result.Trim() }
    } catch {}
    return "N/A"
}

function Get-DBConnections { Run-DB "SELECT count(*) FROM pg_stat_activity" }
function Get-DBTables { Run-DB "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" }
function Get-DBSize { Run-DB "SELECT pg_size_pretty(pg_database_size('$dbName'))" }

function Get-DBTableList {
    $result = Run-DB "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename"
    if ($result -and $result -ne "N/A") { return $result -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() } }
    return @()
}

# =============================================================================
# HEADER
# =============================================================================
Clear-Host
$dateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-C "==============================================================================" Cyan
Write-C "                    TOVPLAY ARCHITECTURE SCANNER v3.1                          " White
Write-C "                         $dateStr                            " DarkGray
Write-C "  Credentials loaded from: $credFile" DarkGray
Write-C "==============================================================================" Cyan
Write-Host ""

# =============================================================================
# SECTION 1: LOCAL DEVELOPMENT
# =============================================================================
Write-C "##############################################################################" Yellow
Write-C "#                      SECTION 1: LOCAL DEVELOPMENT                          #" Yellow
Write-C "##############################################################################" Yellow
Write-Host ""

# --- Backend ---
$backendPath = "F:\tovplay\tovplay-backend"
if (Test-Path $backendPath) {
    $stats = Get-DirStats $backendPath
    Write-C "  +-- BACKEND ---------------------------------------------------------------" Green
    Write-C "    Root Path:   $backendPath" Cyan
    Write-C "    Source Path: $backendPath\src" Cyan
    Write-C "    Stats:       $($stats.Files) files | $($stats.SizeMB) MB" DarkGray
    Write-Host ""

    Write-C "    Key Files:" White
    $keyFiles = @("requirements.txt", "Dockerfile", "docker-compose.yml", ".env.template", "README.md", "run.py")
    foreach ($f in $keyFiles) {
        $fullPath = "$backendPath\$f"
        $exists = if (Test-Path $fullPath) { "[OK]" } else { "[--]" }
        $color = if ($exists -eq "[OK]") { "Green" } else { "Red" }
        Write-C "      $exists $fullPath" $color
    }
    Write-Host ""

    Write-C "    Source Structure ($backendPath\src):" White
    $structure = Get-TreeStructure "$backendPath\src" 0 2
    foreach ($line in $structure) { Write-C "$line" Gray }
    Write-Host ""
}

# --- Frontend ---
$frontendPath = "F:\tovplay\tovplay-frontend"
if (Test-Path $frontendPath) {
    $stats = Get-DirStats $frontendPath
    Write-C "  +-- FRONTEND --------------------------------------------------------------" Green
    Write-C "    Root Path:   $frontendPath" Cyan
    Write-C "    Source Path: $frontendPath\src" Cyan
    Write-C "    Stats:       $($stats.Files) files | $($stats.SizeMB) MB" DarkGray
    Write-Host ""

    Write-C "    Key Files:" White
    $keyFiles = @("package.json", "Dockerfile", "vite.config.js", ".env.template", "index.html")
    foreach ($f in $keyFiles) {
        $fullPath = "$frontendPath\$f"
        $exists = if (Test-Path $fullPath) { "[OK]" } else { "[--]" }
        $color = if ($exists -eq "[OK]") { "Green" } else { "Red" }
        Write-C "      $exists $fullPath" $color
    }
    Write-Host ""

    Write-C "    Source Structure ($frontendPath\src):" White
    $structure = Get-TreeStructure "$frontendPath\src" 0 2
    foreach ($line in $structure) { Write-C "$line" Gray }
    Write-Host ""
}

Write-C "  +-- LOCAL DEV COMMANDS ----------------------------------------------------" DarkGray
Write-C "    Start Dev:   cd F:\tovplay; .\tovrun.ps1" DarkGray
Write-C "    Backend:     http://localhost:5001" DarkGray
Write-C "    Frontend:    http://localhost:3000" DarkGray
Write-Host ""

# =============================================================================
# SECTION 2: PRODUCTION SERVER
# =============================================================================
Write-C "##############################################################################" Magenta
Write-C "#                      SECTION 2: PRODUCTION SERVER                          #" Magenta
Write-C "##############################################################################" Magenta
Write-Host ""

Write-C "  +-- CONNECTION INFO -------------------------------------------------------" Cyan
Write-C "    IP Address:  $prodHost" White
Write-C "    SSH User:    $prodUser" White
Write-C "    SSH via:     staging jump host ($stagingHost)" DarkGray
Write-C "    SSH Command: wsl -d ubuntu bash -c `"sshpass -p '$stagingPass' ssh -tt $stagingUser@$stagingHost 'sshpass -p $prodPass ssh admin@$prodHost'`"" DarkGray
Write-Host ""

$prodSSH = Get-SSHStatus-Production
$prodColor = if ($prodSSH) { "Green" } else { "Red" }
$prodStatus = if ($prodSSH) { "CONNECTED" } else { "UNREACHABLE" }
Write-C "  +-- SSH STATUS: [$prodStatus] ----------------------------------------------" $prodColor

if ($prodSSH) {
    $disk = Get-ServerDisk-Production
    $ram = Get-ServerRam-Production
    Write-C "    Disk Usage:  $disk" Gray
    Write-C "    RAM Usage:   $ram" Gray
    Write-Host ""

    Write-C "  +-- PATHS & DIRECTORIES --------------------------------------------------" Cyan
    Write-C "    App Root:        /home/admin/tovplay" White
    Write-C "    Frontend Root:   /var/www/tovplay" White
    Write-C "    Nginx Config:    /etc/nginx/sites-enabled/tovplay.conf" White
    Write-C "    SSL Certs:       /etc/letsencrypt/live/app.tovplay.org/" White
    Write-C "    Docker Compose:  /home/admin/tovplay/docker-compose.yml -> docker-compose.production.yml" White
    Write-C "    Environment:     /home/admin/tovplay/.env" White
    Write-C "    Logs:            /home/admin/tovplay/logs/" White
    Write-C "    pgBouncer:       /home/admin/tovplay/pgbouncer/" White
    Write-C "    Monitoring:      /home/admin/tovplay/monitoring/" White
    Write-C "    Grafana:         /home/admin/tovplay/grafana/" White
    Write-Host ""

    Write-C "  +-- NGINX CONFIGURATION --------------------------------------------------" Cyan
    Write-C "    Config File:     /etc/nginx/sites-enabled/tovplay.conf" White
    Write-C "    Server Name:     app.tovplay.org, tovplay.vps.webdock.cloud" White
    Write-C "    SSL:             /etc/letsencrypt/live/app.tovplay.org/fullchain.pem" White
    Write-C "    Frontend Root:   /var/www/tovplay" White
    Write-C "    Proxy Routes:" White
    Write-C "      /api/           -> http://127.0.0.1:8000/api/ (Backend)" DarkGray
    Write-C "      /api/database/  -> http://127.0.0.1:7777/api/database/ (DB Viewer)" DarkGray
    Write-C "      /logs/api/      -> http://127.0.0.1:7778/api/ (Error Dashboard)" DarkGray
    Write-C "      /database-viewer-> http://127.0.0.1:7777/database-viewer" DarkGray
    Write-C "      /logs/          -> http://127.0.0.1:7778/ (Logs UI)" DarkGray
    Write-C "      /               -> React SPA (try_files)" DarkGray
    Write-Host ""

    Write-C "  +-- DOCKER CONTAINERS (LIVE) ---------------------------------------------" Cyan
    $containers = Get-ServerContainers-Production
    foreach ($c in $containers) {
        $parts = $c -split '\|'
        $name = $parts[0]
        $status = if ($parts.Count -gt 1) { $parts[1] } else { "unknown" }
        $ports = if ($parts.Count -gt 2) { $parts[2] } else { "" }
        $statusColor = if ($status -match "Up") { "Green" } else { "Red" }
        $portsStr = if ($ports) { " | Ports: $ports" } else { "" }
        Write-C "    * $name" $statusColor
        Write-C "      Status: $status$portsStr" DarkGray
    }
    Write-Host ""

    Write-C "  +-- DOCKER IMAGES (LIVE) -------------------------------------------------" Cyan
    $images = Get-DockerImages-Production
    foreach ($img in $images | Select-Object -First 15) {
        $parts = $img -split '\|'
        $imgName = $parts[0]
        $imgSize = if ($parts.Count -gt 1) { $parts[1] } else { "" }
        Write-C "    $imgName ($imgSize)" Gray
    }
    if ($images.Count -gt 15) { Write-C "    ... and $($images.Count - 15) more images" DarkGray }
    Write-Host ""

    Write-C "  +-- CRON JOBS (LIVE) -----------------------------------------------------" Cyan
    $crons = Get-CronJobs-Production
    if ($crons.Count -eq 0) { Write-C "    No cron jobs found" DarkGray }
    foreach ($cron in $crons) { Write-C "    $cron" Gray }
    Write-Host ""

    Write-C "  +-- SERVICES STATUS (LIVE) -----------------------------------------------" Cyan
    $dockerSvc = Run-SSH-Production "systemctl is-active docker"
    $nginxSvc = Run-SSH-Production "systemctl is-active nginx"
    Write-C "    docker: $($dockerSvc.Trim()), nginx: $($nginxSvc.Trim())" Gray
    Write-Host ""

    Write-C "  +-- PROJECT FILES (/home/admin/tovplay/) ---------------------------------" Cyan
    $files = Get-ServerFiles-Production "/home/admin/tovplay/"
    foreach ($f in $files | Select-Object -First 25) {
        Write-C "    $f" Gray
    }
    Write-Host ""
}

Write-C "  +-- ENDPOINTS (LIVE) ------------------------------------------------------" Cyan
$endpoints = @(
    @{ Name = "Frontend"; URL = $creds.urls.production },
    @{ Name = "Backend API"; URL = "$($creds.urls.production)/api/health" },
    @{ Name = "Logs Dashboard"; URL = $creds.urls.logs },
    @{ Name = "Grafana"; URL = $creds.urls.grafana },
    @{ Name = "Prometheus"; URL = $creds.urls.prometheus }
)
foreach ($ep in $endpoints) {
    $status = Get-UrlStatus $ep.URL
    $statusColor = if ($status -eq 200) { "Green" } else { "Red" }
    $statusText = if ($status -eq 200) { "OK 200" } else { "-- $status" }
    Write-C "    [$statusText] $($ep.Name) -> $($ep.URL)" $statusColor
}
Write-Host ""

# =============================================================================
# SECTION 3: STAGING SERVER
# =============================================================================
Write-C "##############################################################################" Blue
Write-C "#                       SECTION 3: STAGING SERVER                            #" Blue
Write-C "##############################################################################" Blue
Write-Host ""

Write-C "  +-- CONNECTION INFO -------------------------------------------------------" Cyan
Write-C "    IP Address:  $stagingHost" White
Write-C "    SSH User:    $stagingUser" White
Write-C "    SSH Command: wsl -d ubuntu bash -c `"sshpass -p '$stagingPass' ssh $stagingUser@$stagingHost`"" DarkGray
Write-Host ""

$stagingSSH = Get-SSHStatus-Staging
$stagingColor = if ($stagingSSH) { "Green" } else { "Red" }
$stagingStatus = if ($stagingSSH) { "CONNECTED" } else { "UNREACHABLE" }
Write-C "  +-- SSH STATUS: [$stagingStatus] --------------------------------------------" $stagingColor

if ($stagingSSH) {
    $disk = Get-ServerDisk-Staging
    $ram = Get-ServerRam-Staging
    Write-C "    Disk Usage:  $disk" Gray
    Write-C "    RAM Usage:   $ram" Gray
    Write-Host ""

    Write-C "  +-- PATHS & DIRECTORIES --------------------------------------------------" Cyan
    Write-C "    App Root:        /home/admin/tovplay" White
    Write-C "    Frontend Root:   /var/www/tovplay-staging" White
    Write-C "    Nginx Config:    /etc/nginx/sites-enabled/staging.tovplay.org" White
    Write-C "                     -> /etc/nginx/sites-available/staging.tovplay.org" DarkGray
    Write-C "    SSL Certs:       /etc/nginx/ssl/staging.tovplay.org.crt" White
    Write-C "                     /etc/nginx/ssl/staging.tovplay.org.key" White
    Write-C "    Docker Compose:  /home/admin/tovplay/docker-compose.yml -> docker-compose.staging.yml" White
    Write-C "    Environment:     /home/admin/tovplay/.env.staging" White
    Write-C "    Prometheus:      /home/admin/tovplay/prometheus/" White
    Write-C "    Grafana:         /home/admin/tovplay/grafana/" White
    Write-Host ""

    Write-C "  +-- NGINX CONFIGURATION --------------------------------------------------" Cyan
    Write-C "    Config File:     /etc/nginx/sites-enabled/staging.tovplay.org" White
    Write-C "    Server Name:     staging.tovplay.org" White
    Write-C "    SSL:             /etc/nginx/ssl/staging.tovplay.org.crt" White
    Write-C "    Frontend Root:   /var/www/tovplay-staging" White
    Write-C "    Proxy Routes:" White
    Write-C "      /api/          -> http://localhost:8001 (Backend)" DarkGray
    Write-C "      /nginx_status  -> stub_status (metrics)" DarkGray
    Write-C "      /              -> React SPA (try_files)" DarkGray
    Write-Host ""

    Write-C "  +-- DOCKER CONTAINERS (LIVE) ---------------------------------------------" Cyan
    $containers = Get-ServerContainers-Staging
    foreach ($c in $containers) {
        $parts = $c -split '\|'
        $name = $parts[0]
        $status = if ($parts.Count -gt 1) { $parts[1] } else { "unknown" }
        $ports = if ($parts.Count -gt 2) { $parts[2] } else { "" }
        $statusColor = if ($status -match "Up") { "Green" } else { "Red" }
        $portsStr = if ($ports) { " | Ports: $ports" } else { "" }
        Write-C "    * $name" $statusColor
        Write-C "      Status: $status$portsStr" DarkGray
    }
    Write-Host ""

    Write-C "  +-- DOCKER IMAGES (LIVE) -------------------------------------------------" Cyan
    $images = Get-DockerImages-Staging
    foreach ($img in $images | Select-Object -First 10) {
        $parts = $img -split '\|'
        $imgName = $parts[0]
        $imgSize = if ($parts.Count -gt 1) { $parts[1] } else { "" }
        Write-C "    $imgName ($imgSize)" Gray
    }
    if ($images.Count -gt 10) { Write-C "    ... and $($images.Count - 10) more images" DarkGray }
    Write-Host ""

    Write-C "  +-- CRON JOBS (LIVE) -----------------------------------------------------" Cyan
    $crons = Get-CronJobs-Staging
    if ($crons.Count -eq 0) { Write-C "    No cron jobs found" DarkGray }
    foreach ($cron in $crons) { Write-C "    $cron" Gray }
    Write-Host ""

    Write-C "  +-- SERVICES STATUS (LIVE) -----------------------------------------------" Cyan
    $dockerSvc = Run-SSH-Staging "systemctl is-active docker"
    $nginxSvc = Run-SSH-Staging "systemctl is-active nginx"
    Write-C "    docker: $($dockerSvc.Trim()), nginx: $($nginxSvc.Trim())" Gray
    Write-Host ""

    Write-C "  +-- PROJECT FILES (/home/admin/tovplay/) ---------------------------------" Cyan
    $files = Get-ServerFiles-Staging "/home/admin/tovplay/"
    foreach ($f in $files | Select-Object -First 20) {
        Write-C "    $f" Gray
    }
    Write-Host ""
}

Write-C "  +-- ENDPOINTS (LIVE) ------------------------------------------------------" Cyan
$stagingUrl = Get-UrlStatus $creds.urls.staging
$stagingUrlColor = if ($stagingUrl -eq 200) { "Green" } else { "Red" }
$stagingUrlText = if ($stagingUrl -eq 200) { "OK 200" } else { "-- $stagingUrl" }
Write-C "    [$stagingUrlText] Staging App -> $($creds.urls.staging)" $stagingUrlColor
Write-Host ""

# =============================================================================
# SECTION 4: DATABASE SERVER
# =============================================================================
Write-C "##############################################################################" Red
Write-C "#                       SECTION 4: DATABASE SERVER                           #" Red
Write-C "##############################################################################" Red
Write-Host ""

Write-C "  +-- CONNECTION INFO -------------------------------------------------------" Cyan
Write-C "    Host:        $dbHost" White
Write-C "    Port:        $dbPort" White
Write-C "    Database:    $dbName" White
Write-C "    User:        $dbUser" White
Write-C "    Schema:      public" White
Write-C "    Version:     PostgreSQL 17.4 (Debian)" White
Write-C "    Connect:     PGPASSWORD='$dbPass' psql -h $dbHost -U '$dbUser' -d $dbName" DarkGray
Write-Host ""

$dbPortOpen = Test-Port $dbHost $dbPort
$dbColor = if ($dbPortOpen) { "Green" } else { "Red" }
$dbStatus = if ($dbPortOpen) { "OPEN" } else { "CLOSED" }
Write-C "  +-- PORT STATUS: [$dbStatus] ------------------------------------------------" $dbColor

if ($dbPortOpen) {
    $conns = Get-DBConnections
    $tables = Get-DBTables
    $dbSize = Get-DBSize
    Write-C "    Active Connections: $conns" Gray
    Write-C "    Total Tables:       $tables" Gray
    Write-C "    Database Size:      $dbSize" Gray
    Write-Host ""

    Write-C "  +-- CONNECTION POOLING (pgBouncer) ---------------------------------------" Cyan
    Write-C "    Production pgBouncer: $($prodHost):6432" White
    Write-C "    Staging pgBouncer:    $($stagingHost):6432" White
    Write-C "    Pool Mode:            transaction" White
    Write-C "    Max DB Connections:   50" White
    Write-Host ""

    Write-C "  +-- TABLES (public schema) -----------------------------------------------" Cyan
    $tableList = Get-DBTableList
    $tableCount = 0
    $tableRow = "    "
    foreach ($t in $tableList) {
        $tableRow += "$t, "
        $tableCount++
        if ($tableCount % 4 -eq 0) {
            Write-C $tableRow.TrimEnd(", ") Gray
            $tableRow = "    "
        }
    }
    if ($tableRow.Trim()) {
        Write-C $tableRow.TrimEnd(", ") Gray
    }
    Write-Host ""
}

# =============================================================================
# FOOTER
# =============================================================================
if (-not $Brief) {
    Write-C "##############################################################################" Yellow
    Write-C "#                           TECH STACK SUMMARY                               #" Yellow
    Write-C "##############################################################################" Yellow
    Write-Host ""
    Write-C "  Backend:   Python 3.11, Flask, PostgreSQL, Socket.IO, Gunicorn" White
    Write-C "  Frontend:  React 18, Vite 6, Redux Toolkit, Tailwind, shadcn/ui" White
    Write-C "  DevOps:    Docker multi-stage, GitHub Actions, Cloudflare" White
    Write-C "  Monitor:   Prometheus, Grafana, Loki, Node Exporter, cAdvisor" White
    Write-C "  Database:  PostgreSQL 17.4 + pgBouncer (connection pooling)" White
    Write-Host ""
}

$timeStr = Get-Date -Format "HH:mm:ss"
Write-C "==============================================================================" Cyan
Write-C "  Scan completed at $timeStr | Options: -Brief (skip tech) | -NoColor" DarkGray
Write-C "==============================================================================" Cyan
