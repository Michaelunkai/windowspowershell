# Direct WMI test - no frills
$ErrorActionPreference = "Stop"

# Must run as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "Elevating..."
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $MyInvocation.MyCommand.Path -Wait
    exit
}

Write-Host "=== Direct WMI Restore Point Test ===" -ForegroundColor Cyan
Write-Host "Admin: YES" -ForegroundColor Green
Write-Host ""

# Bypass frequency limit
Write-Host "Bypassing frequency limit..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0 -Force -ErrorAction SilentlyContinue

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$description = "DirectTest_$timestamp"

Write-Host "Creating restore point: $description"
Write-Host "Started at: $(Get-Date -Format 'HH:mm:ss')"

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    $sr = [wmiclass]"\\localhost\root\default:SystemRestore"
    $result = $sr.CreateRestorePoint($description, 12, 100)
    
    $stopwatch.Stop()
    $elapsed = $stopwatch.Elapsed.TotalSeconds
    
    if ($result.ReturnValue -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS! Return code: 0" -ForegroundColor Green
        Write-Host "Elapsed: $([math]::Round($elapsed, 1)) seconds" -ForegroundColor Cyan
        
        if ($elapsed -lt 60) {
            Write-Host "UNDER 60 SECONDS - TARGET MET!" -ForegroundColor Green
        } else {
            Write-Host "Took longer than 60 seconds" -ForegroundColor Yellow
        }
    } else {
        Write-Host ""
        Write-Host "FAILED! Return code: $($result.ReturnValue)" -ForegroundColor Red
        Write-Host "Elapsed: $([math]::Round($elapsed, 1)) seconds" -ForegroundColor Cyan
    }
} catch {
    $stopwatch.Stop()
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Elapsed: $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1)) seconds" -ForegroundColor Cyan
}

# Count restore points
Write-Host ""
Write-Host "Counting restore points..."
try {
    $rps = Get-WmiObject -Namespace "root\default" -Class SystemRestore -ErrorAction Stop
    $count = @($rps).Count
    Write-Host "Total restore points: $count" -ForegroundColor Cyan
} catch {
    Write-Host "Could not count restore points: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
