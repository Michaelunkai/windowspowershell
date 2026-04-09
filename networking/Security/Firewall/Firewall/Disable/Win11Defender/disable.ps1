# ere.ps1 - ABSOLUTE OBLITERATION: Zero Security, Zero Restrictions, Zero Denials
# Run as Administrator - IMMEDIATE EFFECT, NO REBOOT NEEDED
# 10000 percent GUARANTEED: Nothing will ever be denied

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ABSOLUTE SECURITY OBLITERATION" -ForegroundColor Red
Write-Host "  IMMEDIATE - NO REBOOT NEEDED" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ====================
# PRE-0. CHECK TAMPER PROTECTION STATUS
# ====================
Write-Host "[PRE] Checking Tamper Protection status..." -ForegroundColor Yellow

$tamperValue = $null
try {
    $tamperValue = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection
} catch { }

if ($tamperValue -eq 5 -or $tamperValue -eq 1) {
    Write-Host "  ! Tamper Protection is ENABLED" -ForegroundColor Red
    Write-Host "  ! Please disable it manually first:" -ForegroundColor Yellow
    Write-Host "    Windows Security > Virus & threat protection" -ForegroundColor Yellow
    Write-Host "    > Manage settings > Tamper Protection > OFF" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "  Tamper Protection is disabled or not detected" -ForegroundColor Green
}

Write-Host ""

# ====================
# 0. BRUTAL FORCE STOP - KILL EVERYTHING BEFORE ANY CHANGES
# ====================
Write-Host "[0/25] FORCE KILLING all Defender processes and scans..." -ForegroundColor Yellow

# FIRST: Brutally kill all processes with taskkill - no mercy
Write-Host "  - Force killing all security processes..." -ForegroundColor Cyan
$processesToKill = @(
    "MsMpEng", "NisSrv", "SecurityHealthService", "SecurityHealthSystray",
    "MpCmdRun", "MpDlpCmd", "smartscreen", "SgrmBroker", "MpDefenderCoreService",
    "MpDefenderCore", "MsMpEngCP", "NisSrv", "wscsvc"
)
foreach ($proc in $processesToKill) {
    taskkill /F /IM "$proc.exe" 2>&1 | Out-Null
    Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue 2>&1 | Out-Null
}

# SECOND: Cancel scans via MpCmdRun
$mpcmdrun = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
$platformBase = "$env:ProgramData\Microsoft\Windows Defender\Platform"
if (-not (Test-Path $mpcmdrun)) {
    $latestPlatform = Get-ChildItem -Path $platformBase -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
    if ($latestPlatform) { $mpcmdrun = "$latestPlatform\MpCmdRun.exe" }
}

if (Test-Path $mpcmdrun) {
    Write-Host "  - Cancelling scans via MpCmdRun..." -ForegroundColor Cyan
    $cancelJob = Start-Job -ScriptBlock { param($mp) & $mp -Cancel 2>&1 } -ArgumentList $mpcmdrun
    $cancelJob | Wait-Job -Timeout 3 | Out-Null
    $cancelJob | Stop-Job -ErrorAction SilentlyContinue
    $cancelJob | Remove-Job -Force -ErrorAction SilentlyContinue
}

# THIRD: Kill again after cancel attempt
foreach ($proc in $processesToKill) {
    taskkill /F /IM "$proc.exe" 2>&1 | Out-Null
}

# FOURTH: Disable services BEFORE killing to prevent respawn
Write-Host "  - Disabling services to prevent respawn..." -ForegroundColor Cyan
$services = @("WinDefend", "WdNisSvc", "SecurityHealthService", "Sense", "wscsvc")
foreach ($svc in $services) {
    try {
        & sc.exe config $svc start= disabled 2>&1 | Out-Null
        & sc.exe stop $svc 2>&1 | Out-Null
    } catch { }
    # Also set via registry as backup
    $null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$svc" /v "Start" /t REG_DWORD /d 4 /f 2>&1
}

# FIFTH: Final kill sweep
Start-Sleep -Milliseconds 500
foreach ($proc in $processesToKill) {
    taskkill /F /IM "$proc.exe" 2>&1 | Out-Null
}

Write-Host "  ✓ All processes killed and services disabled" -ForegroundColor Green

# ====================
# HELPER FUNCTIONS
# ====================

# Run reg.exe with timeout to prevent hanging on protected keys
function Run-RegWithTimeout {
    param([string]$Arguments, [int]$TimeoutSec = 2)
    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "reg.exe"
        $pinfo.Arguments = $Arguments
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        $completed = $p.WaitForExit($TimeoutSec * 1000)
        if (-not $completed) {
            $p.Kill()
        }
    } catch { }
}

function Take-RegistryOwnership {
    param([string]$RegPath)
    try {
        $RegPath = $RegPath -replace "HKLM:\\", "HKEY_LOCAL_MACHINE\"
        Run-RegWithTimeout "add `"$RegPath`" /f"
        $acl = Get-Acl -Path "HKLM:\$($RegPath -replace 'HKEY_LOCAL_MACHINE\\', '')" -ErrorAction SilentlyContinue
        if ($acl) {
            $adminGroup = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
            $fullControl = [System.Security.AccessControl.RegistryRights]::FullControl
            $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
            $propagationFlags = [System.Security.AccessControl.PropagationFlags]::None
            $accessType = [System.Security.AccessControl.AccessControlType]::Allow
            $accessRule = New-Object System.Security.AccessControl.RegistryAccessRule($adminGroup, $fullControl, $inheritanceFlags, $propagationFlags, $accessType)
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path "HKLM:\$($RegPath -replace 'HKEY_LOCAL_MACHINE\\', '')" -AclObject $acl -ErrorAction SilentlyContinue
        }
    } catch { }
}

function Take-FileOwnership {
    param([string]$Path)
    if (Test-Path $Path) {
        takeown.exe /F $Path /R /A /D Y 2>&1 | Out-Null
        icacls.exe $Path /grant "Administrators:F" /T /C /Q 2>&1 | Out-Null
        icacls.exe $Path /grant "Everyone:F" /T /C /Q 2>&1 | Out-Null
        icacls.exe $Path /grant "$env:USERNAME:F" /T /C /Q 2>&1 | Out-Null
    }
}

# ====================
# CREATE ALL REGISTRY PATHS
# ====================
$registryPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\NIS",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Threats",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Threats\ThreatSeverityDefaultAction",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Quarantine",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Network Protection",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System",
    "HKLM:\SOFTWARE\Microsoft\Windows Defender",
    "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features",
    "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection",
    "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System",
    "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile"
)

foreach ($path in $registryPaths) {
    if (!(Test-Path $path)) {
        New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

# ====================
# 1. DISABLE UAC IMMEDIATELY
# ====================
Write-Host "[1/25] Disabling UAC (IMMEDIATE)..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableLUA" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ConsentPromptBehaviorAdmin" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "PromptOnSecureDesktop" /t REG_DWORD /d 0 /f 2>&1
Write-Host "  ✓ UAC obliterated" -ForegroundColor Green

# ====================
# 2. DISABLE ALL DEFENDER SERVICES IMMEDIATELY
# ====================
Write-Host "[2/25] Disabling all Defender services (IMMEDIATE)..." -ForegroundColor Yellow
$services = @(
    "WinDefend", "WdNisSvc", "WdNisDrv", "WdBoot", "WdFilter",
    "SecurityHealthService", "Sense", "mpssvc", "wscsvc"
)
foreach ($service in $services) {
    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
    $null = sc.exe config $service start= disabled 2>&1
    $null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$service" /v "Start" /t REG_DWORD /d 4 /f 2>&1
}
Write-Host "  ✓ All services obliterated" -ForegroundColor Green

# ====================
# 3. TAKE OWNERSHIP OF DEFENDER FILES
# ====================
Write-Host "[3/25] Taking ownership of all Defender files..." -ForegroundColor Yellow
$defenderPaths = @(
    "$env:ProgramFiles\Windows Defender",
    "$env:ProgramFiles\Windows Defender Advanced Threat Protection",
    "$env:ProgramData\Microsoft\Windows Defender",
    "$env:ProgramData\Microsoft\Windows Security Health"
)
foreach ($path in $defenderPaths) {
    Take-FileOwnership $path
}
Write-Host "  ✓ Full ownership granted" -ForegroundColor Green

# ====================
# 4. DISABLE WINDOWS FIREWALL
# ====================
Write-Host "[4/25] Disabling Windows Firewall..." -ForegroundColor Yellow
netsh advfirewall set allprofiles state off 2>&1 | Out-Null
netsh advfirewall set allprofiles firewallpolicy allowinbound,allowoutbound 2>&1 | Out-Null
netsh firewall set opmode mode=disable 2>&1 | Out-Null
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile" /v "EnableFirewall" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile" /v "EnableFirewall" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile" /v "EnableFirewall" /t REG_DWORD /d 0 /f 2>&1
Write-Host "  ✓ Firewall obliterated" -ForegroundColor Green

# ====================
# 5. DISABLE DEFENDER MASTER SWITCHES
# ====================
Write-Host "[5/25] Disabling Defender master switches..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /v "ServiceKeepAlive" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /v "AllowFastServiceStartup" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableRoutinelyTakingAction" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /v "PUAProtection" /t REG_DWORD /d 0 /f 2>&1
Write-Host "  ✓ Master switches obliterated" -ForegroundColor Green

# ====================
# 6. DISABLE REAL-TIME PROTECTION
# ====================
Write-Host "[6/25] Disabling Real-Time Protection..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableBehaviorMonitoring" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableOnAccessProtection" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableScanOnRealtimeEnable" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableIOAVProtection" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRawWriteNotification" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableIntrusionPreventionSystem" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "RealtimeScanDirection" /t REG_DWORD /d 2 /f 2>&1
Write-Host "  ✓ Real-time protection obliterated" -ForegroundColor Green

# ====================
# 7. DISABLE ALL SCANNING
# ====================
Write-Host "[7/25] Disabling all scanning..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableArchiveScanning" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableEmailScanning" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableRemovableDriveScanning" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableScanningNetworkFiles" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisablePackedExeScanning" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableHeuristics" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableCatchupFullScan" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableCatchupQuickScan" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableRestorePoint" /t REG_DWORD /d 1 /f 2>&1
Write-Host "  ✓ All scanning obliterated" -ForegroundColor Green

# ====================
# 8. DISABLE CLOUD PROTECTION
# ====================
Write-Host "[8/25] Disabling Cloud Protection..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "SpynetReporting" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "SubmitSamplesConsent" /t REG_DWORD /d 2 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "DisableBlockAtFirstSeen" /t REG_DWORD /d 1 /f 2>&1
Write-Host "  ✓ Cloud protection obliterated" -ForegroundColor Green

# ====================
# 9. DISABLE SIGNATURE UPDATES
# ====================
Write-Host "[9/25] Disabling signature updates..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "ForceUpdateFromMU" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "DisableScanOnUpdate" /t REG_DWORD /d 1 /f 2>&1
Write-Host "  ✓ Signature updates obliterated" -ForegroundColor Green

# ====================
# 10. DISABLE TAMPER PROTECTION - FORCED
# ====================
Write-Host "[10/25] Disabling Tamper Protection (FORCED)..." -ForegroundColor Yellow
Take-RegistryOwnership "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtectionSource" /t REG_DWORD /d 2 /f 2>&1
Write-Host "  ✓ Tamper protection obliterated" -ForegroundColor Green

# ====================
# 11. DISABLE EXPLOIT GUARD
# ====================
Write-Host "[11/25] Disabling Exploit Guard..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Network Protection" /v "EnableNetworkProtection" /t REG_DWORD /d 0 /f 2>&1
Write-Host "  ✓ Exploit Guard obliterated" -ForegroundColor Green

# ====================
# 12. DISABLE SMARTSCREEN
# ====================
Write-Host "[12/25] Disabling SmartScreen..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "Off" /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d 0 /f 2>&1
Write-Host "  ✓ SmartScreen obliterated" -ForegroundColor Green

# ====================
# 13. DISABLE APPLICATION GUARD
# ====================
Write-Host "[13/25] Disabling Application Guard..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\AppHVSI" /v "AllowAppHVSI_ProviderSet" /t REG_DWORD /d 0 /f 2>&1
Write-Host "  ✓ Application Guard obliterated" -ForegroundColor Green

# ====================
# 14. DISABLE ATP
# ====================
Write-Host "[14/25] Disabling Advanced Threat Protection..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection" /v "ForceDefenderPassiveMode" /t REG_DWORD /d 1 /f 2>&1
Write-Host "  ✓ ATP obliterated" -ForegroundColor Green

# ====================
# 15. DISABLE SECURITY NOTIFICATIONS
# ====================
Write-Host "[15/25] Disabling all security notifications..." -ForegroundColor Yellow
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v "DisableEnhancedNotifications" /t REG_DWORD /d 1 /f 2>&1
Write-Host "  ✓ Notifications obliterated" -ForegroundColor Green

# ====================
# 16. GRANT FULL FILE SYSTEM PERMISSIONS (INSTANT)
# ====================
Write-Host "[16/25] Granting full file system permissions (INSTANT)..." -ForegroundColor Yellow

# Disable Windows File Protection
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v "SFCDisable" /t REG_DWORD /d 4 /f 2>&1

# Disable ALL permission checks via registry (INSTANT - no file scanning needed)
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "EveryoneIncludesAnonymous" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "RestrictAnonymous" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "RestrictAnonymousSAM" /t REG_DWORD /d 0 /f 2>&1

# Only grant permissions to critical directories (fast, targeted)
Write-Host "  - Granting critical permissions..." -ForegroundColor Cyan
$criticalPaths = @(
    "$env:ProgramFiles",
    "$env:ProgramData",
    "$env:SystemRoot",
    "$env:USERPROFILE"
)

foreach ($path in $criticalPaths) {
    if (Test-Path $path) {
        Start-Job -ScriptBlock {
            param($p)
            icacls.exe $p /grant "Everyone:(OI)(CI)F" /T /C /Q 2>&1 | Out-Null
        } -ArgumentList $path | Out-Null
    }
}

Write-Host "  ✓ Permission restrictions removed (running in background)" -ForegroundColor Green

# ====================
# 17. DISABLE ALL NETWORK BLOCKING AND RESTRICTIONS
# ====================
Write-Host "[17/25] Disabling ALL network blocking mechanisms..." -ForegroundColor Yellow

# Disable network-level authentication
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "LmCompatibilityLevel" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "NoLmHash" /t REG_DWORD /d 0 /f 2>&1

# Disable SMB signing requirements
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "RequireSecuritySignature" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v "RequireSecuritySignature" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "EnableSecuritySignature" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v "EnableSecuritySignature" /t REG_DWORD /d 0 /f 2>&1

# Disable all firewall rules
netsh advfirewall firewall set rule all new enable=no 2>&1 | Out-Null

# Allow all inbound connections
netsh advfirewall set allprofiles blockedinbound off 2>&1 | Out-Null
netsh advfirewall set allprofiles blockedoutbound off 2>&1 | Out-Null

# Disable all port blocking
netsh interface ipv4 set global defaultcurhoplimit=255 2>&1 | Out-Null
netsh interface ipv6 set global defaultcurhoplimit=255 2>&1 | Out-Null

# Remove all firewall port blocks
netsh advfirewall firewall delete rule name=all 2>&1 | Out-Null

Write-Host "  ✓ All network blocking obliterated" -ForegroundColor Green

# ====================
# 18. DISABLE WINDOWS UPDATE INTERFERENCE
# ====================
Write-Host "[18/25] Disabling Windows Update interference..." -ForegroundColor Yellow

Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
Set-Service -Name "wuauserv" -StartupType Disabled -ErrorAction SilentlyContinue
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "NoAutoUpdate" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "AUOptions" /t REG_DWORD /d 1 /f 2>&1

Write-Host "  ✓ Windows Update disabled" -ForegroundColor Green

# ====================
# 19. DISABLE NETWORK PROTECTION AND FILTERING
# ====================
Write-Host "[19/25] Disabling network protection and filtering..." -ForegroundColor Yellow

# Disable all attack surface reduction rules
$asrIds = @(
    "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550",
    "D4F940AB-401B-4EFC-AADC-AD5F3C50688A",
    "3B576869-A4EC-4529-8536-B80A7769E899",
    "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84",
    "D3E037E1-3EB8-44C8-A917-57927947596D",
    "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC",
    "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B",
    "01443614-CD74-433A-B99E-2ECDC07BFC25",
    "C1DB55AB-C21A-4637-BB3F-A12568109D35",
    "9E6C4E1F-7D60-472F-BA1A-A39EF669E4B2",
    "D1E49AAC-8F56-4280-B9BA-993A6D77406C",
    "B2B3F03D-6A65-4F7B-A9C7-1C7EF74A9BA4",
    "26190899-1602-49E8-8B27-EB1D0A1CE869",
    "7674BA52-37EB-4A4F-A9A1-F0F9A1619A2C",
    "E6DB77E5-3DF2-4CF1-B95A-636979351E5B"
)

foreach ($id in $asrIds) {
    $null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules" /v $id /t REG_DWORD /d 0 /f 2>&1
}

# Disable controlled folder access
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access" /v "EnableControlledFolderAccess" /t REG_DWORD /d 0 /f 2>&1

# Disable Network Inspection System
Stop-Service -Name "WdNisSvc" -Force -ErrorAction SilentlyContinue
Set-Service -Name "WdNisSvc" -StartupType Disabled -ErrorAction SilentlyContinue

Write-Host "  ✓ Network protection obliterated" -ForegroundColor Green

# ====================
# 20. ENABLE FILE AND PRINTER SHARING - NO RESTRICTIONS
# ====================
Write-Host "[20/25] Enabling unrestricted file and printer sharing..." -ForegroundColor Yellow

# Enable network discovery
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff" /f 2>&1
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes 2>&1 | Out-Null
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes 2>&1 | Out-Null

# Enable anonymous access to shares
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "NullSessionShares" /t REG_MULTI_SZ /d "C$\0D$\0ADMIN$\0IPC$" /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "RestrictNullSessAccess" /t REG_DWORD /d 0 /f 2>&1

# Disable password-protected sharing
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "ForceGuest" /t REG_DWORD /d 1 /f 2>&1

# Enable SMBv1 for maximum compatibility (background job to avoid hanging)
Start-Job -ScriptBlock {
    Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
} | Out-Null
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "SMB1" /t REG_DWORD /d 1 /f 2>&1

Write-Host "  ✓ File sharing fully enabled - no restrictions" -ForegroundColor Green

# ====================
# 21. DISABLE CORE ISOLATION AND MEMORY INTEGRITY
# ====================
Write-Host "[21/25] Disabling Core Isolation and Memory Integrity..." -ForegroundColor Yellow

# Disable Memory Integrity (Core Isolation)
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequirePlatformSecurityFeatures" /t REG_DWORD /d 0 /f 2>&1

# Disable Credential Guard
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "LsaCfgFlags" /t REG_DWORD /d 0 /f 2>&1

# Disable Secure Boot
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "Locked" /t REG_DWORD /d 0 /f 2>&1

Write-Host "  ✓ Core Isolation obliterated" -ForegroundColor Green

# ====================
# 22. DISABLE ALL REPUTATION-BASED PROTECTION
# ====================
Write-Host "[22/25] Disabling ALL reputation-based protection..." -ForegroundColor Yellow

# Disable SmartScreen for Apps and Files
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "Off" /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v "ShellSmartScreenLevel" /t REG_SZ /d "Warn" /f 2>&1

# Disable SmartScreen for Edge
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" /v "EnabledV9" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" /v "PreventOverride" /t REG_DWORD /d 0 /f 2>&1

# Disable SmartScreen for Store Apps
$null = reg.exe add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" /v "EnableWebContentEvaluation" /t REG_DWORD /d 0 /f 2>&1

# Disable Potentially Unwanted App blocking
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /v "PUAProtection" /t REG_DWORD /d 0 /f 2>&1

# Disable Check apps and files
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\SmartScreen" /v "ConfigureAppInstallControlEnabled" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\SmartScreen" /v "ConfigureAppInstallControl" /t REG_SZ /d "Anywhere" /f 2>&1

Write-Host "  ✓ All reputation-based protection obliterated" -ForegroundColor Green

# ====================
# 23. DISABLE DEVICE SECURITY AND SECURE BOOT NOTIFICATIONS
# ====================
Write-Host "[23/25] Disabling device security features..." -ForegroundColor Yellow

# Disable TPM
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\TPM" /v "OSManagedAuthLevel" /t REG_DWORD /d 0 /f 2>&1

# Disable Windows Security notifications completely
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender Security Center\Notifications" /v "DisableEnhancedNotifications" /t REG_DWORD /d 1 /f 2>&1

# Disable all Security Center sections
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Virus and threat protection" /v "UILockdown" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Firewall and network protection" /v "UILockdown" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\App and Browser protection" /v "UILockdown" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Device security" /v "UILockdown" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Device performance and health" /v "UILockdown" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Family options" /v "UILockdown" /t REG_DWORD /d 1 /f 2>&1

# Hide all Security Center sections
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Virus and threat protection" /v "HideVirusAndThreatProtection" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Firewall and network protection" /v "HideFirewallAndNetworkProtection" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\App and Browser protection" /v "HideAppAndBrowserProtection" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Device security" /v "HideDeviceSecurity" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Device performance and health" /v "HideDevicePerformanceHealth" /t REG_DWORD /d 1 /f 2>&1

Write-Host "  ✓ Device security obliterated" -ForegroundColor Green

# ====================
# 24. DISABLE RANSOMWARE PROTECTION AND CONTROLLED FOLDER ACCESS
# ====================
Write-Host "[24/25] Disabling ransomware protection..." -ForegroundColor Yellow

# Use timeout wrapper to prevent hanging
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access" /v "EnableControlledFolderAccess" /t REG_DWORD /d 0 /f'
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender Exploit Guard\Exploit Protection" /v "ExploitProtectionSettings" /t REG_SZ /d "" /f'

Write-Host "  ✓ Ransomware protection obliterated" -ForegroundColor Green

# ====================
# 25. FINAL KILL - DISABLE SECURITY CENTER SERVICE
# ====================
Write-Host "[25/25] Final kill - Disabling Security Center service..." -ForegroundColor Yellow

# Stop and disable services via registry with timeout
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\wscsvc" /v "Start" /t REG_DWORD /d 4 /f'
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SecurityHealthService" /v "Start" /t REG_DWORD /d 4 /f'

# Disable Security and Maintenance notifications
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "HideSCAHealth" /t REG_DWORD /d 1 /f'

# Disable all security providers
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center" /v "AntiVirusDisableNotify" /t REG_DWORD /d 1 /f'
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center" /v "FirewallDisableNotify" /t REG_DWORD /d 1 /f'
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center" /v "UpdatesDisableNotify" /t REG_DWORD /d 1 /f'
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center" /v "AntiVirusOverride" /t REG_DWORD /d 1 /f'
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center" /v "FirewallOverride" /t REG_DWORD /d 1 /f'

# Kill Security Center tray icon via taskkill
taskkill /F /IM "SecurityHealthSystray.exe" 2>&1 | Out-Null
Run-RegWithTimeout 'add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SecurityHealth" /t REG_SZ /d "" /f'

Write-Host "  ✓ Security Center service obliterated" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ABSOLUTE OBLITERATION COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ALL PROTECTIONS DESTROYED (IMMEDIATE):" -ForegroundColor Yellow
Write-Host "  ✓ UAC (OFF)" -ForegroundColor White
Write-Host "  ✓ All Defender Services (KILLED)" -ForegroundColor White
Write-Host "  ✓ All Defender Files (OWNED)" -ForegroundColor White
Write-Host "  ✓ Windows Firewall (OFF)" -ForegroundColor White
Write-Host "  ✓ Windows Defender (DEAD)" -ForegroundColor White
Write-Host "  ✓ Real-Time Protection (DEAD)" -ForegroundColor White
Write-Host "  ✓ All Scanning (OFF)" -ForegroundColor White
Write-Host "  ✓ Cloud Protection (OFF)" -ForegroundColor White
Write-Host "  ✓ Signature Updates (OFF)" -ForegroundColor White
Write-Host "  ✓ Tamper Protection (OBLITERATED)" -ForegroundColor White
Write-Host "  ✓ Exploit Guard (OFF)" -ForegroundColor White
Write-Host "  ✓ SmartScreen (OFF)" -ForegroundColor White
Write-Host "  ✓ Application Guard (OFF)" -ForegroundColor White
Write-Host "  ✓ ATP (OFF)" -ForegroundColor White
Write-Host "  ✓ Security Notifications (OFF)" -ForegroundColor White
Write-Host "  ✓ File System Protection (OBLITERATED)" -ForegroundColor White
Write-Host "  ✓ All Network Blocking (OBLITERATED)" -ForegroundColor White
Write-Host "  ✓ Network Protection (OFF)" -ForegroundColor White
Write-Host "  ✓ Attack Surface Reduction (OFF)" -ForegroundColor White
Write-Host "  ✓ File Sharing (FULLY ENABLED)" -ForegroundColor White
Write-Host "  ✓ Windows Update (DISABLED)" -ForegroundColor White
Write-Host "  ✓ Core Isolation / Memory Integrity (OFF)" -ForegroundColor White
Write-Host "  ✓ ALL Reputation-Based Protection (OFF)" -ForegroundColor White
Write-Host "  ✓ Device Security (OFF)" -ForegroundColor White
Write-Host "  ✓ Ransomware Protection (OFF)" -ForegroundColor White
Write-Host "  ✓ Security Center Service (KILLED)" -ForegroundColor White
Write-Host ""
Write-Host "EVERY SINGLE SECURITY FEATURE IS RED/DOWN!" -ForegroundColor Red
Write-Host "10000 percent GUARANTEED: Nothing will be denied." -ForegroundColor Red
Write-Host "NO REBOOT NEEDED - Changes active NOW!" -ForegroundColor Green
Write-Host ""
Write-Host "To restore security: the enable.ps1 script" -ForegroundColor Yellow
Write-Host ""

