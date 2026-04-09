<#
.SYNOPSIS
    WebTerm - Your actual PowerShell terminal in a browser, globally accessible
.USAGE
    a.ps1              Start terminal with global URL
    a.ps1 -Stop        Kill it
    a.ps1 -Status      Show URL and status
#>
param(
    [switch]$Stop,
    [switch]$Status,
    [int]$Port = 7681
)

$ErrorActionPreference = 'Stop'
$TTYD_DIR  = "$env:LOCALAPPDATA\ttyd"
$TTYD_EXE  = "$TTYD_DIR\ttyd.exe"
$CF_DIR    = "$env:LOCALAPPDATA\cloudflared"
$CF_EXE    = "$CF_DIR\cloudflared.exe"
$STATE_FILE = "$env:TEMP\webterm_state.json"
$LOG_DIR   = "$env:TEMP\webterm"

function Write-Step([string]$msg) { Write-Host "[WebTerm] $msg" -ForegroundColor Cyan }
function Write-OK([string]$msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err([string]$msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Get-State {
    if (!(Test-Path $STATE_FILE)) { return $null }
    $s = Get-Content $STATE_FILE -Raw | ConvertFrom-Json
    $s | Add-Member -NotePropertyName 'ttyd_alive' -NotePropertyValue $false -Force
    $s | Add-Member -NotePropertyName 'cf_alive'   -NotePropertyValue $false -Force
    try { $s.ttyd_alive = !!(Get-Process -Id $s.ttyd_pid -ErrorAction SilentlyContinue) } catch {}
    try { $s.cf_alive   = !!(Get-Process -Id $s.cf_pid -ErrorAction SilentlyContinue) } catch {}
    return $s
}

# ============================================
# -Status
# ============================================
if ($Status) {
    $s = Get-State
    if (!$s) { Write-Host "WebTerm is not running." -ForegroundColor Yellow; exit 0 }
    $alive = $s.ttyd_alive -and $s.cf_alive
    $color = if ($alive) { "Green" } else { "Red" }
    $tag   = if ($alive) { "RUNNING" } else { "DEAD" }
    Write-Host ""
    Write-Host "  WebTerm: [$tag]" -ForegroundColor $color
    Write-Host "  URL:     $($s.url)" -ForegroundColor Cyan
    Write-Host "  Local:   http://localhost:$($s.port)" -ForegroundColor White
    Write-Host "  ttyd:    PID $($s.ttyd_pid) $(if($s.ttyd_alive){'alive'}else{'dead'})" -ForegroundColor DarkGray
    Write-Host "  cf:      PID $($s.cf_pid) $(if($s.cf_alive){'alive'}else{'dead'})" -ForegroundColor DarkGray
    Write-Host "  Started: $($s.started)" -ForegroundColor DarkGray
    Write-Host ""
    if (!$alive) { Remove-Item $STATE_FILE -Force -ErrorAction SilentlyContinue }
    exit 0
}

# ============================================
# -Stop
# ============================================
if ($Stop) {
    $s = Get-State
    if ($s) {
        try { Stop-Process -Id $s.ttyd_pid -Force -ErrorAction SilentlyContinue } catch {}
        try { Stop-Process -Id $s.cf_pid   -Force -ErrorAction SilentlyContinue } catch {}
        Remove-Item $STATE_FILE -Force -ErrorAction SilentlyContinue
    }
    Get-Process -Name "ttyd" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-OK "WebTerm stopped."
    exit 0
}

# ============================================
# Check if already running
# ============================================
$s = Get-State
if ($s -and $s.ttyd_alive -and $s.cf_alive) {
    Write-Host ""
    Write-Host "  WebTerm is already running!" -ForegroundColor Yellow
    Write-Host "  URL: $($s.url)" -ForegroundColor Cyan
    Write-Host "  Use -Stop to restart." -ForegroundColor DarkGray
    Write-Host ""
    $s.url | Set-Clipboard
    exit 0
}
# Clean stale state
if ($s) {
    try { Stop-Process -Id $s.ttyd_pid -Force -ErrorAction SilentlyContinue } catch {}
    try { Stop-Process -Id $s.cf_pid   -Force -ErrorAction SilentlyContinue } catch {}
    Remove-Item $STATE_FILE -Force -ErrorAction SilentlyContinue
}

# ============================================
# AUTO-INSTALL
# ============================================
Write-Host ""
Write-Host "  ===============================" -ForegroundColor Magenta
Write-Host "  WEBTERM - Terminal in Browser" -ForegroundColor Magenta
Write-Host "  ===============================" -ForegroundColor Magenta
Write-Host ""

New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null

# Install ttyd
if (!(Test-Path $TTYD_EXE)) {
    Write-Step "Installing ttyd..."
    New-Item -ItemType Directory -Path $TTYD_DIR -Force | Out-Null
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/tsl0922/ttyd/releases/latest" -Headers @{"User-Agent"="WebTerm"}
    $asset = $release.assets | Where-Object { $_.name -match "ttyd\.win32\.exe|ttyd_win32\.exe|ttyd.*windows.*\.exe" } | Select-Object -First 1
    if ($asset) {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $TTYD_EXE -UseBasicParsing
        Write-OK "ttyd installed"
    } else {
        winget install -e --id tsl0922.ttyd --accept-package-agreements --accept-source-agreements --silent 2>$null
        $w = Get-Command ttyd -ErrorAction SilentlyContinue
        if ($w) { Copy-Item $w.Source $TTYD_EXE -Force; Write-OK "ttyd installed via winget" }
        else { Write-Err "Could not install ttyd"; exit 1 }
    }
} else { Write-OK "ttyd ready" }

# Install cloudflared
$cfCheck = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cfCheck) { $CF_EXE = $cfCheck.Source }
if (!(Test-Path $CF_EXE)) {
    Write-Step "Installing cloudflared..."
    New-Item -ItemType Directory -Path $CF_DIR -Force | Out-Null
    Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile $CF_EXE -UseBasicParsing
    Write-OK "cloudflared installed"
} else { Write-OK "cloudflared ready" }

# ============================================
# START TTYD (PowerShell terminal)
# ============================================
Write-Step "Starting PowerShell terminal on port $Port..."

# Launch ttyd with powershell directly - simplest working approach
# -W=writable, -w sets working directory
$ttydArgs = "-p $Port -W -t titleFixed=WebTerm -t disableReconnect=false powershell.exe -NoLogo -NoExit"
$ttydProc = Start-Process -FilePath $TTYD_EXE `
    -ArgumentList $ttydArgs `
    -WindowStyle Hidden -PassThru

if (!$ttydProc -or $ttydProc.HasExited) {
    Write-Err "Failed to start ttyd!"
    exit 1
}
Write-OK "ttyd started (PID: $($ttydProc.Id))"

# Wait for ready
Write-Step "Waiting for ttyd..."
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    try { $tcp = [System.Net.Sockets.TcpClient]::new("127.0.0.1", $Port); $tcp.Close(); $ready = $true; break } catch {}
}
if (!$ready) { Write-Err "ttyd not responding on port $Port"; Stop-Process -Id $ttydProc.Id -Force -ErrorAction SilentlyContinue; exit 1 }
Write-OK "ttyd ready on http://localhost:$Port"

# ============================================
# START CLOUDFLARED TUNNEL
# ============================================
Write-Step "Creating tunnel..."
$cfProc = Start-Process -FilePath $CF_EXE `
    -ArgumentList @("tunnel", "--url", "http://localhost:$Port") `
    -WindowStyle Hidden -PassThru -RedirectStandardError "$LOG_DIR\cf.log"

if (!$cfProc -or $cfProc.HasExited) {
    Write-Err "Failed to start cloudflared!"
    Stop-Process -Id $ttydProc.Id -Force -ErrorAction SilentlyContinue
    exit 1
}

# Get URL
Write-Step "Waiting for public URL..."
$publicUrl = $null
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-Path "$LOG_DIR\cf.log") {
        $log = Get-Content "$LOG_DIR\cf.log" -Raw -ErrorAction SilentlyContinue
        if ($log -match '(https://[a-zA-Z0-9-]+\.trycloudflare\.com)') {
            $publicUrl = $matches[1]
            break
        }
    }
}

# Save state
@{
    port     = $Port
    url      = $(if ($publicUrl) { $publicUrl } else { "http://localhost:$Port" })
    ttyd_pid = $ttydProc.Id
    cf_pid   = $cfProc.Id
    started  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
} | ConvertTo-Json | Set-Content $STATE_FILE -Encoding UTF8

if ($publicUrl) { $publicUrl | Set-Clipboard }

Write-Host ""
Write-Host "  =============================================" -ForegroundColor Green
Write-Host "  TERMINAL IS LIVE!" -ForegroundColor Green
Write-Host "  =============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Local:  http://localhost:$Port" -ForegroundColor White
if ($publicUrl) {
    Write-Host ""
    Write-Host "  GLOBAL URL (copied to clipboard):" -ForegroundColor Yellow
    Write-Host "  $publicUrl" -ForegroundColor Cyan
} else {
    Write-Host "  Global URL failed - check $LOG_DIR\cf.log" -ForegroundColor Red
}
Write-Host ""
Write-Host "  Status:  webterm -Status" -ForegroundColor DarkGray
Write-Host "  Stop:    webterm -Stop" -ForegroundColor DarkGray
Write-Host "  =============================================" -ForegroundColor Green
Write-Host ""
