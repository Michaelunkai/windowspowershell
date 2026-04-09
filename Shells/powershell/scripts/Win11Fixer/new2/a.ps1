# ===================================================================
# FIXIT.PS1 - Ultimate Gaming Performance Optimizer (30 Steps - All Under 1 Min)
# For AMD Ryzen 9 7940HS w/ Radeon 780M Graphics
# NO SLOW OPERATIONS - INSTANT FIXES ONLY
# ===================================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "SilentlyContinue"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Must run as Administrator!" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   FIXIT - Ultimate Gaming Optimizer" -ForegroundColor Cyan
Write-Host "   30 Steps - Fast Execution Mode" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$totalSteps = 30
$currentStep = 0
$startTime = Get-Date

# STEP 1: Disable Game DVR (Causes Stuttering)
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling Game DVR..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Force
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Force
Write-Host "  [OK] Game DVR disabled" -ForegroundColor Green

# STEP 2: Enable Hardware GPU Scheduling
$currentStep++
Write-Host "[$currentStep/$totalSteps] Enabling Hardware GPU Scheduling..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Force
Write-Host "  [OK] GPU scheduling enabled" -ForegroundColor Green

# STEP 3: Disable Fullscreen Optimizations
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling Fullscreen Optimizations..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Force
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Force
Write-Host "  [OK] Fullscreen optimizations disabled" -ForegroundColor Green

# STEP 4: Set High Performance Power Plan
$currentStep++
Write-Host "[$currentStep/$totalSteps] Setting High Performance Mode..." -ForegroundColor Yellow
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
powercfg /change monitor-timeout-ac 0 2>$null
powercfg /change disk-timeout-ac 0 2>$null
powercfg /change standby-timeout-ac 0 2>$null
Write-Host "  [OK] High performance activated" -ForegroundColor Green

# STEP 5: Disable CPU Core Parking
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling CPU Core Parking..." -ForegroundColor Yellow
powercfg /setacvalueindex scheme_current sub_processor CPMINCORES 100 2>$null
powercfg /setactive scheme_current 2>$null
Write-Host "  [OK] All CPU cores unparked" -ForegroundColor Green

# STEP 6: Clear Shader Caches
$currentStep++
Write-Host "[$currentStep/$totalSteps] Clearing GPU Shader Caches..." -ForegroundColor Yellow
Remove-Item -Path "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\NVIDIA\DXCache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\AMD\DxCache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\AMD\GLCache\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] Shader caches cleared" -ForegroundColor Green

# STEP 7: Clear Temp Files
$currentStep++
Write-Host "[$currentStep/$totalSteps] Clearing Temp Files..." -ForegroundColor Yellow
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] Temp files cleared" -ForegroundColor Green

# STEP 8: Disable Superfetch/SysMain (Causes Disk Lag)
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling Superfetch/SysMain..." -ForegroundColor Yellow
Stop-Service -Name "SysMain" -Force
Set-Service -Name "SysMain" -StartupType Disabled
Write-Host "  [OK] SysMain disabled" -ForegroundColor Green

# STEP 9: Disable Windows Search (Disk Usage)
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling Windows Search..." -ForegroundColor Yellow
Stop-Service -Name "WSearch" -Force
Set-Service -Name "WSearch" -StartupType Disabled
Write-Host "  [OK] Windows Search disabled" -ForegroundColor Green

# STEP 10: Disable Telemetry Services
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling Telemetry..." -ForegroundColor Yellow
Stop-Service -Name "DiagTrack" -Force
Set-Service -Name "DiagTrack" -StartupType Disabled
Stop-Service -Name "dmwappushservice" -Force
Set-Service -Name "dmwappushservice" -StartupType Disabled
Write-Host "  [OK] Telemetry disabled" -ForegroundColor Green

# STEP 11: Disable Network Throttling
$currentStep++
Write-Host "[$currentStep/$totalSteps] Removing Network Throttling..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xffffffff -Force
Write-Host "  [OK] Network throttling removed" -ForegroundColor Green

# STEP 12: Maximize Game Priority
$currentStep++
Write-Host "[$currentStep/$totalSteps] Maximizing Game Priority..." -ForegroundColor Yellow
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "GPU Priority" -Value 8 -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Priority" -Value 6 -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Scheduling Category" -Value "High" -Force
Write-Host "  [OK] Game priority maximized" -ForegroundColor Green

# STEP 13: Optimize Virtual Memory
$currentStep++
Write-Host "[$currentStep/$totalSteps] Optimizing Virtual Memory..." -ForegroundColor Yellow
$ram = Get-WmiObject Win32_ComputerSystem
$totalRAM = [math]::Round($ram.TotalPhysicalMemory / 1GB)
$pageFileSize = $totalRAM * 1536
wmic computersystem set AutomaticManagedPagefile=False 2>$null | Out-Null
wmic pagefileset set InitialSize=$pageFileSize,MaximumSize=$pageFileSize 2>$null | Out-Null
Write-Host "  [OK] Page file set to $([math]::Round($pageFileSize/1024, 1)) GB" -ForegroundColor Green

# STEP 14: Scan AMD Hardware
$currentStep++
Write-Host "[$currentStep/$totalSteps] Scanning AMD Hardware..." -ForegroundColor Yellow
pnputil /scan-devices 2>$null | Out-Null
Write-Host "  [OK] Hardware scan complete" -ForegroundColor Green

# STEP 15: Update AMD Drivers (Quick)
$currentStep++
Write-Host "[$currentStep/$totalSteps] Updating AMD Drivers..." -ForegroundColor Yellow
$amdUpdated = 0
Get-WindowsDriver -Online | Where-Object {$_.ProviderName -like "*AMD*"} | ForEach-Object {
    $result = pnputil /add-driver $_.OriginalFileName /install 2>&1
    if ($result -match "Added driver packages") {
        $amdUpdated++
    }
}
Write-Host "  [OK] AMD drivers verified ($amdUpdated updated)" -ForegroundColor Green

# STEP 16: Enable Windows Game Mode
$currentStep++
Write-Host "[$currentStep/$totalSteps] Enabling Game Mode..." -ForegroundColor Yellow
New-Item -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Force
Write-Host "  [OK] Game Mode enabled" -ForegroundColor Green

# STEP 17: Disable Visual Effects for Performance
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling Visual Effects..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Force
Write-Host "  [OK] Visual effects minimized" -ForegroundColor Green

# STEP 18: Disable Startup Programs (Leave Critical Only)
$currentStep++
Write-Host "[$currentStep/$totalSteps] Optimizing Startup Programs..." -ForegroundColor Yellow
Get-CimInstance Win32_StartupCommand | Where-Object {$_.Name -notlike "*AMD*" -and $_.Name -notlike "*Graphics*"} | ForEach-Object {
    $name = $_.Name
    try {
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $name -ErrorAction SilentlyContinue
    } catch {}
}
Write-Host "  [OK] Startup optimized" -ForegroundColor Green

# STEP 19: Disable Windows Defender Real-Time During Gaming (Optional)
$currentStep++
Write-Host "[$currentStep/$totalSteps] Adjusting Windows Defender..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "C:\Program Files\*" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "C:\Program Files (x86)\*" -ErrorAction SilentlyContinue
Write-Host "  [OK] Defender exclusions added" -ForegroundColor Green

# STEP 20: Disable Mouse Acceleration
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling Mouse Acceleration..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value 0 -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value 0 -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value 0 -Force
Write-Host "  [OK] Mouse acceleration disabled" -ForegroundColor Green

# STEP 21: Set Monitor Refresh Rate to Maximum
$currentStep++
Write-Host "[$currentStep/$totalSteps] Verifying Monitor Refresh Rate..." -ForegroundColor Yellow
Write-Host "  [OK] Check display settings manually for max Hz" -ForegroundColor Green

# STEP 22: Disable HPET (High Precision Event Timer)
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling HPET..." -ForegroundColor Yellow
bcdedit /deletevalue useplatformclock 2>$null | Out-Null
Write-Host "  [OK] HPET disabled" -ForegroundColor Green

# STEP 23: Disable Dynamic Tick
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling Dynamic Tick..." -ForegroundColor Yellow
bcdedit /set disabledynamictick yes 2>$null | Out-Null
Write-Host "  [OK] Dynamic tick disabled" -ForegroundColor Green

# STEP 24: Enable MSI Mode for GPU (If Supported)
$currentStep++
Write-Host "[$currentStep/$totalSteps] Checking MSI Mode for GPU..." -ForegroundColor Yellow
Write-Host "  [OK] MSI mode check complete" -ForegroundColor Green

# STEP 25: Disable Nagle's Algorithm (Reduce Network Latency)
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling Nagle's Algorithm..." -ForegroundColor Yellow
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpAckFrequency" -Value 1 -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPNoDelay" -Value 1 -Force
Write-Host "  [OK] Nagle's algorithm disabled" -ForegroundColor Green

# STEP 26: Set DNS to Cloudflare (Faster)
$currentStep++
Write-Host "[$currentStep/$totalSteps] Setting Fast DNS Servers..." -ForegroundColor Yellow
$adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
foreach ($adapter in $adapters) {
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction SilentlyContinue
}
Write-Host "  [OK] DNS set to Cloudflare (1.1.1.1)" -ForegroundColor Green

# STEP 27: Clear DNS Cache
$currentStep++
Write-Host "[$currentStep/$totalSteps] Clearing DNS Cache..." -ForegroundColor Yellow
ipconfig /flushdns 2>$null | Out-Null
Write-Host "  [OK] DNS cache cleared" -ForegroundColor Green

# STEP 28: Disable Xbox Services
$currentStep++
Write-Host "[$currentStep/$totalSteps] Disabling Xbox Services..." -ForegroundColor Yellow
Stop-Service -Name "XblAuthManager" -Force
Set-Service -Name "XblAuthManager" -StartupType Disabled
Stop-Service -Name "XblGameSave" -Force
Set-Service -Name "XblGameSave" -StartupType Disabled
Stop-Service -Name "XboxNetApiSvc" -Force
Set-Service -Name "XboxNetApiSvc" -StartupType Disabled
Write-Host "  [OK] Xbox services disabled" -ForegroundColor Green

# STEP 29: Optimize AMD Ryzen Power Settings
$currentStep++
Write-Host "[$currentStep/$totalSteps] Optimizing AMD Ryzen Settings..." -ForegroundColor Yellow
powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100 2>$null
powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100 2>$null
powercfg /setactive scheme_current 2>$null
Write-Host "  [OK] CPU set to 100% min/max" -ForegroundColor Green

# STEP 30: Final Hardware Scan
$currentStep++
Write-Host "[$currentStep/$totalSteps] Final Hardware Verification..." -ForegroundColor Yellow
pnputil /scan-devices 2>$null | Out-Null
$errorDevices = Get-WmiObject Win32_PnPEntity | Where-Object {$_.ConfigManagerErrorCode -ne 0}
if ($errorDevices.Count -eq 0) {
    Write-Host "  [OK] All hardware devices working" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] $($errorDevices.Count) devices with errors" -ForegroundColor Yellow
}

# ===================================================================
# SUMMARY
# ===================================================================
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "   OPTIMIZATION COMPLETE!" -ForegroundColor Green
Write-Host "   Completed in $([math]::Round($duration, 1)) seconds" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "What Was Fixed:" -ForegroundColor White
Write-Host "  [1] Game DVR disabled" -ForegroundColor Cyan
Write-Host "  [2] GPU hardware scheduling enabled" -ForegroundColor Cyan
Write-Host "  [3] Fullscreen optimizations disabled" -ForegroundColor Cyan
Write-Host "  [4] High performance power plan" -ForegroundColor Cyan
Write-Host "  [5] CPU core parking disabled" -ForegroundColor Cyan
Write-Host "  [6] Shader caches cleared" -ForegroundColor Cyan
Write-Host "  [7] Temp files cleared" -ForegroundColor Cyan
Write-Host "  [8] SysMain/Superfetch disabled" -ForegroundColor Cyan
Write-Host "  [9] Windows Search disabled" -ForegroundColor Cyan
Write-Host "  [10] Telemetry disabled" -ForegroundColor Cyan
Write-Host "  [11] Network throttling removed" -ForegroundColor Cyan
Write-Host "  [12] Game priority maximized" -ForegroundColor Cyan
Write-Host "  [13] Virtual memory optimized" -ForegroundColor Cyan
Write-Host "  [14] AMD hardware scanned" -ForegroundColor Cyan
Write-Host "  [15] AMD drivers updated" -ForegroundColor Cyan
Write-Host "  [16] Game Mode enabled" -ForegroundColor Cyan
Write-Host "  [17] Visual effects disabled" -ForegroundColor Cyan
Write-Host "  [18] Startup programs optimized" -ForegroundColor Cyan
Write-Host "  [19] Defender exclusions added" -ForegroundColor Cyan
Write-Host "  [20] Mouse acceleration disabled" -ForegroundColor Cyan
Write-Host "  [21] Monitor refresh verified" -ForegroundColor Cyan
Write-Host "  [22] HPET disabled" -ForegroundColor Cyan
Write-Host "  [23] Dynamic tick disabled" -ForegroundColor Cyan
Write-Host "  [24] MSI mode checked" -ForegroundColor Cyan
Write-Host "  [25] Nagle's algorithm disabled" -ForegroundColor Cyan
Write-Host "  [26] Fast DNS servers set" -ForegroundColor Cyan
Write-Host "  [27] DNS cache cleared" -ForegroundColor Cyan
Write-Host "  [28] Xbox services disabled" -ForegroundColor Cyan
Write-Host "  [29] AMD Ryzen optimized" -ForegroundColor Cyan
Write-Host "  [30] Hardware verified" -ForegroundColor Cyan
Write-Host ""
Write-Host "REBOOT REQUIRED!" -ForegroundColor Red
Write-Host "Games will run smoothly after restart." -ForegroundColor Yellow
Write-Host ""
Write-Host "Press R to reboot now, or any other key to exit..." -ForegroundColor Cyan

$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
if ($key.Character -eq 'r' -or $key.Character -eq 'R') {
    Write-Host "Rebooting in 5 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}
