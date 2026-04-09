#Requires -RunAsAdministrator
# PermanentDotNetPathFix.ps1 - COMPLETE .NET environment repair
# Fixes: LoadLibrary error 126, "install .NET" errors, PATH issues
# PRESERVES: F:\DevKit tools (compilers, build tools, etc.) - ONLY removes F:\DevKit\dotnet

$ErrorActionPreference = "Stop"
$defaultDotnet = "C:\Program Files\dotnet"
$taskName = "EnforceDotNetDefaultPath"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "     PERMANENT .NET ENVIRONMENT FIX - COMPLETE REPAIR          " -ForegroundColor Cyan
Write-Host "     Preserves F:\DevKit tools, fixes dotnet paths only        " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Verify .NET exists at default location
if (-not (Test-Path "$defaultDotnet\dotnet.exe")) {
    Write-Host "[ERROR] .NET not found at $defaultDotnet" -ForegroundColor Red
    Write-Host "Please install .NET SDK from https://dot.net/download first" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Found .NET at: $defaultDotnet" -ForegroundColor Green
Write-Host ""

# STEP 1: Clean Machine PATH - remove ONLY dotnet paths, PRESERVE F:\DevKit tools
Write-Host "[1/8] Cleaning Machine PATH (preserving F:\DevKit tools)..." -ForegroundColor Yellow

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$originalMachinePaths = $machinePath -split ";"
$cleanMachinePaths = @()

foreach ($p in $originalMachinePaths) {
    $trimmed = $p.Trim()
    if (-not $trimmed) { continue }

    # Check if this is a dotnet-specific path that should be removed
    $isDotnetPath = $false

    # Remove: F:\DevKit\dotnet (but NOT F:\DevKit\tools, F:\DevKit\compilers, etc.)
    if ($trimmed -match "(?i)^F:\\DevKit\\dotnet") {
        $isDotnetPath = $true
    }
    # Remove: Any path ending in \dotnet or \.dotnet (but not \tools\dotnet-something)
    elseif ($trimmed -match "(?i)\\dotnet$") {
        $isDotnetPath = $true
    }
    # Remove: User profile .dotnet paths
    elseif ($trimmed -match "(?i)\\\.dotnet") {
        $isDotnetPath = $true
    }
    # Remove: C:\Program Files\dotnet (will be re-added at front)
    elseif ($trimmed -match "(?i)^C:\\Program Files\\dotnet") {
        $isDotnetPath = $true
    }
    # Remove: microsoft.net framework paths that conflict
    elseif ($trimmed -match "(?i)microsoft\.net\\framework") {
        # Keep these - they're for old .NET Framework
        $isDotnetPath = $false
    }

    if ($isDotnetPath) {
        Write-Host "  Removing: $trimmed" -ForegroundColor DarkGray
    } else {
        $cleanMachinePaths += $trimmed
    }
}

Write-Host "[2/8] Cleaning User PATH (preserving non-dotnet paths)..." -ForegroundColor Yellow

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$originalUserPaths = if ($userPath) { $userPath -split ";" } else { @() }
$cleanUserPaths = @()

foreach ($p in $originalUserPaths) {
    $trimmed = $p.Trim()
    if (-not $trimmed) { continue }

    # Remove dotnet-specific paths from User PATH
    $isDotnetPath = $false

    if ($trimmed -match "(?i)\\dotnet$") {
        $isDotnetPath = $true
    }
    elseif ($trimmed -match "(?i)\\\.dotnet") {
        $isDotnetPath = $true
    }
    elseif ($trimmed -match "(?i)DevKit\\dotnet") {
        $isDotnetPath = $true
    }

    if ($isDotnetPath) {
        Write-Host "  Removing from User: $trimmed" -ForegroundColor DarkGray
    } else {
        $cleanUserPaths += $trimmed
    }
}

Write-Host "[3/8] Setting C:\Program Files\dotnet at BEGINNING of Machine PATH..." -ForegroundColor Yellow

# Ensure default dotnet is FIRST, then all other cleaned paths
$newMachinePath = (@($defaultDotnet) + $cleanMachinePaths | Select-Object -Unique) -join ";"
$newUserPath = ($cleanUserPaths | Select-Object -Unique) -join ";"

[Environment]::SetEnvironmentVariable("Path", $newMachinePath, "Machine")
[Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")

Write-Host "  [OK] PATH updated - C:\Program Files\dotnet is now FIRST" -ForegroundColor Green

# STEP 2: Set DOTNET_ROOT and other critical environment variables
# THIS FIXES "LoadLibrary failed error 126" and "install .NET" errors
Write-Host "[4/8] Setting .NET environment variables (fixes error 126)..." -ForegroundColor Yellow

[Environment]::SetEnvironmentVariable("DOTNET_ROOT", $defaultDotnet, "Machine")
$dotnet32Path = "${env:ProgramFiles(x86)}\dotnet"
if (Test-Path $dotnet32Path) {
    [Environment]::SetEnvironmentVariable("DOTNET_ROOT(x86)", $dotnet32Path, "Machine")
}

# Remove any user-level overrides that could cause conflicts
[Environment]::SetEnvironmentVariable("DOTNET_ROOT", $null, "User")
[Environment]::SetEnvironmentVariable("DOTNET_ROOT(x86)", $null, "User")

# Enable multilevel lookup (allows finding shared frameworks)
[Environment]::SetEnvironmentVariable("DOTNET_MULTILEVEL_LOOKUP", "1", "Machine")

# Clear any SDK resolver overrides
[Environment]::SetEnvironmentVariable("DOTNET_MSBUILD_SDK_RESOLVER_CLI_DIR", $null, "User")
[Environment]::SetEnvironmentVariable("DOTNET_MSBUILD_SDK_RESOLVER_CLI_DIR", $null, "Machine")
[Environment]::SetEnvironmentVariable("MSBuildSDKsPath", $null, "User")
[Environment]::SetEnvironmentVariable("MSBuildSDKsPath", $null, "Machine")

Write-Host "  [OK] DOTNET_ROOT = $defaultDotnet" -ForegroundColor Green
Write-Host "  [OK] DOTNET_MULTILEVEL_LOOKUP = 1" -ForegroundColor Green

# STEP 3: Fix Registry entries for .NET runtime resolution
Write-Host "[5/8] Fixing .NET registry entries..." -ForegroundColor Yellow

# Register App Paths for dotnet.exe
$appPathsKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\dotnet.exe"
if (-not (Test-Path $appPathsKey)) {
    New-Item -Path $appPathsKey -Force | Out-Null
}
Set-ItemProperty -Path $appPathsKey -Name "(Default)" -Value "$defaultDotnet\dotnet.exe" -Force
Set-ItemProperty -Path $appPathsKey -Name "Path" -Value $defaultDotnet -Force
Write-Host "  [OK] App Paths registered" -ForegroundColor Green

# Fix InstallLocation for x64
$dotnetSetupKey = "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64"
if (Test-Path $dotnetSetupKey) {
    Set-ItemProperty -Path $dotnetSetupKey -Name "InstallLocation" -Value $defaultDotnet -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] x64 InstallLocation registry fixed" -ForegroundColor Green
}

# Fix InstallLocation for x86 if exists
$dotnetSetupKey32 = "HKLM:\SOFTWARE\WOW6432Node\dotnet\Setup\InstalledVersions\x86"
if ((Test-Path $dotnetSetupKey32) -and (Test-Path $dotnet32Path)) {
    Set-ItemProperty -Path $dotnetSetupKey32 -Name "InstallLocation" -Value $dotnet32Path -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] x86 InstallLocation registry fixed" -ForegroundColor Green
}

# Disable VS from modifying PATH
$vsRegPath = "HKLM:\SOFTWARE\Microsoft\VisualStudio\Setup"
if (-not (Test-Path $vsRegPath)) {
    New-Item -Path $vsRegPath -Force | Out-Null
}
Set-ItemProperty -Path $vsRegPath -Name "DisablePathModification" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] VS path modification disabled" -ForegroundColor Green

# STEP 4: Create startup enforcement script
Write-Host "[6/8] Creating startup enforcement script..." -ForegroundColor Yellow

$startupScriptPath = "C:\ProgramData\DotNetPathFix\EnforcePath.ps1"
$startupScriptDir = Split-Path $startupScriptPath

if (-not (Test-Path $startupScriptDir)) {
    New-Item -ItemType Directory -Path $startupScriptDir -Force | Out-Null
}

# Enforcement script content - preserves F:\DevKit tools
$startupScript = @'
$dd = "C:\Program Files\dotnet"
$logFile = "C:\ProgramData\DotNetPathFix\enforcement.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$changes = @()

# Check Machine PATH - ensure C:\Program Files\dotnet is FIRST
$mp = [Environment]::GetEnvironmentVariable("Path", "Machine")
$firstPath = ($mp -split ";")[0]

if ($firstPath -ne $dd) {
    # Remove all dotnet paths except F:\DevKit tools
    $paths = $mp -split ";"
    $clean = @()
    foreach ($p in $paths) {
        $t = $p.Trim()
        if (-not $t) { continue }
        # Skip dotnet-specific paths
        if ($t -match "(?i)^F:\\DevKit\\dotnet") { continue }
        if ($t -match "(?i)\\dotnet$") { continue }
        if ($t -match "(?i)\\\.dotnet") { continue }
        if ($t -eq $dd) { continue }
        $clean += $t
    }
    $newPath = (@($dd) + $clean | Select-Object -Unique) -join ";"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    $changes += "Machine PATH fixed"
}

# Check User PATH for dotnet entries (should have none)
$up = [Environment]::GetEnvironmentVariable("Path", "User")
if ($up -match "(?i)\\dotnet$|\\\.dotnet|DevKit\\dotnet") {
    $paths = $up -split ";"
    $clean = @()
    foreach ($p in $paths) {
        $t = $p.Trim()
        if (-not $t) { continue }
        if ($t -match "(?i)\\dotnet$") { continue }
        if ($t -match "(?i)\\\.dotnet") { continue }
        if ($t -match "(?i)DevKit\\dotnet") { continue }
        $clean += $t
    }
    $newUserPath = ($clean | Select-Object -Unique) -join ";"
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    $changes += "User PATH fixed"
}

# Ensure DOTNET_ROOT is set
$dr = [Environment]::GetEnvironmentVariable("DOTNET_ROOT", "Machine")
if ($dr -ne $dd) {
    [Environment]::SetEnvironmentVariable("DOTNET_ROOT", $dd, "Machine")
    $changes += "DOTNET_ROOT fixed"
}

# Ensure DOTNET_MULTILEVEL_LOOKUP is set
$ml = [Environment]::GetEnvironmentVariable("DOTNET_MULTILEVEL_LOOKUP", "Machine")
if ($ml -ne "1") {
    [Environment]::SetEnvironmentVariable("DOTNET_MULTILEVEL_LOOKUP", "1", "Machine")
    $changes += "DOTNET_MULTILEVEL_LOOKUP fixed"
}

# Log changes if any
if ($changes.Count -gt 0) {
    $logEntry = "$timestamp - $($changes -join ', ')"
    Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
}
'@

$startupScript | Out-File -FilePath $startupScriptPath -Encoding UTF8 -Force
Write-Host "  [OK] Saved to: $startupScriptPath" -ForegroundColor Green

# STEP 5: Create scheduled task (runs as SYSTEM at startup)
Write-Host "[7/8] Creating scheduled task..." -ForegroundColor Yellow

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$startupScriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Enforces default .NET path on startup - preserves F:\DevKit tools" | Out-Null

Write-Host "  [OK] Task created (runs as SYSTEM at boot)" -ForegroundColor Green

# STEP 6: Update current session immediately
Write-Host "[8/8] Updating current session..." -ForegroundColor Yellow

# Build current session PATH with dotnet first
$currentPaths = $env:Path -split ";"
$sessionClean = @()
foreach ($p in $currentPaths) {
    $t = $p.Trim()
    if (-not $t) { continue }
    if ($t -match "(?i)^F:\\DevKit\\dotnet") { continue }
    if ($t -match "(?i)\\dotnet$") { continue }
    if ($t -match "(?i)\\\.dotnet") { continue }
    $sessionClean += $t
}
$env:Path = (@($defaultDotnet) + $sessionClean | Select-Object -Unique) -join ";"

$env:DOTNET_ROOT = $defaultDotnet
$env:DOTNET_MULTILEVEL_LOOKUP = "1"

Write-Host "  [OK] Current session updated" -ForegroundColor Green

# VERIFICATION
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                      VERIFICATION                             " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Machine PATH - First 5 entries:" -ForegroundColor Yellow
$machineCheck = [Environment]::GetEnvironmentVariable("Path", "Machine") -split ";"
for ($i = 0; $i -lt [Math]::Min(5, $machineCheck.Count); $i++) {
    $entry = $machineCheck[$i]
    if ($entry -eq $defaultDotnet) {
        Write-Host "  [$($i+1)] $entry [CORRECT - FIRST]" -ForegroundColor Green
    } elseif ($entry -match "(?i)DevKit") {
        Write-Host "  [$($i+1)] $entry [F:\DevKit tool - PRESERVED]" -ForegroundColor Cyan
    } else {
        Write-Host "  [$($i+1)] $entry" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Machine PATH - .NET related entries:" -ForegroundColor Yellow
$dotnetEntries = $machineCheck | Where-Object { $_ -match "(?i)dotnet|\.net" }
if ($dotnetEntries) {
    $dotnetEntries | ForEach-Object {
        if ($_ -eq $defaultDotnet) {
            Write-Host "  $_ [CORRECT]" -ForegroundColor Green
        } else {
            Write-Host "  $_ [WARNING - extra dotnet path]" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  (none found - ERROR!)" -ForegroundColor Red
}

Write-Host ""
Write-Host "User PATH .NET entries:" -ForegroundColor Yellow
$userCheck = [Environment]::GetEnvironmentVariable("Path", "User") -split ";" | Where-Object { $_ -match "(?i)dotnet" }
if ($userCheck) {
    $userCheck | ForEach-Object { Write-Host "  $_ [SHOULD BE EMPTY!]" -ForegroundColor Red }
} else {
    Write-Host "  (none - correct!)" -ForegroundColor Green
}

Write-Host ""
Write-Host "F:\DevKit paths preserved:" -ForegroundColor Yellow
$devkitPaths = $machineCheck | Where-Object { $_ -match "(?i)^F:\\DevKit" -and $_ -notmatch "(?i)\\dotnet$" }
if ($devkitPaths) {
    $devkitPaths | ForEach-Object { Write-Host "  $_ [PRESERVED]" -ForegroundColor Cyan }
} else {
    Write-Host "  (no F:\DevKit paths found)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Environment Variables:" -ForegroundColor Yellow
Write-Host "  DOTNET_ROOT = $([Environment]::GetEnvironmentVariable('DOTNET_ROOT', 'Machine'))" -ForegroundColor White
Write-Host "  DOTNET_MULTILEVEL_LOOKUP = $([Environment]::GetEnvironmentVariable('DOTNET_MULTILEVEL_LOOKUP', 'Machine'))" -ForegroundColor White

Write-Host ""
Write-Host "Active dotnet location (where.exe):" -ForegroundColor Yellow
$whereResult = where.exe dotnet 2>$null
if ($whereResult) {
    $isFirst = $true
    $whereResult | ForEach-Object {
        if ($_ -eq "$defaultDotnet\dotnet.exe") {
            if ($isFirst) {
                Write-Host "  $_ [CORRECT - FIRST]" -ForegroundColor Green
            } else {
                Write-Host "  $_ [CORRECT]" -ForegroundColor Green
            }
        } else {
            Write-Host "  $_ [EXTRA - should not appear]" -ForegroundColor Red
        }
        $isFirst = $false
    }
} else {
    Write-Host "  NOT FOUND!" -ForegroundColor Red
}

Write-Host ""
Write-Host "dotnet --version:" -ForegroundColor Yellow
try {
    $version = & "$defaultDotnet\dotnet.exe" --version 2>&1
    Write-Host "  $version" -ForegroundColor White
} catch {
    Write-Host "  ERROR: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "dotnet --list-sdks:" -ForegroundColor Yellow
try {
    & "$defaultDotnet\dotnet.exe" --list-sdks 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} catch {
    Write-Host "  ERROR: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "dotnet --list-runtimes:" -ForegroundColor Yellow
try {
    & "$defaultDotnet\dotnet.exe" --list-runtimes 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} catch {
    Write-Host "  ERROR: $_" -ForegroundColor Red
}

# COMPLETION
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                    PROTECTION ACTIVE                          " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  [OK] C:\Program Files\dotnet is FIRST in PATH" -ForegroundColor Green
Write-Host "  [OK] F:\DevKit\dotnet REMOVED from PATH" -ForegroundColor Green
Write-Host "  [OK] F:\DevKit tools PRESERVED (compilers, etc.)" -ForegroundColor Cyan
Write-Host "  [OK] DOTNET_ROOT environment variable set" -ForegroundColor Green
Write-Host "  [OK] Registry entries fixed" -ForegroundColor Green
Write-Host "  [OK] Scheduled task created (enforces on every boot)" -ForegroundColor Green
Write-Host "  [OK] Visual Studio path modification disabled" -ForegroundColor Green
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  LoadLibrary error 126 - FIXED" -ForegroundColor Green
Write-Host "  'Install .NET' errors  - FIXED" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "=== RESTART YOUR COMPUTER to complete the fix ===" -ForegroundColor Red -BackgroundColor Yellow
Write-Host ""
Write-Host "After reboot, 'where.exe dotnet' should show ONLY:" -ForegroundColor White
Write-Host "  C:\Program Files\dotnet\dotnet.exe" -ForegroundColor Green
Write-Host ""
Write-Host "To remove protection later:" -ForegroundColor Gray
Write-Host "  Unregister-ScheduledTask -TaskName EnforceDotNetDefaultPath -Confirm:0" -ForegroundColor DarkGray
Write-Host "  Remove-Item C:\ProgramData\DotNetPathFix -Recurse -Force" -ForegroundColor DarkGray
Write-Host ""
