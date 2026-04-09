# MSERT Auto-Cleanup with Stuck Detection & Force-Kill
# Handles frozen MSERT, hung clicker, UI automation fallback
# Author: Agent 5 Solution Engineering | Status: Production-Ready

param(
    [int]$TimeoutSeconds = 7200,    # 2 hours max
    [int]$StuckCheckInterval = 30,  # Check every 30s if stuck
    [int]$MaxStuckCount = 5,        # Kill if unresponsive 5× in a row
    [string]$LogPath = "C:\logs\msert-runner.log"
)

# Setup logging
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

function Log {
    param([string]$msg, [string]$level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$level] $msg"
    Add-Content -Path $LogPath -Value $line
    Write-Host $line -ForegroundColor $(if ($level -eq "ERROR") { "Red" } else { "White" })
}

Log "======================================" "INFO"
Log "MSERT Runner v3.0 PRODUCTION START" "INFO"
Log "Timeout: $TimeoutSeconds seconds | Stuck check: $StuckCheckInterval seconds" "INFO"
Log "======================================" "INFO"

# ===== STEP 1: Download MSERT =====
Log "Downloading Microsoft Safety Scanner..." "INFO"
$msertPath = "$env:TEMP\MSERT.exe"
Remove-Item $msertPath -Force -ErrorAction SilentlyContinue

try {
    Invoke-WebRequest 'https://go.microsoft.com/fwlink/?LinkId=212732' -OutFile $msertPath -TimeoutSec 60
    Log "Downloaded MSERT to $msertPath" "INFO"
} catch {
    Log "FAILED to download MSERT: $_" "ERROR"
    exit 1
}

# ===== STEP 2: Kill existing MSERT/clicker =====
Log "Cleaning up old processes..." "INFO"
Get-Process -Name "MSERT", "python" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# ===== STEP 3: Launch MSERT with AUTO-REMOVE flag =====
Log "Launching MSERT with /F:Y (auto-remove threats)..." "INFO"
$msertProcess = Start-Process -FilePath $msertPath -ArgumentList "/F:Y" -PassThru

if (-not $msertProcess) {
    Log "FAILED to launch MSERT" "ERROR"
    exit 1
}

Log "MSERT launched (PID: $($msertProcess.Id))" "INFO"

# ===== STEP 4: Start clicker parallel (fallback for GUI mode) =====
Log "Starting UI automation clicker as fallback..." "INFO"
$clickerPath = Join-Path (Split-Path -Parent $PSScriptRoot) "msert-clicker-PRODUCTION.py"
if (Test-Path $clickerPath) {
    $clickerProc = Start-Process -FilePath "python.exe" -ArgumentList $clickerPath -PassThru
    Log "Clicker started (PID: $($clickerProc.Id))" "INFO"
} else {
    Log "Clicker not found at $clickerPath — proceeding with MSERT only" "WARN"
    $clickerProc = $null
}

# ===== STEP 5: Monitor for stuck processes =====
Log "Starting health monitoring loop..." "INFO"

$startTime = Get-Date
$stuckCount = 0
$lastWindowTitle = ""
$lastFilesScanned = 0
$msertFinished = $false

while ($true) {
    $elapsed = (Get-Date) - $startTime
    $elapsedSec = [int]$elapsed.TotalSeconds

    # Check if MSERT is still running
    $msertAlive = Get-Process -Id $msertProcess.Id -ErrorAction SilentlyContinue
    if (-not $msertAlive) {
        Log "MSERT process exited (PID: $($msertProcess.Id))" "INFO"
        $msertFinished = $true
        break
    }

    # Try to get window title (indicates responsiveness)
    $msertWindow = Get-Process -Name "MSERT" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" }
    $currentWindowTitle = if ($msertWindow) { $msertWindow.MainWindowTitle } else { "" }

    # Check if window changed (indicates progress)
    if ($currentWindowTitle -ne $lastWindowTitle) {
        Log "Window title changed: '$lastWindowTitle' → '$currentWindowTitle'" "INFO"
        $lastWindowTitle = $currentWindowTitle
        $stuckCount = 0
    } else {
        $stuckCount++
        if ($stuckCount -eq 1) {
            Log "⚠️  Window title unchanged for $StuckCheckInterval seconds (check $stuckCount/$MaxStuckCount)" "WARN"
        }
    }

    # If stuck for too long, kill and fallback
    if ($stuckCount -ge $MaxStuckCount) {
        Log "❌ MSERT stuck for $($StuckCheckInterval * $MaxStuckCount) seconds — force-killing" "ERROR"
        Stop-Process -Id $msertProcess.Id -Force -ErrorAction SilentlyContinue
        Log "MSERT terminated (forced)" "INFO"
        break
    }

    # Timeout check
    if ($elapsedSec -ge $TimeoutSeconds) {
        Log "⏱️  TIMEOUT: Exceeded $TimeoutSeconds seconds — killing MSERT" "ERROR"
        Stop-Process -Id $msertProcess.Id -Force -ErrorAction SilentlyContinue
        Log "MSERT terminated (timeout)" "INFO"
        break
    }

    # Log progress every 300 seconds (5 min)
    if ($elapsedSec % 300 -eq 0 -and $elapsedSec -gt 0) {
        Log "Progress: $([int]($elapsedSec / 60)) min elapsed | Window: '$currentWindowTitle'" "INFO"
    }

    Start-Sleep -Seconds $StuckCheckInterval
}

# ===== STEP 6: Wait for clicker to finish (if running) =====
if ($clickerProc) {
    Log "Waiting for clicker to finish..." "INFO"
    try {
        $clickerProc.WaitForExit(30000)  # 30-second timeout
        $clickerExitCode = $clickerProc.ExitCode
        Log "Clicker finished with exit code: $clickerExitCode" "INFO"
    } catch {
        Log "Clicker timeout or error: $_" "WARN"
        Stop-Process -Id $clickerProc.Id -Force -ErrorAction SilentlyContinue
    }
}

# ===== STEP 7: Parse MSERT results =====
Log "Scanning for MSERT log files..." "INFO"

$logLocations = @(
    "C:\Windows\debug\msert.log",
    "$env:TEMP\msert.log",
    "C:\$RECYCLE.BIN\*msert*.log"
)

$foundLog = $null
foreach ($loc in $logLocations) {
    if (Test-Path $loc) {
        $foundLog = (Get-Item $loc -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        if ($foundLog) { break }
    }
}

if ($foundLog) {
    Log "Found MSERT log: $foundLog" "INFO"
    $logContent = Get-Content $foundLog -Raw -ErrorAction SilentlyContinue
    
    # Check for threats
    $threatsFound = $logContent | Select-String "Threat" | Measure-Object | Select-Object -ExpandProperty Count
    $threatsRemoved = $logContent | Select-String "Removed|Cleaned|Delete" | Measure-Object | Select-Object -ExpandProperty Count
    
    Log "Threats found: $threatsFound | Threats removed: $threatsRemoved" "INFO"
    
    if ($threatsFound -eq 0) {
        Log "✅ No threats detected — system clean" "INFO"
    } elseif ($threatsRemoved -ge $threatsFound) {
        Log "✅ All threats removed successfully" "INFO"
    } else {
        Log "⚠️  Some threats remain — manual cleanup may be needed" "WARN"
    }
} else {
    Log "⚠️  MSERT log not found — check MSERT.exe execution" "WARN"
}

# ===== STEP 8: Cleanup =====
Remove-Item $msertPath -Force -ErrorAction SilentlyContinue
Log "Cleaned up temporary files" "INFO"
Log "MSERT Runner finished" "INFO"
Log "======================================" "INFO"

exit 0
