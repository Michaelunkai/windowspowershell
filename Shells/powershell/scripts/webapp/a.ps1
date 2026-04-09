<#
.SYNOPSIS
    WebApp - Run any app and expose it with a global URL
.USAGE
    a.ps1 <command> [-Port 3456]
    a.ps1 "node server.js" -Port 3000
    a.ps1 "python -m http.server 8080" -Port 8080
    a.ps1 "cd F:\myproject; npm start" -Port 3000
    a.ps1 -Stop              Kill all webapp instances
    a.ps1 -List              Show running instances
#>
param(
    [Parameter(Position=0)][string]$Command,
    [int]$Port = 0,
    [switch]$Stop,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$CF_DIR    = "$env:LOCALAPPDATA\cloudflared"
$CF_EXE    = "$CF_DIR\cloudflared.exe"
$STATE_DIR = "$env:TEMP\webapp"
$LOG_DIR   = "$STATE_DIR\logs"

function Write-Step([string]$msg) { Write-Host "[WebApp] $msg" -ForegroundColor Cyan }
function Write-OK([string]$msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err([string]$msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Get-RunningInstances {
    if (!(Test-Path "$STATE_DIR\*.json")) { return @() }
    $instances = @()
    Get-ChildItem "$STATE_DIR\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        $data = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $appAlive = $false; $cfAlive = $false
        try { $appAlive = !!(Get-Process -Id $data.app_pid -ErrorAction SilentlyContinue) } catch {}
        try { $cfAlive  = !!(Get-Process -Id $data.cf_pid -ErrorAction SilentlyContinue) } catch {}
        $data | Add-Member -NotePropertyName 'app_alive' -NotePropertyValue $appAlive -Force
        $data | Add-Member -NotePropertyName 'cf_alive'  -NotePropertyValue $cfAlive -Force
        $data | Add-Member -NotePropertyName 'state_file' -NotePropertyValue $_.FullName -Force
        $instances += $data
    }
    return $instances
}

# ============================================
# -List
# ============================================
if ($List) {
    $instances = Get-RunningInstances
    if ($instances.Count -eq 0) { Write-Host "No WebApp instances running." -ForegroundColor Yellow; exit 0 }
    Write-Host "`n=== WEBAPP INSTANCES ===" -ForegroundColor Cyan
    foreach ($inst in $instances) {
        $alive = $inst.app_alive -and $inst.cf_alive
        $color = if ($alive) { "Green" } else { "Red" }
        $tag   = if ($alive) { "RUNNING" } else { "DEAD" }
        Write-Host "  [$tag] " -NoNewline -ForegroundColor $color
        Write-Host "$($inst.command)" -ForegroundColor White
        Write-Host "         Port: $($inst.port) -> $($inst.url)" -ForegroundColor Yellow
        Write-Host "         App PID: $($inst.app_pid) | CF PID: $($inst.cf_pid) | Started: $($inst.started)" -ForegroundColor DarkGray
    }
    Write-Host ""
    # Clean dead
    $instances | Where-Object { !$_.app_alive -and !$_.cf_alive } | ForEach-Object {
        Remove-Item $_.state_file -Force -ErrorAction SilentlyContinue
    }
    exit 0
}

# ============================================
# -Stop
# ============================================
if ($Stop) {
    $instances = Get-RunningInstances
    $killed = 0
    foreach ($inst in $instances) {
        try { Stop-Process -Id $inst.app_pid -Force -ErrorAction SilentlyContinue; $killed++ } catch {}
        try { Stop-Process -Id $inst.cf_pid  -Force -ErrorAction SilentlyContinue; $killed++ } catch {}
        Remove-Item $inst.state_file -Force -ErrorAction SilentlyContinue
    }
    Write-OK "Stopped $killed processes."
    exit 0
}

# ============================================
# VALIDATE
# ============================================
if (!$Command) {
    Write-Host @"

  WEBAPP - Run any app with a global URL
  =======================================
  Usage:
    a.ps1 "<command>" -Port <port>
    a.ps1 -Stop
    a.ps1 -List

  Examples:
    a.ps1 "node server.js" -Port 3000
    a.ps1 "python -m http.server 8080" -Port 8080
    a.ps1 "cd F:\myproject; npm start" -Port 3000
    a.ps1 "dotnet run" -Port 5000
    a.ps1 "F:\myapp\server.exe" -Port 9090

"@ -ForegroundColor Yellow
    exit 0
}

if ($Port -eq 0) {
    # Try to auto-detect port from command
    if ($Command -match '[\s:](\d{4,5})') {
        $Port = [int]$matches[1]
        Write-Step "Auto-detected port: $Port"
    } else {
        Write-Err "Could not auto-detect port. Use -Port <number>"
        Write-Host "  Example: webapp `"node server.js`" -Port 3000" -ForegroundColor Yellow
        exit 1
    }
}

# ============================================
# INSTALL CLOUDFLARED
# ============================================
Write-Host ""
Write-Host "  ===============================" -ForegroundColor Magenta
Write-Host "  WEBAPP - App with Global URL" -ForegroundColor Magenta
Write-Host "  ===============================" -ForegroundColor Magenta
Write-Host ""

New-Item -ItemType Directory -Path $STATE_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $LOG_DIR    -Force | Out-Null

$cfCheck = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cfCheck) { $CF_EXE = $cfCheck.Source }
if (!(Test-Path $CF_EXE)) {
    Write-Step "Installing cloudflared..."
    New-Item -ItemType Directory -Path $CF_DIR -Force | Out-Null
    Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile $CF_EXE -UseBasicParsing
    Write-OK "cloudflared installed"
} else { Write-OK "cloudflared ready" }

# ============================================
# START THE APP
# ============================================
$id = Get-Date -Format "HHmmss"
$appLogFile = "$LOG_DIR\app_${id}.log"

Write-Step "Starting app: $Command"
Write-Step "Expected port: $Port"

$appProc = Start-Process -FilePath "powershell.exe" `
    -ArgumentList @("-NoProfile", "-Command", $Command) `
    -WindowStyle Hidden -PassThru -RedirectStandardError $appLogFile

if (!$appProc -or $appProc.HasExited) {
    Write-Err "Failed to start app!"
    if (Test-Path $appLogFile) { Get-Content $appLogFile | Write-Host -ForegroundColor Red }
    exit 1
}
Write-OK "App started (PID: $($appProc.Id))"

# Wait for the app's port to be ready
Write-Step "Waiting for app on port $Port..."
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    try { $tcp = [System.Net.Sockets.TcpClient]::new("127.0.0.1", $Port); $tcp.Close(); $ready = $true; break } catch {}
}
if (!$ready) {
    Write-Err "App not responding on port $Port after 30s"
    Write-Host "  The app may need more time, or the port is wrong." -ForegroundColor Yellow
    Write-Host "  Check log: $appLogFile" -ForegroundColor DarkGray
    # Don't kill — maybe it's still starting. Continue with tunnel anyway.
}
if ($ready) { Write-OK "App is listening on port $Port" }

# ============================================
# START CLOUDFLARED TUNNEL
# ============================================
$cfLogFile = "$LOG_DIR\cf_${id}.log"
Write-Step "Creating tunnel to localhost:$Port..."
$cfProc = Start-Process -FilePath $CF_EXE `
    -ArgumentList @("tunnel", "--url", "http://localhost:$Port") `
    -WindowStyle Hidden -PassThru -RedirectStandardError $cfLogFile

if (!$cfProc -or $cfProc.HasExited) {
    Write-Err "Failed to start cloudflared!"
    exit 1
}

# Get URL
Write-Step "Waiting for public URL..."
$publicUrl = $null
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-Path $cfLogFile) {
        $log = Get-Content $cfLogFile -Raw -ErrorAction SilentlyContinue
        if ($log -match '(https://[a-zA-Z0-9-]+\.trycloudflare\.com)') {
            $publicUrl = $matches[1]
            break
        }
    }
}

# Save state
$stateFile = "$STATE_DIR\app_${id}.json"
@{
    command  = $Command
    port     = $Port
    url      = $(if ($publicUrl) { $publicUrl } else { "http://localhost:$Port" })
    app_pid  = $appProc.Id
    cf_pid   = $cfProc.Id
    started  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
} | ConvertTo-Json | Set-Content $stateFile -Encoding UTF8

if ($publicUrl) { $publicUrl | Set-Clipboard }

Write-Host ""
Write-Host "  =============================================" -ForegroundColor Green
Write-Host "  APP IS LIVE!" -ForegroundColor Green
Write-Host "  =============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Command: $Command" -ForegroundColor White
Write-Host "  Local:   http://localhost:$Port" -ForegroundColor White
if ($publicUrl) {
    Write-Host ""
    Write-Host "  GLOBAL URL (copied to clipboard):" -ForegroundColor Yellow
    Write-Host "  $publicUrl" -ForegroundColor Cyan
} else {
    Write-Host "  Global URL failed - check $cfLogFile" -ForegroundColor Red
}
Write-Host ""
Write-Host "  List:  webapp -List" -ForegroundColor DarkGray
Write-Host "  Stop:  webapp -Stop" -ForegroundColor DarkGray
Write-Host "  =============================================" -ForegroundColor Green
Write-Host ""
