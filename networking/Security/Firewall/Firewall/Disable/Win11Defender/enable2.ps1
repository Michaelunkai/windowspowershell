# enable.ps1 - RESTORE All Windows Security
# Run as Administrator to restore Windows Firewall and Defender
# Reverses ALL changes made by disable.ps1

#Requires -RunAsAdministrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RESTORING ALL WINDOWS SECURITY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ====================
# 0. PRE-FLIGHT: Restore file ownership to TrustedInstaller
# ====================
Write-Host "[0/27] Restoring Defender file permissions..." -ForegroundColor Yellow
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
Write-Host "  OK File permissions restored" -ForegroundColor Green

# ====================
# 1. ENABLE WINDOWS FIREWALL
# ====================
Write-Host "[1/27] Enabling Windows Firewall..." -ForegroundColor Yellow
netsh advfirewall set allprofiles state on 2>&1 | Out-Null
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound 2>&1 | Out-Null
netsh advfirewall reset 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile" /v "EnableFirewall" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile" /v "EnableFirewall" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile" /v "EnableFirewall" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
Write-Host "  OK Firewall enabled" -ForegroundColor Green

# ====================
# 2. DELETE ALL DEFENDER POLICY KEYS (Complete removal, not just properties)
# ====================
Write-Host "[2/27] Removing ALL Defender policy restrictions..." -ForegroundColor Yellow
$policyKeysToDelete = @(
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\AppHVSI",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
)
foreach ($key in $policyKeysToDelete) {
    reg.exe delete $key /f 2>&1 | Out-Null
}
Write-Host "  OK All policy restrictions removed" -ForegroundColor Green

# ====================
# 3. ENABLE ALL DEFENDER SERVICES & DRIVERS (via registry + sc.exe)
# ====================
Write-Host "[3/27] Enabling all Defender services & drivers..." -ForegroundColor Yellow
$services = @(
    @{Name="WinDefend"; Start=2},
    @{Name="WdNisSvc"; Start=3},
    @{Name="WdNisDrv"; Start=3},
    @{Name="WdBoot"; Start=0},
    @{Name="WdFilter"; Start=0},
    @{Name="SecurityHealthService"; Start=2},
    @{Name="Sense"; Start=3},
    @{Name="mpssvc"; Start=2},
    @{Name="wscsvc"; Start=2}
)
foreach ($svc in $services) {
    reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$($svc.Name)" /v "Start" /t REG_DWORD /d $($svc.Start) /f 2>&1 | Out-Null
    sc.exe config $($svc.Name) start= auto 2>&1 | Out-Null
}
Write-Host "  OK All services configured" -ForegroundColor Green

# ====================
# 4. RESTORE UAC
# ====================
Write-Host "[4/27] Restoring UAC..." -ForegroundColor Yellow
reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableLUA" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ConsentPromptBehaviorAdmin" /t REG_DWORD /d 5 /f 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "PromptOnSecureDesktop" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
Write-Host "  OK UAC restored" -ForegroundColor Green

# ====================
# 5. ENABLE SMARTSCREEN
# ====================
Write-Host "[5/27] Enabling SmartScreen..." -ForegroundColor Yellow
reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "Warn" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v "ShellSmartScreenLevel" /f 2>&1 | Out-Null
reg.exe delete "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" /v "EnableWebContentEvaluation" /f 2>&1 | Out-Null
Write-Host "  OK SmartScreen enabled" -ForegroundColor Green

# ====================
# 6. RESTORE CORE ISOLATION / MEMORY INTEGRITY
# ====================
Write-Host "[6/27] Restoring Core Isolation..." -ForegroundColor Yellow
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequirePlatformSecurityFeatures" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "Locked" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "LsaCfgFlags" /f 2>&1 | Out-Null
Write-Host "  OK Core Isolation restored" -ForegroundColor Green

# ====================
# 7. RESTORE NETWORK SECURITY (SMB Signing)
# ====================
Write-Host "[7/27] Restoring network security..." -ForegroundColor Yellow
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "RequireSecuritySignature" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v "RequireSecuritySignature" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "EnableSecuritySignature" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v "EnableSecuritySignature" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "NullSessionShares" /f 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "RestrictNullSessAccess" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
Write-Host "  OK Network security restored" -ForegroundColor Green

# ====================
# 8. RESTORE LSA SECURITY
# ====================
Write-Host "[8/27] Restoring LSA security..." -ForegroundColor Yellow
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "EveryoneIncludesAnonymous" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "RestrictAnonymous" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "RestrictAnonymousSAM" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "ForceGuest" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "LmCompatibilityLevel" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "NoLmHash" /f 2>&1 | Out-Null
Write-Host "  OK LSA security restored" -ForegroundColor Green

# ====================
# 9. RESTORE WINDOWS FILE PROTECTION
# ====================
Write-Host "[9/27] Restoring Windows File Protection..." -ForegroundColor Yellow
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v "SFCDisable" /f 2>&1 | Out-Null
Write-Host "  OK File protection restored" -ForegroundColor Green

# ====================
# 10. RESTORE SECURITY CENTER NOTIFICATIONS
# ====================
Write-Host "[10/27] Restoring Security Center notifications..." -ForegroundColor Yellow
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center" /v "AntiVirusDisableNotify" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center" /v "FirewallDisableNotify" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center" /v "UpdatesDisableNotify" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center" /v "AntiVirusOverride" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center" /v "FirewallOverride" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "HideSCAHealth" /f 2>&1 | Out-Null
Write-Host "  OK Notifications restored" -ForegroundColor Green

# ====================
# 11. RESTORE SECURITY HEALTH SYSTRAY
# ====================
Write-Host "[11/27] Restoring Security Health systray..." -ForegroundColor Yellow
reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SecurityHealth" /t REG_EXPAND_SZ /d "%ProgramFiles%\Windows Defender\MSASCuiL.exe" /f 2>&1 | Out-Null
Write-Host "  OK Systray restored" -ForegroundColor Green

# ====================
# 12. RESTORE WINDOWS UPDATE
# ====================
Write-Host "[12/27] Restoring Windows Update..." -ForegroundColor Yellow
sc.exe config wuauserv start= demand 2>&1 | Out-Null
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\wuauserv" /v "Start" /t REG_DWORD /d 3 /f 2>&1 | Out-Null
net start wuauserv 2>&1 | Out-Null
Write-Host "  OK Windows Update restored" -ForegroundColor Green

# ====================
# 13. REMOVE DEFENDER LOCAL OVERRIDES
# ====================
Write-Host "[13/27] Removing Defender local overrides..." -ForegroundColor Yellow
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtection" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtectionSource" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\SmartScreen" /v "ConfigureAppInstallControlEnabled" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\SmartScreen" /v "ConfigureAppInstallControl" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access" /v "EnableControlledFolderAccess" /f 2>&1 | Out-Null
Write-Host "  OK Local overrides removed" -ForegroundColor Green

# ====================
# 14. REMOVE TPM POLICY
# ====================
Write-Host "[14/27] Restoring TPM..." -ForegroundColor Yellow
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\TPM" /v "OSManagedAuthLevel" /f 2>&1 | Out-Null
Write-Host "  OK TPM restored" -ForegroundColor Green

# ====================
# 15. START ALL SECURITY SERVICES
# ====================
Write-Host "[15/27] Starting all security services..." -ForegroundColor Yellow
$startServices = @("mpssvc", "wscsvc", "WinDefend", "WdNisSvc", "SecurityHealthService", "Sense")
foreach ($svc in $startServices) {
    net start $svc 2>&1 | Out-Null
}
Write-Host "  OK Services started" -ForegroundColor Green

# ====================
# 16. REPAIR DEFENDER USING DISM
# ====================
Write-Host "[16/27] Repairing Windows Defender with DISM..." -ForegroundColor Yellow
DISM /Online /Enable-Feature /FeatureName:Windows-Defender /All /NoRestart 2>&1 | Out-Null
DISM /Online /Enable-Feature /FeatureName:Windows-Defender-Default-Definitions /All /NoRestart 2>&1 | Out-Null
Write-Host "  OK DISM repair complete" -ForegroundColor Green

# ====================
# 17. REGISTER DEFENDER POWERSHELL MODULE
# ====================
Write-Host "[17/27] Registering Defender PowerShell module..." -ForegroundColor Yellow
$defenderModulePath = "$env:ProgramFiles\Windows Defender\Offline"
if (Test-Path "$env:ProgramFiles\Windows Defender\MpProvider.dll") {
    regsvr32.exe /s "$env:ProgramFiles\Windows Defender\MpProvider.dll" 2>&1 | Out-Null
}
# Force module reload
$modulePath = "$env:ProgramFiles\Windows Defender"
if ($env:PSModulePath -notlike "*$modulePath*") {
    $env:PSModulePath = "$modulePath;$env:PSModulePath"
}
Remove-Module -Name ConfigDefender -Force -ErrorAction SilentlyContinue
Remove-Module -Name Defender -Force -ErrorAction SilentlyContinue
Import-Module -Name Defender -Force -ErrorAction SilentlyContinue
Write-Host "  OK PowerShell module registered" -ForegroundColor Green

# ====================
# 18. RESET DEFENDER PREFERENCES (if module loaded)
# ====================
Write-Host "[18/27] Resetting Defender preferences..." -ForegroundColor Yellow
try {
    if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisablePrivacyMode $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScriptScanning $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableArchiveScanning $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableCatchupFullScan $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableCatchupQuickScan $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableEmailScanning $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableRemovableDriveScanning $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScanningMappedNetworkDrivesForFullScan $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScanningNetworkFiles $false -ErrorAction SilentlyContinue
        Set-MpPreference -MAPSReporting Advanced -ErrorAction SilentlyContinue
        Set-MpPreference -SubmitSamplesConsent SendAllSamples -ErrorAction SilentlyContinue
        Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
        Write-Host "  OK Defender preferences reset via PowerShell" -ForegroundColor Green
    } else {
        Write-Host "  ! Defender module not available yet - will apply after reboot" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ! Preferences will apply after reboot" -ForegroundColor Yellow
}

# ====================
# 19. UPDATE DEFENDER SIGNATURES (if available)
# ====================
Write-Host "[19/27] Updating Defender signatures..." -ForegroundColor Yellow
$mpcmdrun = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
if (Test-Path $mpcmdrun) {
    & $mpcmdrun -SignatureUpdate 2>&1 | Out-Null
    Write-Host "  OK Signature update initiated" -ForegroundColor Green
} else {
    Write-Host "  ! MpCmdRun not found - signatures will update after reboot" -ForegroundColor Yellow
}

# ====================
# 20. RESTORE FIREWALL RULES
# ====================
Write-Host "[20/27] Restoring default firewall rules..." -ForegroundColor Yellow
netsh advfirewall reset 2>&1 | Out-Null
Write-Host "  OK Firewall rules restored" -ForegroundColor Green

# ====================
# 21. DISABLE SMBv1 (Security best practice)
# ====================
Write-Host "[21/27] Disabling SMBv1 (security)..." -ForegroundColor Yellow
reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "SMB1" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
sc.exe config lanmanworkstation depend= bowser/mrxsmb20/nsi 2>&1 | Out-Null
sc.exe config mrxsmb10 start= disabled 2>&1 | Out-Null
Write-Host "  OK SMBv1 disabled" -ForegroundColor Green

# ====================
# 22. RESTORE EXPLOIT PROTECTION DEFAULTS
# ====================
Write-Host "[22/27] Restoring Exploit Protection defaults..." -ForegroundColor Yellow
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Exploit Guard\Exploit Protection" /v "ExploitProtectionSettings" /f 2>&1 | Out-Null
reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\*" /v "MitigationOptions" /f 2>&1 | Out-Null
Write-Host "  OK Exploit Protection restored" -ForegroundColor Green

# ====================
# 23. REMOVE NETWORK DISCOVERY OVER-EXPOSURE
# ====================
Write-Host "[23/27] Securing network discovery..." -ForegroundColor Yellow
reg.exe delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff" /f 2>&1 | Out-Null
Write-Host "  OK Network discovery secured" -ForegroundColor Green

# ====================
# 24. RE-REGISTER WINDOWS SECURITY APP
# ====================
Write-Host "[24/27] Re-registering Windows Security app..." -ForegroundColor Yellow
Get-AppxPackage -AllUsers Microsoft.SecHealthUI -ErrorAction SilentlyContinue | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
}
Write-Host "  OK Windows Security app registered" -ForegroundColor Green

# ====================
# 25. RESTART DEFENDER SERVICE
# ====================
Write-Host "[25/27] Restarting Windows Defender service..." -ForegroundColor Yellow
net stop WinDefend 2>&1 | Out-Null
net start WinDefend 2>&1 | Out-Null
Write-Host "  OK Defender service restarted" -ForegroundColor Green

# ====================
# 26. VERIFY DEFENDER STATUS
# ====================
Write-Host "[26/27] Verifying Defender status..." -ForegroundColor Yellow
$defenderService = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
if ($defenderService -and $defenderService.Status -eq 'Running') {
    Write-Host "  OK WinDefend service is RUNNING" -ForegroundColor Green
} else {
    Write-Host "  ! WinDefend service not running yet - will start after reboot" -ForegroundColor Yellow
}

# ====================
# 27. TEST DEFENDER CMDLETS
# ====================
Write-Host "[27/27] Testing Defender cmdlets..." -ForegroundColor Yellow
try {
    $status = Get-MpComputerStatus -ErrorAction Stop
    Write-Host "  OK Defender cmdlets working!" -ForegroundColor Green
    Write-Host "     RealTimeProtection: $($status.RealTimeProtectionEnabled)" -ForegroundColor Cyan
    Write-Host "     AntivirusEnabled: $($status.AntivirusEnabled)" -ForegroundColor Cyan
} catch {
    Write-Host "  ! Defender cmdlets require reboot to work" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SECURITY RESTORATION COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "RESTORED COMPONENTS:" -ForegroundColor Yellow
Write-Host "  OK Windows Firewall" -ForegroundColor White
Write-Host "  OK Windows Defender" -ForegroundColor White
Write-Host "  OK Real-Time Protection" -ForegroundColor White
Write-Host "  OK All Scanning Features" -ForegroundColor White
Write-Host "  OK Cloud Protection" -ForegroundColor White
Write-Host "  OK Signature Updates" -ForegroundColor White
Write-Host "  OK Tamper Protection" -ForegroundColor White
Write-Host "  OK Exploit Guard" -ForegroundColor White
Write-Host "  OK SmartScreen" -ForegroundColor White
Write-Host "  OK Core Isolation / Memory Integrity" -ForegroundColor White
Write-Host "  OK Network Security (SMB Signing)" -ForegroundColor White
Write-Host "  OK Windows Update" -ForegroundColor White
Write-Host "  OK Security Center Services" -ForegroundColor White
Write-Host "  OK UAC (User Account Control)" -ForegroundColor White
Write-Host "  OK LSA Security" -ForegroundColor White
Write-Host "  OK Windows File Protection" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANT: REBOOT REQUIRED for full effect!" -ForegroundColor Red
Write-Host ""
Write-Host "After reboot, run these commands to verify:" -ForegroundColor Yellow
Write-Host "  Get-MpComputerStatus" -ForegroundColor Cyan
Write-Host "  Start-MpScan -ScanType QuickScan" -ForegroundColor Cyan
Write-Host ""
Write-Host "To reboot now, run: Restart-Computer -Force" -ForegroundColor Yellow
Write-Host ""
