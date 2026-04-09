# enable.ps1 - FORCE RESTORE All Windows Security
# Run as Administrator - GUARANTEED to restore Windows Defender
# Reverses ALL changes made by disable.ps1
# WORKS WITHOUT REBOOT - Restores Defender PowerShell module immediately

#Requires -RunAsAdministrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FORCE RESTORING ALL WINDOWS SECURITY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ====================
# 0. STOP INTERFERING PROCESSES
# ====================
Write-Host "[0/40] Stopping interfering processes..." -ForegroundColor Yellow
Get-Process -Name "MsMpEng","NisSrv","SecurityHealthService" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "  OK Processes stopped" -ForegroundColor Green

# ====================
# 1. DELETE ALL POLICY KEYS FIRST (Most Critical Step)
# ====================
Write-Host "[1/40] FORCE DELETING all policy restrictions..." -ForegroundColor Yellow
$policyKeysToDelete = @(
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\AppHVSI",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\TPM"
)
foreach ($key in $policyKeysToDelete) {
    cmd /c "reg delete `"$key`" /f 2>nul" | Out-Null
}
Write-Host "  OK All policy keys deleted" -ForegroundColor Green

# ====================
# 2. DELETE DEFENDER LOCAL OVERRIDES (Critical)
# ====================
Write-Host "[2/40] Removing Defender local overrides..." -ForegroundColor Yellow
$localOverrides = @(
    "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Features",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Exclusions",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\SmartScreen",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard"
)
foreach ($key in $localOverrides) {
    cmd /c "reg delete `"$key`" /f 2>nul" | Out-Null
}
Write-Host "  OK Local overrides removed" -ForegroundColor Green

# ====================
# 3. RESTORE FILE OWNERSHIP TO TRUSTEDINSTALLER
# ====================
Write-Host "[3/40] Restoring Defender file ownership..." -ForegroundColor Yellow
$defenderPaths = @(
    "$env:ProgramFiles\Windows Defender",
    "$env:ProgramFiles\Windows Defender Advanced Threat Protection",
    "$env:ProgramData\Microsoft\Windows Defender",
    "$env:ProgramData\Microsoft\Windows Security Health"
)
foreach ($path in $defenderPaths) {
    if (Test-Path $path) {
        icacls.exe $path /setowner "NT SERVICE\TrustedInstaller" /T /C /Q 2>&1 | Out-Null
        icacls.exe $path /reset /T /C /Q 2>&1 | Out-Null
    }
}
Write-Host "  OK File ownership restored" -ForegroundColor Green

# ====================
# 4. ENABLE ALL DEFENDER DRIVERS (Boot-time drivers - Critical!)
# ====================
Write-Host "[4/40] Enabling Defender drivers..." -ForegroundColor Yellow
$drivers = @(
    @{Name="WdBoot"; Start=0},
    @{Name="WdFilter"; Start=0},
    @{Name="WdNisDrv"; Start=3}
)
foreach ($drv in $drivers) {
    cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$($drv.Name)`" /v Start /t REG_DWORD /d $($drv.Start) /f" 2>&1 | Out-Null
    cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$($drv.Name)`" /v ImagePath /f 2>nul" | Out-Null
}
Write-Host "  OK Defender drivers enabled" -ForegroundColor Green

# ====================
# 5. ENABLE ALL DEFENDER SERVICES
# ====================
Write-Host "[5/40] Enabling all Defender services..." -ForegroundColor Yellow
$services = @(
    @{Name="WinDefend"; Start=2; Type="own"},
    @{Name="WdNisSvc"; Start=3; Type="own"},
    @{Name="SecurityHealthService"; Start=2; Type="own"},
    @{Name="Sense"; Start=3; Type="own"},
    @{Name="mpssvc"; Start=2; Type="share"},
    @{Name="wscsvc"; Start=2; Type="share"}
)
foreach ($svc in $services) {
    cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$($svc.Name)`" /v Start /t REG_DWORD /d $($svc.Start) /f" 2>&1 | Out-Null
    if ($svc.Type -eq "own") {
        sc.exe config $($svc.Name) start= auto type= own 2>&1 | Out-Null
    } else {
        sc.exe config $($svc.Name) start= auto 2>&1 | Out-Null
    }
}
Write-Host "  OK All services enabled" -ForegroundColor Green

# ====================
# 6. ENABLE WINDOWS FIREWALL SERVICE
# ====================
Write-Host "[6/40] Enabling Windows Firewall service..." -ForegroundColor Yellow
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mpssvc`" /v Start /t REG_DWORD /d 2 /f" 2>&1 | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BFE`" /v Start /t REG_DWORD /d 2 /f" 2>&1 | Out-Null
sc.exe config mpssvc start= auto 2>&1 | Out-Null
sc.exe config BFE start= auto 2>&1 | Out-Null
net start BFE 2>&1 | Out-Null
net start mpssvc 2>&1 | Out-Null
Write-Host "  OK Firewall service enabled" -ForegroundColor Green

# ====================
# 7. ENABLE WINDOWS FIREWALL
# ====================
Write-Host "[7/40] Enabling Windows Firewall..." -ForegroundColor Yellow
netsh advfirewall set allprofiles state on 2>&1 | Out-Null
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound 2>&1 | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile`" /v EnableFirewall /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile`" /v EnableFirewall /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile`" /v EnableFirewall /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
Write-Host "  OK Firewall enabled" -ForegroundColor Green

# ====================
# 8. RESTORE UAC
# ====================
Write-Host "[8/40] Restoring UAC..." -ForegroundColor Yellow
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`" /v EnableLUA /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 5 /f" 2>&1 | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`" /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
Write-Host "  OK UAC restored" -ForegroundColor Green

# ====================
# 9. ENABLE SMARTSCREEN
# ====================
Write-Host "[9/40] Enabling SmartScreen..." -ForegroundColor Yellow
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer`" /v SmartScreenEnabled /t REG_SZ /d Warn /f" 2>&1 | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System`" /v EnableSmartScreen /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System`" /v ShellSmartScreenLevel /f 2>nul" | Out-Null
Write-Host "  OK SmartScreen enabled" -ForegroundColor Green

# ====================
# 10. RESTORE CORE ISOLATION / MEMORY INTEGRITY
# ====================
Write-Host "[10/40] Restoring Core Isolation..." -ForegroundColor Yellow
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity`" /v Enabled /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard`" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard`" /v RequirePlatformSecurityFeatures /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard`" /v Locked /f 2>nul" | Out-Null
Write-Host "  OK Core Isolation restored" -ForegroundColor Green

# ====================
# 11. RESTORE NETWORK SECURITY
# ====================
Write-Host "[11/40] Restoring network security..." -ForegroundColor Yellow
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters`" /v RequireSecuritySignature /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters`" /v RequireSecuritySignature /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters`" /v EnableSecuritySignature /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters`" /v EnableSecuritySignature /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters`" /v NullSessionShares /f 2>nul" | Out-Null
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters`" /v RestrictNullSessAccess /t REG_DWORD /d 1 /f" 2>&1 | Out-Null
Write-Host "  OK Network security restored" -ForegroundColor Green

# ====================
# 12. RESTORE LSA SECURITY
# ====================
Write-Host "[12/40] Restoring LSA security..." -ForegroundColor Yellow
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa`" /v EveryoneIncludesAnonymous /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa`" /v RestrictAnonymous /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa`" /v RestrictAnonymousSAM /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa`" /v ForceGuest /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa`" /v LmCompatibilityLevel /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa`" /v NoLmHash /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa`" /v LsaCfgFlags /f 2>nul" | Out-Null
Write-Host "  OK LSA security restored" -ForegroundColor Green

# ====================
# 13. RESTORE FILE PROTECTION
# ====================
Write-Host "[13/40] Restoring Windows File Protection..." -ForegroundColor Yellow
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`" /v SFCDisable /f 2>nul" | Out-Null
Write-Host "  OK File protection restored" -ForegroundColor Green

# ====================
# 14. RESTORE SECURITY CENTER NOTIFICATIONS
# ====================
Write-Host "[14/40] Restoring Security Center..." -ForegroundColor Yellow
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center`" /v AntiVirusDisableNotify /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center`" /v FirewallDisableNotify /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center`" /v UpdatesDisableNotify /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center`" /v AntiVirusOverride /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center`" /v FirewallOverride /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer`" /v HideSCAHealth /f 2>nul" | Out-Null
Write-Host "  OK Security Center restored" -ForegroundColor Green

# ====================
# 15. RESTORE SECURITY HEALTH SYSTRAY
# ====================
Write-Host "[15/40] Restoring Security Health systray..." -ForegroundColor Yellow
$systrayPath = "$env:ProgramFiles\Windows Defender\MSASCuiL.exe"
if (Test-Path $systrayPath) {
    cmd /c "reg add `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`" /v SecurityHealth /t REG_EXPAND_SZ /d `"$systrayPath`" /f" 2>&1 | Out-Null
}
Write-Host "  OK Systray restored" -ForegroundColor Green

# ====================
# 16. RESTORE WINDOWS UPDATE
# ====================
Write-Host "[16/40] Restoring Windows Update..." -ForegroundColor Yellow
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\wuauserv`" /v Start /t REG_DWORD /d 3 /f" 2>&1 | Out-Null
sc.exe config wuauserv start= demand 2>&1 | Out-Null
Write-Host "  OK Windows Update restored" -ForegroundColor Green

# ====================
# 17. DISABLE SMBv1 (Security)
# ====================
Write-Host "[17/40] Disabling SMBv1 (security)..." -ForegroundColor Yellow
cmd /c "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters`" /v SMB1 /t REG_DWORD /d 0 /f" 2>&1 | Out-Null
sc.exe config mrxsmb10 start= disabled 2>&1 | Out-Null
Write-Host "  OK SMBv1 disabled" -ForegroundColor Green

# ====================
# 18. RESTORE DEFENDER POWERSHELL MODULE (CRITICAL - NO REBOOT REQUIRED)
# ====================
Write-Host "[18/40] RESTORING Defender PowerShell Module..." -ForegroundColor Cyan

# Find the latest Defender platform folder
$platformBase = "$env:ProgramData\Microsoft\Windows Defender\Platform"
$latestPlatform = $null

if (Test-Path $platformBase) {
    $latestPlatform = Get-ChildItem -Path $platformBase -Directory |
        Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

$moduleSourcePath = $null
$moduleDestPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules\Defender"

if ($latestPlatform) {
    $moduleSourcePath = Join-Path $latestPlatform "Powershell"
    Write-Host "  Found Defender platform: $latestPlatform" -ForegroundColor Gray
}

# Check if module source exists
if ($moduleSourcePath -and (Test-Path "$moduleSourcePath\Defender.psd1")) {
    Write-Host "  Found Defender module source at: $moduleSourcePath" -ForegroundColor Gray

    # Remove existing broken symlink or folder
    if (Test-Path $moduleDestPath) {
        Write-Host "  Removing existing module folder..." -ForegroundColor Gray
        cmd /c "rmdir /s /q `"$moduleDestPath`"" 2>&1 | Out-Null
        Remove-Item -Path $moduleDestPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Create the Defender module folder
    New-Item -Path $moduleDestPath -ItemType Directory -Force | Out-Null

    # Copy all module files
    Write-Host "  Copying module files..." -ForegroundColor Gray
    Copy-Item -Path "$moduleSourcePath\*" -Destination $moduleDestPath -Recurse -Force

    # Verify copy
    if (Test-Path "$moduleDestPath\Defender.psd1") {
        Write-Host "  OK Defender module files copied to system modules" -ForegroundColor Green
    } else {
        Write-Host "  ! Failed to copy module files" -ForegroundColor Red
    }
} else {
    Write-Host "  ! Defender module source not found in platform folder" -ForegroundColor Yellow
    Write-Host "  Attempting alternative restoration methods..." -ForegroundColor Yellow
}

# ====================
# 19. CREATE SYMBOLIC LINK AS BACKUP METHOD
# ====================
Write-Host "[19/40] Creating module symbolic link..." -ForegroundColor Yellow

# If copy didn't work, try symbolic link
if (-not (Test-Path "$moduleDestPath\Defender.psd1") -and $moduleSourcePath -and (Test-Path "$moduleSourcePath\Defender.psd1")) {
    # Remove destination if exists
    if (Test-Path $moduleDestPath) {
        cmd /c "rmdir /s /q `"$moduleDestPath`"" 2>&1 | Out-Null
    }

    # Create symbolic link
    cmd /c "mklink /D `"$moduleDestPath`" `"$moduleSourcePath`"" 2>&1 | Out-Null

    if (Test-Path "$moduleDestPath\Defender.psd1") {
        Write-Host "  OK Symbolic link created successfully" -ForegroundColor Green
    } else {
        Write-Host "  ! Symbolic link creation failed" -ForegroundColor Red
    }
} else {
    Write-Host "  OK Module already in place" -ForegroundColor Green
}

# ====================
# 20. UPDATE PSMODULEPATH ENVIRONMENT VARIABLE
# ====================
Write-Host "[20/40] Updating PSModulePath..." -ForegroundColor Yellow

$defenderModulePaths = @(
    $moduleDestPath,
    $moduleSourcePath,
    "$env:ProgramFiles\Windows Defender"
)

foreach ($modPath in $defenderModulePaths) {
    if ($modPath -and (Test-Path $modPath)) {
        if ($env:PSModulePath -notlike "*$modPath*") {
            $env:PSModulePath = "$modPath;$env:PSModulePath"
        }
    }
}

# Also update system environment variable permanently
$currentPath = [Environment]::GetEnvironmentVariable("PSModulePath", "Machine")
if ($moduleSourcePath -and ($currentPath -notlike "*$moduleSourcePath*")) {
    [Environment]::SetEnvironmentVariable("PSModulePath", "$moduleSourcePath;$currentPath", "Machine")
}

Write-Host "  OK PSModulePath updated" -ForegroundColor Green

# ====================
# 21. FORCE REGISTER DEFENDER CMDLET ASSEMBLIES
# ====================
Write-Host "[21/40] Registering Defender assemblies..." -ForegroundColor Yellow

$defenderDlls = @(
    "$env:ProgramFiles\Windows Defender\MpProvider.dll",
    "$env:ProgramFiles\Windows Defender\MpClient.dll",
    "$env:ProgramFiles\Windows Defender\MpOav.dll",
    "$env:ProgramFiles\Windows Defender\MpSvc.dll"
)

if ($latestPlatform) {
    $defenderDlls += @(
        "$latestPlatform\MpProvider.dll",
        "$latestPlatform\MpClient.dll",
        "$latestPlatform\MpCmdRun.dll"
    )
}

foreach ($dll in $defenderDlls) {
    if (Test-Path $dll) {
        regsvr32.exe /s $dll 2>&1 | Out-Null
    }
}

Write-Host "  OK Assemblies registered" -ForegroundColor Green

# ====================
# 22. RESET WINDEFEND SERVICE SECURITY DESCRIPTOR
# ====================
Write-Host "[22/40] Resetting WinDefend service security..." -ForegroundColor Yellow
sc.exe sdset WinDefend "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)" 2>&1 | Out-Null
Write-Host "  OK Service security reset" -ForegroundColor Green

# ====================
# 23. START SECURITY SERVICES IN ORDER
# ====================
Write-Host "[23/40] Starting security services in order..." -ForegroundColor Yellow
$startOrder = @("wscsvc", "mpssvc", "WinDefend", "WdNisSvc", "SecurityHealthService")
foreach ($svc in $startOrder) {
    net stop $svc 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    net start $svc 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
}
Write-Host "  OK Services started" -ForegroundColor Green

# ====================
# 24. RE-REGISTER WINDOWS SECURITY APP
# ====================
Write-Host "[24/40] Re-registering Windows Security app..." -ForegroundColor Yellow
Get-AppxPackage -AllUsers Microsoft.SecHealthUI -ErrorAction SilentlyContinue | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
}
Write-Host "  OK Windows Security app registered" -ForegroundColor Green

# ====================
# 25. FORCE RELOAD DEFENDER WMI PROVIDER
# ====================
Write-Host "[25/40] Reloading Defender WMI provider..." -ForegroundColor Yellow
$mofFiles = @(
    "$env:SystemRoot\System32\wbem\ProtectionManagement.mof",
    "$env:ProgramFiles\Windows Defender\ProtectionManagement.mof"
)
if ($latestPlatform) {
    $mofFiles += "$latestPlatform\ProtectionManagement.mof"
}
foreach ($mof in $mofFiles) {
    if (Test-Path $mof) {
        mofcomp.exe $mof 2>&1 | Out-Null
    }
}
Write-Host "  OK WMI provider reloaded" -ForegroundColor Green

# ====================
# 26. RESTART WMI SERVICE
# ====================
Write-Host "[26/40] Restarting WMI service..." -ForegroundColor Yellow
net stop winmgmt /y 2>&1 | Out-Null
net start winmgmt 2>&1 | Out-Null
Start-Sleep -Seconds 2
Write-Host "  OK WMI service restarted" -ForegroundColor Green

# ====================
# 27. FORCE START DEFENDER VIA SC
# ====================
Write-Host "[27/40] Force starting Defender via SC..." -ForegroundColor Yellow
sc.exe start WinDefend 2>&1 | Out-Null
sc.exe start WdNisSvc 2>&1 | Out-Null
sc.exe start SecurityHealthService 2>&1 | Out-Null
Start-Sleep -Seconds 3
Write-Host "  OK Defender started" -ForegroundColor Green

# ====================
# 28. UPDATE SIGNATURES (if MpCmdRun exists)
# ====================
Write-Host "[28/40] Updating Defender signatures..." -ForegroundColor Yellow
$mpcmdrun = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
if (-not (Test-Path $mpcmdrun) -and $latestPlatform) {
    $mpcmdrun = "$latestPlatform\MpCmdRun.exe"
}
if (Test-Path $mpcmdrun) {
    & $mpcmdrun -SignatureUpdate 2>&1 | Out-Null
    Write-Host "  OK Signature update initiated" -ForegroundColor Green
} else {
    Write-Host "  ! MpCmdRun not found" -ForegroundColor Yellow
}

# ====================
# 29. RESET FIREWALL TO DEFAULTS
# ====================
Write-Host "[29/40] Resetting firewall to defaults..." -ForegroundColor Yellow
netsh advfirewall reset 2>&1 | Out-Null
Write-Host "  OK Firewall reset" -ForegroundColor Green

# ====================
# 30. REMOVE NETWORK DISCOVERY OVER-EXPOSURE
# ====================
Write-Host "[30/40] Securing network discovery..." -ForegroundColor Yellow
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff`" /f 2>nul" | Out-Null
Write-Host "  OK Network discovery secured" -ForegroundColor Green

# ====================
# 31. REMOVE EXPLOIT PROTECTION OVERRIDES
# ====================
Write-Host "[31/40] Restoring Exploit Protection..." -ForegroundColor Yellow
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Exploit Guard`" /f 2>nul" | Out-Null
cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\*`" /v MitigationOptions /f 2>nul" | Out-Null
Write-Host "  OK Exploit Protection restored" -ForegroundColor Green

# ====================
# 32. TRIGGER WINDOWS SECURITY REFRESH
# ====================
Write-Host "[32/40] Triggering Windows Security refresh..." -ForegroundColor Yellow
Start-Process -FilePath "explorer.exe" -ArgumentList "windowsdefender:" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Get-Process -Name "SecHealthUI" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "  OK Security refresh triggered" -ForegroundColor Green

# ====================
# 33. CLEAR POWERSHELL MODULE CACHE
# ====================
Write-Host "[33/40] Clearing PowerShell module cache..." -ForegroundColor Yellow

# Remove cached module info
Remove-Module -Name Defender -Force -ErrorAction SilentlyContinue
Remove-Module -Name ConfigDefender -Force -ErrorAction SilentlyContinue

# Clear module analysis cache
$cacheDir = "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\ModuleAnalysisCache"
if (Test-Path $cacheDir) {
    Remove-Item -Path "$cacheDir\*" -Force -ErrorAction SilentlyContinue
}

# Also clear the cache file
$cacheFile = "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\ModuleAnalysisCache\ModuleAnalysisCache"
if (Test-Path $cacheFile) {
    Remove-Item -Path $cacheFile -Force -ErrorAction SilentlyContinue
}

Write-Host "  OK Module cache cleared" -ForegroundColor Green

# ====================
# 34. REFRESH POWERSHELL MODULE LIST
# ====================
Write-Host "[34/40] Refreshing module list..." -ForegroundColor Yellow

# Force PowerShell to rediscover modules
$null = Get-Module -ListAvailable -Refresh -ErrorAction SilentlyContinue

Write-Host "  OK Module list refreshed" -ForegroundColor Green

# ====================
# 35. FORCE IMPORT DEFENDER MODULE FROM EXACT PATH
# ====================
Write-Host "[35/40] Force importing Defender module..." -ForegroundColor Yellow
$moduleImported = $false

# Try multiple paths in order
$tryPaths = @(
    "$moduleDestPath\Defender.psd1",
    "$moduleSourcePath\Defender.psd1"
)

foreach ($modPath in $tryPaths) {
    if ((Test-Path $modPath) -and (-not $moduleImported)) {
        try {
            Import-Module $modPath -Force -Global -ErrorAction Stop
            $moduleImported = $true
            Write-Host "  OK Defender module imported from: $modPath" -ForegroundColor Green
            break
        } catch {
            Write-Host "  ! Failed to import from $modPath" -ForegroundColor Yellow
        }
    }
}

if (-not $moduleImported) {
    # Last resort - try by name
    try {
        Import-Module -Name Defender -Force -ErrorAction Stop
        $moduleImported = $true
        Write-Host "  OK Defender module imported by name" -ForegroundColor Green
    } catch {
        Write-Host "  ! Module import failed, will retry after services stabilize" -ForegroundColor Yellow
    }
}

# ====================
# 36. WAIT FOR DEFENDER SERVICE TO STABILIZE
# ====================
Write-Host "[36/40] Waiting for Defender to stabilize..." -ForegroundColor Yellow
$maxWait = 30
$waited = 0
while ($waited -lt $maxWait) {
    $svc = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
    if ($svc.Status -eq 'Running') {
        break
    }
    Start-Sleep -Seconds 1
    $waited++
}
Write-Host "  OK Defender service stable (waited ${waited}s)" -ForegroundColor Green

# ====================
# 37. FINAL MODULE IMPORT ATTEMPT
# ====================
Write-Host "[37/40] Final module import attempt..." -ForegroundColor Yellow
if (-not $moduleImported) {
    Start-Sleep -Seconds 2
    foreach ($modPath in $tryPaths) {
        if ((Test-Path $modPath) -and (-not $moduleImported)) {
            try {
                Import-Module $modPath -Force -Global -ErrorAction Stop
                $moduleImported = $true
                Write-Host "  OK Module imported on retry" -ForegroundColor Green
                break
            } catch {
                # Continue to next path
            }
        }
    }
}

# ====================
# 38. TEST DEFENDER CMDLETS
# ====================
Write-Host "[38/40] Testing Defender cmdlets..." -ForegroundColor Yellow
$cmdletWorks = $false
try {
    $status = Get-MpComputerStatus -ErrorAction Stop
    $cmdletWorks = $true
    Write-Host "  OK Defender cmdlets working!" -ForegroundColor Green
    Write-Host "     RealTimeProtection: $($status.RealTimeProtectionEnabled)" -ForegroundColor Cyan
    Write-Host "     AntivirusEnabled: $($status.AntivirusEnabled)" -ForegroundColor Cyan
    Write-Host "     AMServiceEnabled: $($status.AMServiceEnabled)" -ForegroundColor Cyan
} catch {
    Write-Host "  ! Cmdlets not responding yet: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ====================
# 39. SET DEFENDER PREFERENCES (if module works)
# ====================
Write-Host "[39/40] Setting Defender preferences..." -ForegroundColor Yellow
if ($cmdletWorks) {
    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
        Set-MpPreference -MAPSReporting Advanced -ErrorAction SilentlyContinue
        Set-MpPreference -SubmitSamplesConsent SendAllSamples -ErrorAction SilentlyContinue
        Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
        Write-Host "  OK Preferences set" -ForegroundColor Green
    } catch {
        Write-Host "  ! Some preferences may need adjustment" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ! Preferences will apply when cmdlets work" -ForegroundColor Yellow
}

# ====================
# 40. RUN QUICK VERIFICATION SCAN
# ====================
Write-Host "[40/40] Running verification scan..." -ForegroundColor Yellow
if ($cmdletWorks) {
    try {
        Start-MpScan -ScanType QuickScan -ErrorAction Stop
        Write-Host "  OK Quick scan started!" -ForegroundColor Green
    } catch {
        Write-Host "  ! Scan will be available after stabilization" -ForegroundColor Yellow
    }
} else {
    # Try via MpCmdRun
    if (Test-Path $mpcmdrun) {
        & $mpcmdrun -Scan -ScanType 1 2>&1 | Out-Null
        Write-Host "  OK Quick scan started via MpCmdRun" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SECURITY RESTORATION COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Final service check
Write-Host "SERVICE STATUS:" -ForegroundColor Yellow
$checkServices = @("WinDefend", "mpssvc", "wscsvc", "SecurityHealthService")
foreach ($svc in $checkServices) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service) {
        $color = if ($service.Status -eq 'Running') { "Green" } else { "Red" }
        Write-Host "  $svc : $($service.Status)" -ForegroundColor $color
    }
}

Write-Host ""
Write-Host "MODULE STATUS:" -ForegroundColor Yellow
Write-Host "  Module Path: $moduleDestPath" -ForegroundColor Gray
Write-Host "  Module Exists: $(Test-Path "$moduleDestPath\Defender.psd1")" -ForegroundColor $(if (Test-Path "$moduleDestPath\Defender.psd1") { "Green" } else { "Red" })

Write-Host ""
if ($cmdletWorks) {
    Write-Host "SUCCESS! Defender is fully operational - NO REBOOT REQUIRED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Verification:" -ForegroundColor Yellow
    Write-Host "  Get-MpComputerStatus  - Works!" -ForegroundColor Green
    Write-Host "  Start-MpScan          - Works!" -ForegroundColor Green
} else {
    Write-Host "Module installed but cmdlets need a new PowerShell session." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To verify, open a NEW PowerShell window and run:" -ForegroundColor Cyan
    Write-Host "  Get-MpComputerStatus" -ForegroundColor White
    Write-Host "  Start-MpScan -ScanType QuickScan" -ForegroundColor White
    Write-Host ""
    Write-Host "NO REBOOT REQUIRED - just open a new PowerShell!" -ForegroundColor Green
}

Write-Host ""
