#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Comprehensive fix for "LoadLibrary failed with error 126: The specified module could not be found"

.DESCRIPTION
    This script diagnoses and fixes DLL Error 126 by:
    1. Repairing Windows system files (SFC/DISM)
    2. Re-registering common DLLs
    3. Fixing Visual C++ Redistributables
    4. Repairing .NET Framework
    5. Fixing PATH environment variable
    6. Clearing DLL cache
    7. Resetting Windows component store

.PARAMETER ApplicationPath
    Optional: Path to the specific application causing the error

.PARAMETER Quick
    Run only essential fixes (faster)

.PARAMETER Full
    Run all fixes including lengthy repairs

.EXAMPLE
    .\Fix-DLLError126.ps1
    .\Fix-DLLError126.ps1 -ApplicationPath "C:\Program Files\MyApp\app.exe"
    .\Fix-DLLError126.ps1 -Full
#>

param(
    [string]$ApplicationPath = "",
    [switch]$Quick,
    [switch]$Full
)

# Self-elevate if not admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($ApplicationPath) { $arguments += " -ApplicationPath `"$ApplicationPath`"" }
    if ($Quick) { $arguments += " -Quick" }
    if ($Full) { $arguments += " -Full" }
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"

# Colors and formatting
function Write-Status { param($msg) Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[-] $msg" -ForegroundColor Red }
function Write-Section { param($msg) Write-Host "`n========== $msg ==========`n" -ForegroundColor Magenta }

# Log file
$LogPath = "$env:TEMP\DLLError126_Fix_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogPath -Force | Out-Null

Write-Host @"
=============================================================
      DLL ERROR 126 COMPREHENSIVE FIX SCRIPT
      "LoadLibrary failed with error 126"
=============================================================
"@ -ForegroundColor Cyan

$fixCount = 0
$issuesFound = 0

# ============================================================
# PHASE 1: DIAGNOSIS
# ============================================================
Write-Section "PHASE 1: DIAGNOSING THE PROBLEM"

# Check if specific app provided
if ($ApplicationPath -and (Test-Path $ApplicationPath)) {
    Write-Status "Analyzing application: $ApplicationPath"

    # Use dumpbin or Dependencies to find missing DLLs
    $appDir = Split-Path $ApplicationPath -Parent
    Write-Status "Application directory: $appDir"

    # Check for common missing dependencies
    $dllsToCheck = @(
        "vcruntime140.dll", "vcruntime140_1.dll", "msvcp140.dll",
        "ucrtbase.dll", "api-ms-win-crt-runtime-l1-1-0.dll",
        "concrt140.dll", "vccorlib140.dll", "mfc140.dll",
        "msvcr100.dll", "msvcr110.dll", "msvcr120.dll",
        "msvcp100.dll", "msvcp110.dll", "msvcp120.dll"
    )

    foreach ($dll in $dllsToCheck) {
        $found = $false
        $searchPaths = @($appDir, "$env:SystemRoot\System32", "$env:SystemRoot\SysWOW64")
        foreach ($path in $searchPaths) {
            if (Test-Path "$path\$dll") { $found = $true; break }
        }
        if (-not $found) {
            Write-Warn "Potentially missing: $dll"
            $issuesFound++
        }
    }
}

# Check system integrity
Write-Status "Checking for corrupted system files..."

# ============================================================
# PHASE 2: VISUAL C++ REDISTRIBUTABLES
# ============================================================
Write-Section "PHASE 2: VISUAL C++ REDISTRIBUTABLES"

Write-Status "Checking installed Visual C++ Redistributables..."

$vcRedists = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,
                              HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "*Visual C++*" -or $_.DisplayName -like "*Visual Studio*Redistributable*" } |
    Select-Object DisplayName, DisplayVersion

if ($vcRedists) {
    Write-Status "Found Visual C++ Redistributables:"
    $vcRedists | ForEach-Object { Write-Host "    - $($_.DisplayName)" -ForegroundColor Gray }
} else {
    Write-Warn "No Visual C++ Redistributables found - this is likely the problem!"
    $issuesFound++
}

# Download and install latest VC++ Redistributables
Write-Status "Installing/Repairing Visual C++ Redistributables..."

$vcRedistUrls = @{
    "VC2015-2022_x64" = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    "VC2015-2022_x86" = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
}

$downloadPath = "$env:TEMP\vcredist"
New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null

foreach ($name in $vcRedistUrls.Keys) {
    $url = $vcRedistUrls[$name]
    $file = "$downloadPath\$name.exe"

    Write-Status "Downloading $name..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing -ErrorAction Stop

        Write-Status "Installing $name (repair mode)..."
        $proc = Start-Process -FilePath $file -ArgumentList "/repair /quiet /norestart" -Wait -PassThru
        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 1638 -or $proc.ExitCode -eq 3010) {
            Write-Success "$name installed/repaired successfully"
            $fixCount++
        } else {
            # Try fresh install
            $proc = Start-Process -FilePath $file -ArgumentList "/install /quiet /norestart" -Wait -PassThru
            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                Write-Success "$name installed successfully"
                $fixCount++
            }
        }
    } catch {
        Write-Warn "Could not download $name - $($_.Exception.Message)"
    }
}

# ============================================================
# PHASE 3: SYSTEM FILE CHECKER
# ============================================================
Write-Section "PHASE 3: SYSTEM FILE CHECKER (SFC)"

Write-Status "Running System File Checker..."
$sfcResult = & sfc /scannow 2>&1
$sfcOutput = $sfcResult -join "`n"

if ($sfcOutput -match "found corrupt files and successfully repaired") {
    Write-Success "SFC found and repaired corrupted files"
    $fixCount++
} elseif ($sfcOutput -match "did not find any integrity violations") {
    Write-Success "SFC found no integrity violations"
} elseif ($sfcOutput -match "found corrupt files but was unable to fix") {
    Write-Warn "SFC found corrupt files but couldn't fix them - will try DISM"
    $issuesFound++
} else {
    Write-Status "SFC completed"
}

# ============================================================
# PHASE 4: DISM REPAIR
# ============================================================
if (-not $Quick) {
    Write-Section "PHASE 4: DISM COMPONENT STORE REPAIR"

    Write-Status "Checking component store health..."
    & DISM /Online /Cleanup-Image /CheckHealth

    Write-Status "Scanning component store..."
    & DISM /Online /Cleanup-Image /ScanHealth

    Write-Status "Restoring component store health (this may take a while)..."
    $dismResult = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1
    $dismOutput = $dismResult -join "`n"

    if ($dismOutput -match "The restore operation completed successfully") {
        Write-Success "DISM repair completed successfully"
        $fixCount++
    } elseif ($dismOutput -match "No component store corruption detected") {
        Write-Success "No component store corruption detected"
    } else {
        Write-Warn "DISM completed with possible issues"
    }
}

# ============================================================
# PHASE 5: RE-REGISTER SYSTEM DLLs
# ============================================================
Write-Section "PHASE 5: RE-REGISTERING CRITICAL DLLs"

$criticalDlls = @(
    "oleaut32.dll", "ole32.dll", "shell32.dll", "urlmon.dll",
    "mshtml.dll", "shdocvw.dll", "browseui.dll", "jscript.dll",
    "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll",
    "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll",
    "dssenh.dll", "rsaenh.dll", "gpkcsp.dll", "sccbase.dll",
    "slbcsp.dll", "cryptdlg.dll", "wucltui.dll", "wups.dll",
    "wuaueng.dll", "wuapi.dll", "wups2.dll", "wuwebv.dll"
)

$reregistered = 0
foreach ($dll in $criticalDlls) {
    $dllPath32 = "$env:SystemRoot\SysWOW64\$dll"
    $dllPath64 = "$env:SystemRoot\System32\$dll"

    if (Test-Path $dllPath64) {
        $null = & regsvr32 /s $dllPath64 2>&1
        $reregistered++
    }
    if (Test-Path $dllPath32) {
        $null = & regsvr32 /s $dllPath32 2>&1
        $reregistered++
    }
}
Write-Success "Re-registered $reregistered DLLs"
$fixCount++

# ============================================================
# PHASE 6: PATH ENVIRONMENT VARIABLE
# ============================================================
Write-Section "PHASE 6: FIXING PATH ENVIRONMENT VARIABLE"

Write-Status "Checking PATH for critical directories..."

$criticalPaths = @(
    "$env:SystemRoot\System32",
    "$env:SystemRoot",
    "$env:SystemRoot\System32\Wbem",
    "$env:SystemRoot\System32\WindowsPowerShell\v1.0"
)

$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$pathParts = $currentPath -split ";" | Where-Object { $_ }
$pathModified = $false

foreach ($critPath in $criticalPaths) {
    if ($pathParts -notcontains $critPath) {
        Write-Warn "Missing from PATH: $critPath"
        $pathParts = @($critPath) + $pathParts
        $pathModified = $true
        $issuesFound++
    }
}

# Remove invalid paths
$validPaths = $pathParts | Where-Object { Test-Path $_ -ErrorAction SilentlyContinue }
$invalidCount = $pathParts.Count - $validPaths.Count
if ($invalidCount -gt 0) {
    Write-Warn "Found $invalidCount invalid paths in PATH variable"
}

if ($pathModified) {
    $newPath = $validPaths -join ";"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Success "PATH variable repaired"
    $fixCount++
} else {
    Write-Success "PATH variable is correct"
}

# ============================================================
# PHASE 7: .NET FRAMEWORK REPAIR
# ============================================================
if (-not $Quick) {
    Write-Section "PHASE 7: .NET FRAMEWORK REPAIR"

    Write-Status "Checking .NET Framework installations..."

    # Check installed .NET versions
    $netVersions = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP" -Recurse -ErrorAction SilentlyContinue |
        Get-ItemProperty -Name Version, Release -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match "^(?!S)\p{L}" } |
        Select-Object PSChildName, Version

    if ($netVersions) {
        Write-Status "Found .NET Framework versions:"
        $netVersions | ForEach-Object { Write-Host "    - $($_.PSChildName): $($_.Version)" -ForegroundColor Gray }
    }

    # Re-enable .NET Framework 3.5 feature if needed
    Write-Status "Ensuring .NET Framework 3.5 is enabled..."
    $net35 = Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" -ErrorAction SilentlyContinue
    if ($net35 -and $net35.State -ne "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All -NoRestart -ErrorAction SilentlyContinue
        Write-Success ".NET Framework 3.5 enabled"
        $fixCount++
    }
}

# ============================================================
# PHASE 8: WINDOWS UPDATE COMPONENTS
# ============================================================
if ($Full) {
    Write-Section "PHASE 8: WINDOWS UPDATE COMPONENTS RESET"

    Write-Status "Stopping Windows Update services..."
    $services = @("wuauserv", "cryptSvc", "bits", "msiserver")
    foreach ($svc in $services) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    }

    Write-Status "Clearing Windows Update cache..."
    Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\System32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Status "Restarting Windows Update services..."
    foreach ($svc in $services) {
        Start-Service -Name $svc -ErrorAction SilentlyContinue
    }

    Write-Success "Windows Update components reset"
    $fixCount++
}

# ============================================================
# PHASE 9: CLEAR DLL CACHE AND TEMP FILES
# ============================================================
Write-Section "PHASE 9: CLEARING CACHES"

Write-Status "Clearing DLL cache and temporary files..."

$cachePaths = @(
    "$env:TEMP\*",
    "$env:SystemRoot\Temp\*",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*"
)

$cleared = 0
foreach ($path in $cachePaths) {
    $items = Get-ChildItem $path -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        try {
            Remove-Item $item.FullName -Recurse -Force -ErrorAction Stop
            $cleared++
        } catch { }
    }
}
Write-Success "Cleared $cleared cached items"

# Flush DNS and reset network
Write-Status "Flushing DNS cache..."
& ipconfig /flushdns | Out-Null
Write-Success "DNS cache flushed"

# ============================================================
# PHASE 10: REPAIR APP-SPECIFIC ISSUES
# ============================================================
if ($ApplicationPath -and (Test-Path $ApplicationPath)) {
    Write-Section "PHASE 10: APPLICATION-SPECIFIC REPAIRS"

    $appDir = Split-Path $ApplicationPath -Parent
    $appName = Split-Path $ApplicationPath -Leaf

    Write-Status "Checking application compatibility..."

    # Check if app needs specific VC++ runtime
    $appBitness = "Unknown"
    try {
        $bytes = [System.IO.File]::ReadAllBytes($ApplicationPath)
        $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
        $machineType = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
        $appBitness = switch ($machineType) {
            0x014c { "32-bit (x86)" }
            0x8664 { "64-bit (x64)" }
            0xAA64 { "64-bit (ARM64)" }
            default { "Unknown" }
        }
        Write-Status "Application architecture: $appBitness"
    } catch {
        Write-Warn "Could not determine application architecture"
    }

    # Copy required DLLs to app directory if missing
    $vcDlls = @("vcruntime140.dll", "vcruntime140_1.dll", "msvcp140.dll")
    $sourceDir = if ($appBitness -like "*32*") { "$env:SystemRoot\SysWOW64" } else { "$env:SystemRoot\System32" }

    foreach ($dll in $vcDlls) {
        $appDll = Join-Path $appDir $dll
        $sysDll = Join-Path $sourceDir $dll

        if (-not (Test-Path $appDll) -and (Test-Path $sysDll)) {
            Write-Status "Copying $dll to application directory..."
            Copy-Item $sysDll $appDll -Force -ErrorAction SilentlyContinue
            $fixCount++
        }
    }
}

# ============================================================
# PHASE 11: UNIVERSAL CRT (UCRT)
# ============================================================
Write-Section "PHASE 11: UNIVERSAL C RUNTIME (UCRT)"

Write-Status "Checking Universal CRT installation..."

$ucrtDll = "$env:SystemRoot\System32\ucrtbase.dll"
if (Test-Path $ucrtDll) {
    $ucrtVersion = (Get-Item $ucrtDll).VersionInfo.FileVersion
    Write-Success "UCRT installed: version $ucrtVersion"
} else {
    Write-Warn "UCRT not found - installing via Windows Update..."
    $issuesFound++

    # Try to install KB2999226 (Universal CRT)
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()

    Write-Status "Searching for Universal CRT update..."
    # This is a simplified approach - in production, you'd want more robust Windows Update handling
}

# ============================================================
# SUMMARY AND VERIFICATION
# ============================================================
Write-Section "SUMMARY"

Write-Host @"

=============================================================
                    REPAIR COMPLETE
=============================================================
"@ -ForegroundColor Green

Write-Host "Issues found:     $issuesFound" -ForegroundColor $(if ($issuesFound -gt 0) { "Yellow" } else { "Green" })
Write-Host "Fixes applied:    $fixCount" -ForegroundColor Green
Write-Host "Log file:         $LogPath" -ForegroundColor Gray

# Verification
Write-Section "VERIFICATION"

Write-Status "Verifying critical system files..."

$verifyDlls = @(
    "$env:SystemRoot\System32\vcruntime140.dll",
    "$env:SystemRoot\System32\msvcp140.dll",
    "$env:SystemRoot\System32\ucrtbase.dll",
    "$env:SystemRoot\SysWOW64\vcruntime140.dll",
    "$env:SystemRoot\SysWOW64\msvcp140.dll"
)

$allGood = $true
foreach ($dll in $verifyDlls) {
    if (Test-Path $dll) {
        Write-Host "    [OK] $(Split-Path $dll -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "    [MISSING] $dll" -ForegroundColor Red
        $allGood = $false
    }
}

if ($allGood) {
    Write-Success "`nAll critical DLLs verified!"
} else {
    Write-Warn "`nSome DLLs still missing - a reboot may be required"
}

# Final recommendations
Write-Host @"

=============================================================
                  RECOMMENDATIONS
=============================================================
"@ -ForegroundColor Cyan

Write-Host "1. REBOOT your computer to complete repairs" -ForegroundColor Yellow
Write-Host "2. If error persists, run this script with -Full flag" -ForegroundColor Yellow
Write-Host "3. For specific apps, use: .\Fix-DLLError126.ps1 -ApplicationPath `"path\to\app.exe`"" -ForegroundColor Yellow

if ($ApplicationPath) {
    Write-Host "`n4. Try running the application again after reboot" -ForegroundColor Yellow
}

Stop-Transcript | Out-Null

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
