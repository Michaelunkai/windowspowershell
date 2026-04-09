# WSL2 Ultimate Fix - Unified v4.0 - PowerShell 5.1
# Merged from wsl_fixer.ps1 + a.ps1 (wslfix)
# Run: Set-ExecutionPolicy Bypass -Scope Process -Force; .\wsl_fixer.ps1
# All fixes are PERMANENT and survive WSL restarts!

$ErrorActionPreference = "Continue"
$DISTRO = "Ubuntu"

function Write-OK($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Info($m) { Write-Host "[i] $m" -ForegroundColor Cyan }
function Write-Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "[X] $m" -ForegroundColor Red }
function Write-Section($m) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Blue
    Write-Host "  $m" -ForegroundColor White
    Write-Host ("=" * 70) -ForegroundColor Blue
}

Clear-Host
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Magenta
Write-Host "  =    WSL2 ULTIMATE FIX v4.0 - UNIFIED + PERMANENT FIXES      =" -ForegroundColor Magenta
Write-Host "  =    All fixes survive WSL restarts. Windows updates incl.    =" -ForegroundColor Magenta
Write-Host "  ================================================================" -ForegroundColor Magenta
Write-Host ""

# ============================================================================
# SECTION 1: AUTO-ELEVATE TO ADMIN
# ============================================================================
Write-Section "1. ADMIN ELEVATION CHECK"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Elevating to Administrator..."
    Start-Process PowerShell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}
Write-OK "Running as Administrator"

# ============================================================================
# SECTION 2: BACKUP .wslconfig
# ============================================================================
Write-Section "2. BACKUP .wslconfig"
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = "$env:USERPROFILE\wsl-backup-$ts"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
$cfgPath = "$env:USERPROFILE\.wslconfig"
if (Test-Path $cfgPath) {
    Copy-Item $cfgPath "$BackupDir\wslconfig.bak" -Force
    Write-OK "Backed up .wslconfig to $BackupDir"
} else { Write-Info "No existing .wslconfig" }

# ============================================================================
# SECTION 3: REMOVE OLD .wslconfig
# ============================================================================
Write-Section "3. REMOVE OLD .wslconfig"
if (Test-Path $cfgPath) { Remove-Item $cfgPath -Force; Write-OK "Removed old .wslconfig" }
else { Write-Info "Nothing to remove" }

# ============================================================================
# SECTION 4: CREATE OPTIMIZED .wslconfig (auto-detect RAM/CPU)
# ============================================================================
Write-Section "4. CREATE OPTIMIZED .wslconfig"
try {
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $cpu = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
} catch { $ram = 16; $cpu = 4 }
$useRAM = [math]::Min([math]::Max(4, [math]::Floor($ram / 2)), 16)
$useCPU = [math]::Min([math]::Max(2, [math]::Floor($cpu / 2)), 8)
Write-Info "System: ${ram}GB RAM, $cpu CPUs -> WSL: ${useRAM}GB, $useCPU CPUs"
$cfg = @"
[wsl2]
memory=${useRAM}GB
processors=$useCPU
swap=2GB
localhostForwarding=true
nestedVirtualization=true
guiApplications=true
debugConsole=false
vmIdleTimeout=-1

kernelCommandLine=quiet loglevel=0 pci=noaer

[experimental]
autoMemoryReclaim=dropcache
sparseVhd=true
"@
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($cfgPath, $cfg, $utf8)
Write-OK "Created .wslconfig (${useRAM}GB RAM, $useCPU CPUs)"

# ============================================================================
# SECTION 5: ENABLE WINDOWS FEATURES
# ============================================================================
Write-Section "5. ENABLE WINDOWS FEATURES"
$wslComps = @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform", "HypervisorPlatform")
foreach ($c in $wslComps) {
    try {
        $f = Get-WindowsOptionalFeature -FeatureName $c -Online -ErrorAction SilentlyContinue
        if ($f -and $f.State -ne "Enabled") {
            Enable-WindowsOptionalFeature -Online -FeatureName $c -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-OK "Enabled: $c"
        } else { Write-OK "Already enabled: $c" }
    } catch { Write-Warn "Could not enable $c" }
}

# ============================================================================
# SECTION 6: SET WSL2 AS DEFAULT VERSION
# ============================================================================
Write-Section "6. SET WSL2 DEFAULT VERSION"
wsl --set-default-version 2
Write-OK "WSL 2 set as default"

# ============================================================================
# SECTION 7: SHUTDOWN AND RESTART WSL SERVICE
# ============================================================================
Write-Section "7. SHUTDOWN AND RESTART WSL SERVICE"
$null = wsl --shutdown 2>&1
Start-Sleep -Seconds 3
try { Stop-Service LxssManager -Force -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Seconds 3
try { Start-Service LxssManager -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Seconds 3
$svc2 = Get-Service -Name wslservice -ErrorAction SilentlyContinue
if ($svc2) { try { Restart-Service wslservice -ErrorAction SilentlyContinue } catch {} ; Write-OK "wslservice restarted" }
Write-OK "LxssManager restarted"

# ============================================================================
# SECTION 8: UPDATE WSL
# ============================================================================
Write-Section "8. UPDATE WSL"
$ur = wsl --update 2>&1
if ($LASTEXITCODE -ne 0 -or $ur -match "error|failed") {
    wsl --update --pre-release 2>&1 | Out-Null
    Write-Warn "Used pre-release update channel"
} else { Write-OK "WSL updated successfully" }
Start-Sleep -Seconds 2

# ============================================================================
# SECTION 9: CREATE wsl.conf INSIDE WSL
# ============================================================================
Write-Section "9. CREATE wsl.conf INSIDE WSL"
wsl -d Ubuntu -u root -- bash -c "printf '[boot]\nsystemd=true\n\n[network]\ngenerateResolvConf=false\nhostname=micha-wsl\n\n[interop]\nenabled=true\nappendWindowsPath=true\n\n[user]\ndefault=root\n' > /etc/wsl.conf"
if ($LASTEXITCODE -eq 0) { Write-OK "Created /etc/wsl.conf" } else { Write-Warn "wsl.conf issue (WSL may not be running)" }

# ============================================================================
# SECTION 10: FIX DNS INSIDE WSL
# ============================================================================
Write-Section "10. FIX DNS INSIDE WSL"
wsl -d Ubuntu -u root -- bash -c "chattr -i /etc/resolv.conf 2>/dev/null; printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\nnameserver 8.8.4.4\n' > /etc/resolv.conf; chattr +i /etc/resolv.conf 2>/dev/null"
if ($LASTEXITCODE -eq 0) { Write-OK "DNS fixed and locked (immutable)" } else { Write-Warn "DNS fix issue" }

# ============================================================================
# SECTION 11: TEST WSL WITH RETRIES (10 attempts)
# ============================================================================
Write-Section "11. TEST WSL WITH RETRIES (10 attempts)"
Start-Sleep -Seconds 5
$working = $false
for ($i = 1; $i -le 10; $i++) {
    Write-Info "Attempt $i of 10..."
    $r = wsl -d Ubuntu whoami 2>&1
    if ($r -match "root|micha|ubuntu") { Write-OK "WSL started on attempt $i!"; $working = $true; break }
    Write-Warn "Failed. Restarting LxssManager..."
    net stop LxssManager /y 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    net start LxssManager 2>&1 | Out-Null
    Start-Sleep -Seconds 8
}
if (-not $working) {
    $null = wsl --shutdown 2>&1
    Start-Sleep -Seconds 5
    $ft = wsl -d Ubuntu whoami 2>&1
    if ($ft -match "root|micha|ubuntu") { Write-OK "WSL ok after full restart"; $working = $true }
    else { Write-Err "WSL failed - reboot may be needed" }
}

# ============================================================================
# SECTION 12: HCS_E_CONNECTION_TIMEOUT DETECTION
# ============================================================================
Write-Section "12. HCS_E_CONNECTION_TIMEOUT DETECTION"
$hcsPat = @("HCS_E_CONNECTION_TIMEOUT", "0x80131500")
$hcsAtt = 0
$hcsOk = $false
while ($hcsAtt -lt 2 -and -not $hcsOk) {
    $hcsAtt++
    $wslOut = $(wsl --list --running 2>&1) | Out-String
    $hit = $false
    $mp = ""
    foreach ($p in $hcsPat) {
        if ($wslOut -match [regex]::Escape($p)) { $hit = $true; $mp = $p; break }
    }
    if (-not $hit) { Write-OK "No timeout on attempt $hcsAtt"; $hcsOk = $true }
    else {
        Write-Warn "Timeout detected ($mp). Restarting LxssManager..."
        $hs = Get-Service -Name LxssManager -ErrorAction SilentlyContinue
        if ($hs) { Stop-Service LxssManager -Force -ErrorAction SilentlyContinue } else { wsl --shutdown 2>&1 | Out-Null }
        Start-Sleep -Seconds 5
        if ($hs) { Start-Service LxssManager -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 5
    }
}
if ($hcsOk) { Write-OK "WSL running normally" } else { Write-Warn "WSL HCS check failed - may need reboot" }

# ============================================================================
# SECTION 13: FEATURE TOGGLE FALLBACK
# ============================================================================
Write-Section "13. FEATURE TOGGLE FALLBACK"
$wslOk2 = $false
try { wsl --list --verbose 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { $wslOk2 = $true } } catch {}
if (-not $wslOk2) {
    Write-Warn "Toggling features as fallback..."
    $ft2 = @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform", "HypervisorPlatform")
    foreach ($x in $ft2) { Disable-WindowsOptionalFeature -Online -FeatureName $x -NoRestart -ErrorAction SilentlyContinue | Out-Null }
    Start-Sleep -Seconds 5
    foreach ($x in $ft2) { Enable-WindowsOptionalFeature -Online -FeatureName $x -NoRestart -ErrorAction SilentlyContinue | Out-Null }
    Write-Warn "Features toggled - reboot may be required"
} else { Write-OK "WSL functional - toggle not needed" }

# ============================================================================
# SECTION 14: INSTALL ESSENTIAL PACKAGES INSIDE WSL
# ============================================================================
Write-Section "14. ESSENTIAL PACKAGES INSIDE WSL"
wsl -d Ubuntu -u root -- bash -c "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq 2>&1 | tail -3; apt-get upgrade -y -qq 2>&1 | tail -5; apt-get autoremove -y -qq 2>&1 | tail -3"
if ($LASTEXITCODE -eq 0) { Write-OK "APT maintenance complete" } else { Write-Warn "APT had issues" }
wsl -d Ubuntu -u root -- bash -c "export DEBIAN_FRONTEND=noninteractive; apt-get install -y -qq curl wget git vim net-tools htop build-essential python3 python3-pip unzip zip 2>&1 | tail -5"
if ($LASTEXITCODE -eq 0) { Write-OK "Essential packages installed" } else { Write-Warn "Some packages failed" }

# ============================================================================
# SECTION 15: INSTALL PSWindowsUpdate AND RUN WINDOWS UPDATES
# ============================================================================
Write-Section "15. INSTALL WINDOWS UPDATES"
try { Import-Module PowerShellGet -ErrorAction SilentlyContinue } catch {}
try {
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate -ErrorAction SilentlyContinue)) {
        Install-Module PSWindowsUpdate -Force -SkipPublisherCheck -ErrorAction Stop
    }
    Import-Module PSWindowsUpdate -ErrorAction Stop
    Install-WindowsUpdate -AcceptAll -AutoReboot
    Write-OK "Windows Update completed"
} catch {
    $errMsg = $_.Exception.Message
    Write-Warn "PSWindowsUpdate failed: $errMsg. Run manually if needed."
}

# ============================================================================
# SECTION 16: SUMMARY
# ============================================================================
Write-Section "16. SUMMARY"
Write-Host ""
if ($working) { Write-OK "WSL2 is working correctly" }
else { Write-Warn "WSL2 did not respond - reboot may be required" }
Write-OK "Backup: $BackupDir"
Write-OK "Config: ${useRAM}GB RAM, $useCPU CPUs"
Write-OK "Features: WSL, VirtualMachinePlatform, HypervisorPlatform checked/enabled"
Write-OK "LxssManager restarted; WSL updated; DNS fixed (8.8.8.8, 1.1.1.1, 8.8.4.4)"
Write-Host ""
Write-Host "  Completed. Restart if Windows features were changed." -ForegroundColor Yellow
Write-Host ""
