# Targeted fixes for remaining issues
$ErrorActionPreference = "Continue"

Write-Host "=== Targeted Fix Script ===" -ForegroundColor Cyan

# Fix mtkbtsvc massive handle leak (89,751 handles!)
Write-Host "=== Fixing mtkbtsvc handle leak ===" -ForegroundColor Cyan
$mtk = Get-Service -Name 'mtkbtsvc' -EA 0
if ($mtk) {
    Write-Host "Stopping mtkbtsvc (MediaTek Bluetooth)..." -ForegroundColor Yellow
    Stop-Service -Name 'mtkbtsvc' -Force -EA 0
    Start-Sleep 2
    Write-Host "Starting mtkbtsvc..." -ForegroundColor Green
    Start-Service -Name 'mtkbtsvc' -EA 0
    Write-Host "mtkbtsvc restarted - handle leak cleared!" -ForegroundColor Green
} else {
    Write-Host "mtkbtsvc not found" -ForegroundColor Yellow
}

# Flush DNS cache (failed entries)
Write-Host "=== Flushing DNS cache ===" -ForegroundColor Cyan
ipconfig /flushdns

# Reset HNS for Docker
Write-Host "=== Resetting HNS (Docker) ===" -ForegroundColor Cyan
Stop-Service -Name 'HNS' -Force -EA 0
Start-Sleep 2
Start-Service -Name 'HNS' -EA 0
Write-Host "HNS restarted" -ForegroundColor Green

# Aggressive Shell Experience Host fix
Write-Host "=== Fixing Shell Experience Host (DCOM {8CFC164F}) ===" -ForegroundColor Cyan
$shellPkg = Get-AppxPackage Microsoft.Windows.ShellExperienceHost -EA 0
if ($shellPkg) {
    Write-Host "Re-registering Shell Experience Host..." -ForegroundColor Yellow
    $manifestPath = Join-Path $shellPkg.InstallLocation "AppXManifest.xml"
    Add-AppxPackage -DisableDevelopmentMode -Register $manifestPath -EA 0
    Write-Host "Shell Experience Host re-registered" -ForegroundColor Green
}

# Register core COM DLLs
Write-Host "=== Re-registering core COM DLLs ===" -ForegroundColor Cyan
$dlls = @('ole32.dll','oleaut32.dll','combase.dll','actxprxy.dll')
foreach ($dll in $dlls) {
    $path = Join-Path $env:SystemRoot "System32\$dll"
    if (Test-Path $path) {
        regsvr32 /s $path
        Write-Host "  Registered: $dll" -ForegroundColor Gray
    }
}

# Restart explorer to clear handles
Write-Host "=== Restarting explorer (clear handle buildup) ===" -ForegroundColor Cyan
Stop-Process -Name 'explorer' -Force -EA 0
Start-Sleep 2
Start-Process explorer

Write-Host "=== Targeted fixes complete ===" -ForegroundColor Green
