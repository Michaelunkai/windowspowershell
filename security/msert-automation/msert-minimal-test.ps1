# MSERT Minimal Test - Force-Remove Only (/F flag, no clicker)
# This is the SIMPLEST possible version to test if MSERT works at all

param(
    [int]$TimeoutSeconds = 3600  # 1 hour timeout
)

Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  MSERT Minimal Test - Force-Remove Only   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Find MSERT
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

# Start MSERT with /F flag (auto-remove, no UI)
Write-Host "Starting MSERT with /F flag (auto-remove, headless)..." -ForegroundColor Yellow
$startTime = Get-Date

try {
    $process = Start-Process -FilePath $msertPath -ArgumentList "/F" -PassThru -WindowStyle Hidden
    $pid = $process.Id
    Write-Host "✓ MSERT started (PID: $pid)" -ForegroundColor Green
    
    # Wait with timeout
    Write-Host "Waiting for completion (max $TimeoutSeconds seconds)..." -ForegroundColor Yellow
    
    $exited = $process.WaitForExit($TimeoutSeconds * 1000)
    
    if (-not $exited) {
        Write-Host "❌ TIMEOUT after $TimeoutSeconds seconds!" -ForegroundColor Red
        $process.Kill($true)
        exit 124
    }
    
    $exitCode = $process.ExitCode
    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    
    Write-Host ""
    Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "RESULT:" -ForegroundColor Cyan
    Write-Host "  Exit Code: $exitCode" -ForegroundColor Cyan
    Write-Host "  Elapsed: $([Math]::Round($elapsed))s" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
    
    if ($exitCode -eq 0) {
        Write-Host "✓ MSERT completed successfully (no threats)" -ForegroundColor Green
        exit 0
    } elseif ($exitCode -eq 1) {
        Write-Host "✓ MSERT completed successfully (threats removed)" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "⚠️ MSERT exited with code: $exitCode" -ForegroundColor Yellow
        exit $exitCode
    }
}
catch {
    Write-Host "❌ ERROR: $_" -ForegroundColor Red
    exit 1
}
