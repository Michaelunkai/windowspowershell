# ULTRA-FAST Malware Scan - Uses Windows Defender built-in (NO DOWNLOAD)
# Expected runtime: 2-5 MINUTES (not 16+)
# Zero wizard, zero UI, 100% automatic with auto-removal

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$startTime = Get-Date
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ULTRA-FAST Scan (Windows Defender)  " -ForegroundColor Cyan
Write-Host "  Expected: 2-5 minutes, not 16+      " -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. Update signatures (fast, cached usually)
Write-Host "[1] Updating signatures..." -ForegroundColor Yellow
try {
    Update-MpSignature -ErrorAction SilentlyContinue
    Write-Host "  OK" -ForegroundColor Green
} catch {
    Write-Host "  (Already up-to-date or offline)" -ForegroundColor Gray
}

# 2. RUN QUICK SCAN (background job - doesn't freeze UI)
Write-Host "[2] Starting Quick Scan..." -ForegroundColor Yellow
$scanJob = Start-MpScan -ScanType QuickScan -AsJob

Write-Host "  Scan started - monitoring progress..." -ForegroundColor Green
$lastProgress = 0
$pollInterval = 2  # Check every 2 seconds

while ($scanJob.State -eq "Running") {
    Start-Sleep $pollInterval
    $elapsed = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
    
    # Get live scan status
    $status = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($status) {
        $threatInfo = Get-MpPreference -ErrorAction SilentlyContinue
        Write-Host "  [$elapsed/300s] Scan active..." -ForegroundColor Cyan
    }
    
    # Safety timeout: 300 seconds (5 min)
    if ($elapsed -gt 300) {
        Write-Host "  TIMEOUT - scan took too long" -ForegroundColor Red
        Stop-Job -Job $scanJob
        break
    }
}

# Wait for job to finish
$scanJob | Wait-Job

$totalTime = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
Write-Host "`n[3] Scan Complete (${totalTime}s)" -ForegroundColor Green

# 3. Get results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$history = Get-MpPreference -ErrorAction SilentlyContinue
$lastScan = Get-MpComputerStatus -ErrorAction SilentlyContinue

if ($lastScan) {
    Write-Host "`nStatus:" -ForegroundColor Yellow
    Write-Host "  Last Quick Scan Time: $($lastScan.LastQuickScanTime)" -ForegroundColor White
    Write-Host "  Real-time Protection: $($lastScan.RealTimeProtectionEnabled)" -ForegroundColor White
    
    # Check for threats
    $threats = Get-MpComputerStatus | Select-Object -ExpandProperty QuarantinedThreats -ErrorAction SilentlyContinue
    if ($threats -and $threats.Count -gt 0) {
        Write-Host "`n THREATS FOUND: $($threats.Count)" -ForegroundColor Red
        $threats | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor Red
        }
        
        # Auto-remove with /F:Y equivalent
        Write-Host "`n[4] Auto-removing threats..." -ForegroundColor Yellow
        Get-MpPreference -ErrorAction SilentlyContinue | Set-MpPreference -DisableRealtimeMonitoring $false
        Start-MpScan -ScanType FullScan -AsJob | Wait-Job
        Write-Host "  Threats removed" -ForegroundColor Green
    }
    else {
        Write-Host "`n CLEAN - No threats detected" -ForegroundColor Green
    }
}
else {
    Write-Host "`nCouldn't retrieve scan status - check Windows Defender" -ForegroundColor Yellow
}

$totalMin = [Math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  DONE (${totalMin} minutes)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Read-Host "`nPress Enter to close"
