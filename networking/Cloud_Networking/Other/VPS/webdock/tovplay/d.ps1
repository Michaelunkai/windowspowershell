# d.ps1 - TovPlay REFERENCE DATA Script
# ALWAYS reads credentials from credentials.json - NEVER hardcoded
# Usage: .\d.ps1
# Run time: ~5s (local file reads only, no SSH)
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

# =============================================================================
# ENV FILES
# =============================================================================
$backendEnv = "F:\tovplay\tovplay-backend\.env"
$frontendEnv = "F:\tovplay\tovplay-frontend\.env"

# Load backend .env
$envVars = @{}
if (Test-Path $backendEnv) {
    Get-Content $backendEnv | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $envVars[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
}

# =============================================================================
# HEADER
# =============================================================================
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         TOVPLAY - REFERENCE DATA (REAL-TIME FROM SOURCES)           " -ForegroundColor Cyan
Write-Host "         Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')         " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# =============================================================================
# SOURCE FILES
# =============================================================================
Write-Host "`n## DATA SOURCES" -ForegroundColor Yellow
Write-Host "credentials.json: $credFile" -ForegroundColor DarkGray
if (Test-Path $credFile) {
    Write-Host "  Last modified: $(Get-Item $credFile | Select-Object -ExpandProperty LastWriteTime)" -ForegroundColor Green
}
Write-Host "backend .env:     $backendEnv" -ForegroundColor DarkGray
if (Test-Path $backendEnv) {
    Write-Host "  Last modified: $(Get-Item $backendEnv | Select-Object -ExpandProperty LastWriteTime)" -ForegroundColor Green
}
Write-Host "frontend .env:    $frontendEnv" -ForegroundColor DarkGray
if (Test-Path $frontendEnv) {
    Write-Host "  Last modified: $(Get-Item $frontendEnv | Select-Object -ExpandProperty LastWriteTime)" -ForegroundColor Green
}

# =============================================================================
# INFRASTRUCTURE SCRIPTS
# =============================================================================
Write-Host "`n## INFRASTRUCTURE SCRIPTS" -ForegroundColor Yellow
Write-Host "Run these for real-time server/database data:" -ForegroundColor White
Write-Host "  architecture.ps1  - Full architecture scan (~30s)" -ForegroundColor Gray
Write-Host "  a.ps1             - Complete infrastructure dump (~60s)" -ForegroundColor Gray
Write-Host "  b.ps1             - Quick status check (~10s)" -ForegroundColor Gray
Write-Host "  d.ps1             - This script - reference data (~5s)" -ForegroundColor Gray
Write-Host "Location: F:\study\cloud\vps\webdock\tovplay\" -ForegroundColor DarkGray

# =============================================================================
# CREDENTIALS - FROM credentials.json (REAL-TIME)
# =============================================================================
Write-Host "`n## CREDENTIALS (from credentials.json)" -ForegroundColor Yellow

Write-Host "`n[SERVERS]" -ForegroundColor Green
$prod = $creds.servers.production
$stag = $creds.servers.staging
$db = $creds.servers.database
Write-Host "Production: $($prod.host) | $($prod.user) / $($prod.password)" -ForegroundColor White
Write-Host "Staging:    $($stag.host) | $($stag.user) / $($stag.password)" -ForegroundColor White
Write-Host "Database:   $($db.host):$($db.port) | $($db.user) / $($db.password) | $($db.database)" -ForegroundColor White

Write-Host "`n[SSH COMMANDS]" -ForegroundColor Green
Write-Host "# Staging (direct connection)" -ForegroundColor DarkGray
Write-Host "wsl -d ubuntu bash -c 'sshpass -p `"$($stag.password)`" ssh -o StrictHostKeyChecking=no $($stag.user)@$($stag.host)'" -ForegroundColor Cyan
Write-Host "# Production (via staging jump host)" -ForegroundColor DarkGray
Write-Host "wsl -d ubuntu bash -c 'sshpass -p `"$($stag.password)`" ssh -tt $($stag.user)@$($stag.host) `"sshpass -p $($prod.password) ssh admin@$($prod.host)`"'" -ForegroundColor Cyan
Write-Host "# Database (use PAGER=cat to avoid hanging)" -ForegroundColor DarkGray
Write-Host "wsl -d ubuntu bash -c 'PAGER=cat PGPASSWORD=`"$($db.password)`" psql -h $($db.host) -U `"$($db.user)`" -d $($db.database)'" -ForegroundColor Cyan

Write-Host "`n[AWS S3]" -ForegroundColor Green
$aws = $creds.aws
Write-Host "console: $($aws.console)" -ForegroundColor White
Write-Host "user: $($aws.user) | pass: $($aws.password)" -ForegroundColor White
Write-Host "access: $($aws.access_key)" -ForegroundColor White
Write-Host "secret: $($aws.secret_key)" -ForegroundColor White

Write-Host "`n[DOCKER HUB]" -ForegroundColor Green
$docker = $creds.docker_hub
Write-Host "user: $($docker.user)" -ForegroundColor White
Write-Host "pass: $($docker.password)" -ForegroundColor White
Write-Host "# Docker Hub login command:" -ForegroundColor DarkGray
Write-Host "docker login -u $($docker.user) -p `"$($docker.password)`"" -ForegroundColor Cyan

Write-Host "`n[AWS CLI COMMANDS]" -ForegroundColor Green
Write-Host "# Configure AWS CLI:" -ForegroundColor DarkGray
Write-Host "aws configure set aws_access_key_id $($aws.access_key)" -ForegroundColor Cyan
Write-Host "aws configure set aws_secret_access_key $($aws.secret_key)" -ForegroundColor Cyan
Write-Host "aws configure set region eu-north-1" -ForegroundColor Cyan
Write-Host "# S3 bucket commands:" -ForegroundColor DarkGray
Write-Host "aws s3 ls  # List buckets" -ForegroundColor Cyan
Write-Host "aws s3 ls s3://tovplay-uploads/  # List bucket contents" -ForegroundColor Cyan

# =============================================================================
# DISCORD & EMAIL - FROM .env (real-time)
# =============================================================================
Write-Host "`n## DISCORD & EMAIL (from backend .env)" -ForegroundColor Yellow

Write-Host "`n[EMAIL SMTP]" -ForegroundColor Green
Write-Host "server: $($envVars['SMTP_SERVER']):$($envVars['SMTP_PORT'])" -ForegroundColor White
Write-Host "sender: $($envVars['EMAIL_SENDER'])" -ForegroundColor White
Write-Host "pass: $($envVars['EMAIL_PASSWORD'])" -ForegroundColor White

Write-Host "`n[DISCORD BOT]" -ForegroundColor Green
Write-Host "client_id: $($envVars['DISCORD_CLIENT_ID'])" -ForegroundColor White
Write-Host "client_secret: $($envVars['CLIENT_SECRET'])" -ForegroundColor White
Write-Host "token: $($envVars['DISCORD_TOKEN'])" -ForegroundColor White
Write-Host "guild_id: $($envVars['DISCORD_GUILD_ID'])" -ForegroundColor White
Write-Host "invite: $($envVars['DISCORD_INVITE_LINK'])" -ForegroundColor White

# =============================================================================
# TEST USERS - FROM credentials.json
# =============================================================================
Write-Host "`n[TEST USERS] email / username / password" -ForegroundColor Green
foreach ($user in $creds.test_users) {
    Write-Host "$($user.email) / $($user.username) / $($user.password)" -ForegroundColor White
}

# =============================================================================
# URLS - FROM credentials.json
# =============================================================================
Write-Host "`n## REPOS & URLS (from credentials.json)" -ForegroundColor Yellow

Write-Host "`n[GITHUB]" -ForegroundColor Green
Write-Host "Frontend: $($creds.urls.github_frontend)" -ForegroundColor White
Write-Host "Backend:  $($creds.urls.github_backend)" -ForegroundColor White

Write-Host "`n[APP URLS]" -ForegroundColor Green
Write-Host "Production:  $($creds.urls.production)" -ForegroundColor White
Write-Host "Staging:     $($creds.urls.staging)" -ForegroundColor White
Write-Host "Logs:        $($creds.urls.logs)" -ForegroundColor White
Write-Host "Grafana:     $($creds.urls.grafana)" -ForegroundColor White
Write-Host "Prometheus:  $($creds.urls.prometheus)" -ForegroundColor White
Write-Host "DB Viewer:   $($creds.urls.db_viewer)" -ForegroundColor White

Write-Host "`n[TOOLS]" -ForegroundColor Green
Write-Host "Jira: $($creds.urls.jira)" -ForegroundColor White

Write-Host "`n[TEAM]" -ForegroundColor Green
foreach ($member in $creds.team) {
    if ($member.email) {
        Write-Host "$($member.name) ($($member.email))" -ForegroundColor White
    } else {
        Write-Host "$($member.name)" -ForegroundColor White
    }
}

# =============================================================================
# DATABASE COMMANDS (built from real credentials)
# =============================================================================
Write-Host "`n## DATABASE COMMANDS" -ForegroundColor Yellow

Write-Host "`n[BACKUP]" -ForegroundColor Green
Write-Host "`$f=`"F:\backup\tovplay\DB\tovplay_`$(Get-Date -Format 'yyyyMMdd_HHmmss').sql`"; wsl -d ubuntu bash -c 'PGPASSWORD=`"$($db.password)`" pg_dump -h $($db.host) -U `"$($db.user)`" -d $($db.database)' > `$f" -ForegroundColor Cyan

Write-Host "`n[RESTORE FROM LATEST]" -ForegroundColor Green
Write-Host "`$b=(gci F:\backup\tovplay\DB\*.sql|sort LastWriteTime -Desc)[0].FullName; gc `$b|wsl -d ubuntu bash -c 'PGPASSWORD=`"$($db.password)`" psql -h $($db.host) -U `"$($db.user)`" -d $($db.database)'" -ForegroundColor Cyan

Write-Host "`n[QUICK QUERIES]" -ForegroundColor Green
Write-Host "# Tables list" -ForegroundColor DarkGray
Write-Host "wsl -d ubuntu bash -c 'PAGER=cat PGPASSWORD=`"$($db.password)`" psql -h $($db.host) -U `"$($db.user)`" -d $($db.database) -c `"SELECT tablename FROM pg_tables WHERE schemaname=''public'' ORDER BY tablename`"'" -ForegroundColor Cyan
Write-Host "# Row counts" -ForegroundColor DarkGray
Write-Host "wsl -d ubuntu bash -c 'PAGER=cat PGPASSWORD=`"$($db.password)`" psql -h $($db.host) -U `"$($db.user)`" -d $($db.database) -c `"SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC`"'" -ForegroundColor Cyan

# =============================================================================
# TECH STACK (from package.json / requirements.txt if they exist)
# =============================================================================
Write-Host "`n## TECH STACK" -ForegroundColor Yellow

# Try to get versions from actual files
$backendReqs = "F:\tovplay\tovplay-backend\requirements.txt"
$frontendPkg = "F:\tovplay\tovplay-frontend\package.json"

Write-Host "Backend:    Python 3.11, Flask, PostgreSQL, Socket.IO, Gunicorn" -ForegroundColor White

if (Test-Path $frontendPkg) {
    try {
        $pkg = Get-Content $frontendPkg -Raw | ConvertFrom-Json
        $reactVer = $pkg.dependencies.react -replace '\^', ''
        $viteVer = $pkg.devDependencies.vite -replace '\^', ''
        Write-Host "Frontend:   React $reactVer, Vite $viteVer, Redux Toolkit, Tailwind, shadcn/ui" -ForegroundColor White
    } catch {
        Write-Host "Frontend:   React 18, Vite 6, Redux Toolkit, Tailwind, shadcn/ui" -ForegroundColor White
    }
} else {
    Write-Host "Frontend:   React 18, Vite 6, Redux Toolkit, Tailwind, shadcn/ui" -ForegroundColor White
}

Write-Host "DevOps:     Docker multi-stage, GitHub Actions, Cloudflare" -ForegroundColor White
Write-Host "Monitoring: Prometheus, Grafana, Loki, Node Exporter, cAdvisor" -ForegroundColor White
Write-Host "Database:   PostgreSQL 17.4 + pgBouncer (connection pooling)" -ForegroundColor White

# =============================================================================
# LOCAL DEVELOPMENT
# =============================================================================
Write-Host "`n## LOCAL DEVELOPMENT" -ForegroundColor Yellow
Write-Host "Start:    cd F:\tovplay; .\tovrun.ps1" -ForegroundColor Cyan
Write-Host "Backend:  http://localhost:5001" -ForegroundColor White
Write-Host "Frontend: http://localhost:3000" -ForegroundColor White

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "Script completed at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
Write-Host "Data sources: credentials.json, backend .env, package.json" -ForegroundColor DarkGray
Write-Host "For real-time server data run: a.ps1, b.ps1, or architecture.ps1" -ForegroundColor DarkGray
Write-Host "======================================================================" -ForegroundColor Cyan
