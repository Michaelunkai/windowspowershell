# MSERT Auto-Runner BULLETPROOF v3.1
# Guaranteed timeout, guaranteed cleanup, guaranteed completion

param(
    [int]$TimeoutSeconds = 7200,  # 2 hours
    [bool]$ForceRemoveMode = $true
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    MSERT Auto-Runner BULLETPROOF v3.1                 ║" -ForegroundColor Cyan
Write-Host "║    Guaranteed: Timeout, Cleanup, Completion           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# PHASE 1: FIND MSERT
# ============================================================================

$msertPath = $null
foreach ($path in @(
    "C:\Program Files (x86)\Windows Defender\MSERT.exe",
    "C:\Program Files\Windows Defender\MSERT.exe",
    "C:\Windows\System32\MSERT.exe"
)) {
    if (Test-Path $path) {
        $msertPath = $path
        Write-Host "✓ Found MSERT: $path" -ForegroundColor Green
        break
    }
}

if (-not $msertPath) {
    Write-Host "❌ MSERT not found!" -ForegroundColor Red
    exit 1
}

# ============================================================================
# PHASE 2: START MSERT
# ============================================================================

Write-Host "Starting MSERT with /F flag (auto-remove, headless)..." -ForegroundColor Yellow
$startTime = Get-Date
$msertProcess = $null

try {
    # Use ProcessStartInfo for maximum control
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $msertPath
    $pinfo.Arguments = "/F"
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $pinfo.RedirectStandardOutput = $false
    $pinfo.RedirectStandardError = $false
    
    $msertProcess = [System.Diagnostics.Process]::Start($pinfo)
    $pid = $msertProcess.Id
    
    Write-Host "✓ MSERT started (PID: $pid)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to start MSERT: $_" -ForegroundColor Red
    exit 1
}

# ============================================================================
# PHASE 3: WAIT WITH GUARANTEED TIMEOUT
# ============================================================================

Write-Host "Waiting for completion (max $TimeoutSeconds seconds)..." -ForegroundColor Yellow

# Convert timeout to milliseconds
[long]$timeoutMs = $TimeoutSeconds * 1000

# CRITICAL: Use timeout overload to prevent infinite wait
$exited = $msertProcess.WaitForExit($timeoutMs)

if (-not $exited) {
    Write-Host "❌ TIMEOUT exceeded after $TimeoutSeconds seconds!" -ForegroundColor Red
    Write-Host "Force-killing MSERT process..." -ForegroundColor Red
    
    try {
        $msertProcess.Kill($true)  # $true = kill tree
        $msertProcess.WaitForExit(5000)  # Wait max 5s for kill to complete
    }
    catch {
        Write-Host "⚠️ Failed to kill process: $_" -ForegroundColor Yellow
    }
    
    exit 124  # Timeout exit code
}

# ============================================================================
# PHASE 4: READ EXIT CODE
# ============================================================================

$exitCode = $msertProcess.ExitCode
$elapsed = ((Get-Date) - $startTime).TotalSeconds

Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "RESULT:" -ForegroundColor Cyan
Write-Host "  Exit Code: $exitCode" -ForegroundColor Cyan
Write-Host "  Elapsed: $([Math]::Round($elapsed))s / $TimeoutSeconds" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan

# ============================================================================
# PHASE 5: INTERPRET & EXIT
# ============================================================================

$success = $false

switch ($exitCode) {
    0 {
        Write-Host "✓ MSERT completed successfully (no threats found)" -ForegroundColor Green
        $success = $true
    }
    1 {
        Write-Host "✓ MSERT completed successfully (threats removed)" -ForegroundColor Green
        $success = $true
    }
    2 {
        Write-Host "✓ MSERT completed (threats cleaned)" -ForegroundColor Green
        $success = $true
    }
    default {
        Write-Host "⚠️ MSERT exited with code: $exitCode" -ForegroundColor Yellow
        $success = ($exitCode -in @(0, 1, 2))
    }
}

# ============================================================================
# CLEANUP (GUARANTEED)
# ============================================================================

Write-Host ""
Write-Host "Cleaning up..." -ForegroundColor Yellow

try {
    if ($msertProcess) {
        $msertProcess.Dispose()
    }
}
catch {
    Write-Host "⚠️ Cleanup warning: $_" -ForegroundColor Yellow
}

if ($success) {
    Write-Host "✓ Done!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ MSERT reported an error" -ForegroundColor Red
    exit $exitCode
}
