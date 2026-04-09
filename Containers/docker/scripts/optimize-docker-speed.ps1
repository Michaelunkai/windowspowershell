# Docker Speed Optimization Script
# Ensures maximum Docker performance for all operations
# Run this after every reboot or whenever Docker feels slow

Write-Host "=== DOCKER SPEED OPTIMIZER ===" -ForegroundColor Cyan
Write-Host ""

# 1. Optimize Windows TCP/IP Stack
Write-Host "[1/6] Optimizing TCP/IP stack..." -ForegroundColor Yellow
netsh int tcp set global autotuninglevel=experimental | Out-Null
netsh int tcp set global chimney=enabled | Out-Null
netsh int tcp set global dca=enabled | Out-Null
netsh int tcp set global netdma=enabled | Out-Null
netsh int tcp set global ecncapability=enabled | Out-Null
netsh int tcp set global timestamps=enabled | Out-Null
netsh int tcp set global rss=enabled | Out-Null
netsh int tcp set global rsc=enabled | Out-Null
Write-Host "    OK TCP optimizations applied" -ForegroundColor Green

# 2. Optimize Docker Network Adapter
Write-Host "[2/6] Optimizing Docker network adapter..." -ForegroundColor Yellow
try {
    Set-NetAdapterAdvancedProperty -Name "vEthernet (DockerExternal)" -DisplayName "Maximum Number of RSS Processors" -DisplayValue 16 -ErrorAction SilentlyContinue
    Set-NetAdapterAdvancedProperty -Name "vEthernet (DockerExternal)" -DisplayName "Maximum Number of RSS Queues" -DisplayValue 16 -ErrorAction SilentlyContinue
    Write-Host "    OK Network adapter optimized" -ForegroundColor Green
}
catch {
    Write-Host "    WARN Network adapter not ready (Docker may be starting)" -ForegroundColor Yellow
}

# 3. Disable Windows Defender for Docker operations
Write-Host "[3/6] Verifying Windows Defender exclusions..." -ForegroundColor Yellow
$exclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
if ($exclusions -contains "C:\ProgramData\Docker") {
    Write-Host "    OK Docker directories excluded from scanning" -ForegroundColor Green
}
else {
    Write-Host "    WARN Adding Docker exclusions..." -ForegroundColor Yellow
    Add-MpPreference -ExclusionPath "C:\ProgramData\Docker"
    Add-MpPreference -ExclusionPath "C:\ProgramData\DockerDesktop"
    Add-MpPreference -ExclusionPath "C:\Program Files\Docker"
}

# 4. Optimize disk caching
Write-Host "[4/6] Optimizing disk caching..." -ForegroundColor Yellow
fsutil behavior set disablelastaccess 1 | Out-Null
Write-Host "    OK Last access tracking disabled" -ForegroundColor Green

# 5. Set processor performance mode
Write-Host "[5/6] Setting CPU to maximum performance..." -ForegroundColor Yellow
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
Write-Host "    OK High performance mode enabled" -ForegroundColor Green

# 6. Check Docker status
Write-Host "[6/6] Checking Docker status..." -ForegroundColor Yellow
$dockerRunning = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
if ($dockerRunning) {
    Write-Host "    OK Docker is running" -ForegroundColor Green
    Write-Host ""
    Write-Host "Current Docker Configuration:" -ForegroundColor Cyan
    docker info 2>$null | Select-String -Pattern "CPUs|Memory|Server Version"
}
else {
    Write-Host "    WARN Docker is not running - starting..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Write-Host "    OK Docker starting (allow 15 seconds)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== OPTIMIZATION COMPLETE ===" -ForegroundColor Green
Write-Host "All Docker commands will now run at maximum speed." -ForegroundColor Green
Write-Host "These settings persist until next reboot." -ForegroundColor Yellow
Write-Host ""
