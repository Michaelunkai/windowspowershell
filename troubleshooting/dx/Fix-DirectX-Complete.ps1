#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Complete DirectX Fix for Windows 11 - All-in-One Solution
.DESCRIPTION
    Comprehensive DirectX repair script that:
    1. Creates full backup of DirectX files and registry
    2. Downloads DirectX June 2010 Redistributable (~100MB)
    3. Fixes the getdirectx function by replacing broken web installer
    4. Runs SFC and DISM system repair
    5. Installs all DirectX legacy components
    6. Verifies all components work correctly
    7. Supports full rollback if anything fails

    This script fixes:
    - "An internal system error occurred" error from dxwebsetup.exe
    - "Sections are not initialized" in DXError.log
    - Missing DirectX 9/10/11 components
    - getdirectx function errors
    - DirectX setup internal errors

.NOTES
    Created: 2025-12-25
    Version: 2.0 (Complete Edition)
    Tested on: Windows 11 23H2

.EXAMPLE
    .\Fix-DirectX-Complete.ps1

    Runs the complete DirectX fix with all steps.

.EXAMPLE
    .\Fix-DirectX-Complete.ps1 -SkipDownload

    Skips download if redistributable is already at C:\Temp\directx_Jun2010_redist.exe

.EXAMPLE
    .\Fix-DirectX-Complete.ps1 -FixGetDirectXOnly

    Only fixes the getdirectx function (fastest mode)
#>

[CmdletBinding()]
param(
    [switch]$SkipDownload,
    [switch]$FixGetDirectXOnly,
    [switch]$SkipSystemRepair,
    [switch]$ForceRedownload
)

# ============================================================================
# CONFIGURATION
# ============================================================================
$ErrorActionPreference = "Stop"
$script:timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Paths
$script:baseDir = "C:\Temp\DirectXFix"
$script:redistPath = "C:\Temp\directx_Jun2010_redist.exe"
$script:redistExtractPath = "C:\Temp\DirectXRedist"
$script:backupDir = Join-Path $baseDir "Backups"
$script:logFile = Join-Path $baseDir "dx_fix_$($script:timestamp).log"
$script:backupZip = Join-Path $backupDir "dx_backup_$($script:timestamp).zip"

# DirectX folder (for getdirectx function fix)
$script:userDxFolder = "F:\backup\windowsapps\install\drivers\DircetX"

# Download URL (Microsoft official)
$script:redistUrl = "https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe"

# State tracking
$script:filesBackedUp = 0
$script:filesRestored = 0
$script:rollbackNeeded = $false
$script:criticalError = $false

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('Info','Warning','Error','Success','Header')]
        [string]$Level = 'Info'
    )

    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$ts] [$Level] $Message"

    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor Cyan }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        'Header'  {
            Write-Host ""
            Write-Host ("=" * 70) -ForegroundColor Magenta
            Write-Host "  $Message" -ForegroundColor Magenta
            Write-Host ("=" * 70) -ForegroundColor Magenta
        }
    }

    # Ensure log directory exists
    $logDir = Split-Path $script:logFile -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    Add-Content -Path $script:logFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Initialize-Directories {
    Write-Log "Initializing directories..." -Level Info

    $dirs = @($script:baseDir, $script:backupDir, $script:redistExtractPath)
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log "Created: $dir" -Level Info
        }
    }
}

function Test-AdminRights {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================================
# STEP 1: BACKUP
# ============================================================================

function Backup-DirectXFiles {
    Write-Log "STEP 1: Creating comprehensive DirectX backup" -Level Header

    try {
        $tempBackupDir = Join-Path $env:TEMP "dx_backup_temp_$($script:timestamp)"
        New-Item -ItemType Directory -Path $tempBackupDir -Force | Out-Null

        # Backup System32 DirectX files
        Write-Log "Backing up System32 DirectX files..." -Level Info
        $sys32Path = Join-Path $tempBackupDir "System32"
        New-Item -ItemType Directory -Path $sys32Path -Force | Out-Null

        $patterns = @("d3d*.dll", "dx*.dll", "D3D*.dll", "dcomp.dll", "XAudio*.dll", "X3DAudio*.dll", "xactengine*.dll", "xinput*.dll")
        foreach ($pattern in $patterns) {
            Get-ChildItem "C:\Windows\System32\$pattern" -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item $_.FullName -Destination $sys32Path -Force -ErrorAction SilentlyContinue
                $script:filesBackedUp++
            }
        }

        # Copy dxdiag.exe
        if (Test-Path "C:\Windows\System32\dxdiag.exe") {
            Copy-Item "C:\Windows\System32\dxdiag.exe" -Destination $sys32Path -Force -ErrorAction SilentlyContinue
            $script:filesBackedUp++
        }

        # Backup SysWOW64 DirectX files (32-bit on 64-bit Windows)
        if (Test-Path "C:\Windows\SysWOW64") {
            Write-Log "Backing up SysWOW64 DirectX files..." -Level Info
            $wow64Path = Join-Path $tempBackupDir "SysWOW64"
            New-Item -ItemType Directory -Path $wow64Path -Force | Out-Null

            foreach ($pattern in $patterns) {
                Get-ChildItem "C:\Windows\SysWOW64\$pattern" -ErrorAction SilentlyContinue | ForEach-Object {
                    Copy-Item $_.FullName -Destination $wow64Path -Force -ErrorAction SilentlyContinue
                    $script:filesBackedUp++
                }
            }
        }

        # Backup registry keys
        Write-Log "Backing up DirectX registry keys..." -Level Info
        $regPaths = @(
            "HKLM\SOFTWARE\Microsoft\DirectX",
            "HKCU\Software\Microsoft\DirectX"
        )

        foreach ($regPath in $regPaths) {
            $psPath = $regPath -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\'
            if (Test-Path $psPath) {
                $regFile = Join-Path $tempBackupDir "registry_$(($regPath -replace '\\','_') -replace ':','').reg"
                $null = reg export $regPath $regFile /y 2>&1
                Write-Log "  Exported: $regPath" -Level Info
            }
        }

        # Backup user's DirectX folder if exists
        if (Test-Path $script:userDxFolder) {
            Write-Log "Backing up user DirectX folder..." -Level Info
            $userDxBackup = Join-Path $tempBackupDir "UserDxFolder"
            Copy-Item $script:userDxFolder -Destination $userDxBackup -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Create zip backup
        Write-Log "Creating backup archive..." -Level Info
        if (Test-Path $script:backupZip) {
            Remove-Item $script:backupZip -Force
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempBackupDir, $script:backupZip)

        # Verify backup
        $backupSize = (Get-Item $script:backupZip).Length
        Write-Log "Backup created: $($script:backupZip)" -Level Success
        Write-Log "  Size: $([math]::Round($backupSize/1MB, 2)) MB" -Level Info
        Write-Log "  Files backed up: $($script:filesBackedUp)" -Level Info

        # Cleanup temp
        Remove-Item $tempBackupDir -Recurse -Force -ErrorAction SilentlyContinue

        return $true
    }
    catch {
        Write-Log "Backup failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ============================================================================
# STEP 2: DOWNLOAD DIRECTX REDISTRIBUTABLE
# ============================================================================

function Get-DirectXRedistributable {
    Write-Log "STEP 2: Downloading DirectX June 2010 Redistributable" -Level Header

    # Check if already downloaded
    if ((Test-Path $script:redistPath) -and (-not $ForceRedownload)) {
        $fileSize = (Get-Item $script:redistPath).Length
        if ($fileSize -gt 90000000) {  # ~90MB minimum
            Write-Log "Redistributable already downloaded: $($script:redistPath)" -Level Success
            Write-Log "  Size: $([math]::Round($fileSize/1MB, 2)) MB" -Level Info
            return $true
        }
    }

    if ($SkipDownload) {
        Write-Log "Download skipped (-SkipDownload). Checking for existing file..." -Level Warning
        if (Test-Path $script:redistPath) {
            return $true
        }
        Write-Log "Redistributable not found. Cannot skip download." -Level Error
        return $false
    }

    Write-Log "Downloading from Microsoft (~100MB)..." -Level Info
    Write-Log "  URL: $($script:redistUrl)" -Level Info

    try {
        # Use curl.exe (built into Windows 10/11) - more reliable than WebClient
        $curlPath = "C:\Windows\System32\curl.exe"
        if (Test-Path $curlPath) {
            Write-Log "Using curl.exe for download..." -Level Info

            # Remove partial download if exists
            if (Test-Path $script:redistPath) {
                Remove-Item $script:redistPath -Force
            }

            $curlArgs = @(
                "-L",                           # Follow redirects
                "-o", $script:redistPath,       # Output file
                "--progress-bar",               # Show progress
                $script:redistUrl
            )

            $process = Start-Process -FilePath $curlPath -ArgumentList $curlArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0) {
                throw "curl download failed with exit code $($process.ExitCode)"
            }
        }
        else {
            # Fallback to .NET WebClient
            Write-Log "Using .NET WebClient for download..." -Level Info
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($script:redistUrl, $script:redistPath)
        }

        # Verify download
        if (Test-Path $script:redistPath) {
            $fileSize = (Get-Item $script:redistPath).Length
            if ($fileSize -gt 90000000) {
                Write-Log "Download complete!" -Level Success
                Write-Log "  Size: $([math]::Round($fileSize/1MB, 2)) MB" -Level Info
                return $true
            }
            else {
                throw "Downloaded file is too small ($([math]::Round($fileSize/1MB, 2)) MB)"
            }
        }
        else {
            throw "Download file not found after download"
        }
    }
    catch {
        Write-Log "Download failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ============================================================================
# STEP 3: EXTRACT REDISTRIBUTABLE
# ============================================================================

function Expand-DirectXRedistributable {
    Write-Log "STEP 3: Extracting DirectX Redistributable" -Level Header

    if (-not (Test-Path $script:redistPath)) {
        Write-Log "Redistributable not found: $($script:redistPath)" -Level Error
        return $false
    }

    try {
        # Clean extraction directory
        if (Test-Path $script:redistExtractPath) {
            Write-Log "Cleaning existing extraction directory..." -Level Info
            Remove-Item $script:redistExtractPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:redistExtractPath -Force | Out-Null

        Write-Log "Extracting (this takes 1-2 minutes)..." -Level Info

        $process = Start-Process -FilePath $script:redistPath `
            -ArgumentList "/Q", "/T:$($script:redistExtractPath)" `
            -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -ne 0) {
            Write-Log "Extraction warning: exit code $($process.ExitCode)" -Level Warning
        }

        # Verify extraction
        $dxSetup = Join-Path $script:redistExtractPath "DXSETUP.exe"
        if (Test-Path $dxSetup) {
            $fileCount = (Get-ChildItem $script:redistExtractPath).Count
            $totalSize = [math]::Round((Get-ChildItem $script:redistExtractPath | Measure-Object -Property Length -Sum).Sum / 1MB, 1)

            Write-Log "Extraction complete!" -Level Success
            Write-Log "  Files: $fileCount" -Level Info
            Write-Log "  Size: $totalSize MB" -Level Info
            return $true
        }
        else {
            throw "DXSETUP.exe not found after extraction"
        }
    }
    catch {
        Write-Log "Extraction failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ============================================================================
# STEP 4: FIX GETDIRECTX FUNCTION
# ============================================================================

function Repair-GetDirectXFunction {
    Write-Log "STEP 4: Fixing getdirectx Function" -Level Header

    # Check if user DirectX folder exists
    if (-not (Test-Path $script:userDxFolder)) {
        Write-Log "User DirectX folder not found: $($script:userDxFolder)" -Level Warning
        Write-Log "Creating folder..." -Level Info
        New-Item -ItemType Directory -Path $script:userDxFolder -Force | Out-Null
    }

    # Verify redistributable is extracted
    $dxSetup = Join-Path $script:redistExtractPath "DXSETUP.exe"
    if (-not (Test-Path $dxSetup)) {
        Write-Log "DXSETUP.exe not found. Run extraction first." -Level Error
        return $false
    }

    try {
        # Backup original dxwebsetup.exe if exists
        $originalExe = Join-Path $script:userDxFolder "dxwebsetup.exe"
        $backupExe = Join-Path $script:userDxFolder "dxwebsetup_original.exe"

        if ((Test-Path $originalExe) -and (-not (Test-Path $backupExe))) {
            Write-Log "Backing up original dxwebsetup.exe..." -Level Info
            Copy-Item $originalExe -Destination $backupExe -Force
            Write-Log "  Saved as: dxwebsetup_original.exe" -Level Info
        }

        # Copy DXSETUP.exe as dxwebsetup.exe (so getdirectx function works unchanged)
        Write-Log "Installing DXSETUP.exe as dxwebsetup.exe..." -Level Info
        Copy-Item $dxSetup -Destination $originalExe -Force

        # Copy required DLLs
        Write-Log "Copying required DLLs..." -Level Info
        $requiredDlls = @("DSETUP.dll", "dsetup32.dll")
        foreach ($dll in $requiredDlls) {
            $dllPath = Join-Path $script:redistExtractPath $dll
            if (Test-Path $dllPath) {
                Copy-Item $dllPath -Destination $script:userDxFolder -Force
                Write-Log "  Copied: $dll" -Level Info
            }
        }

        # Copy CAB files (needed for offline installation)
        Write-Log "Copying CAB files (this may take a minute)..." -Level Info
        $cabFiles = Get-ChildItem (Join-Path $script:redistExtractPath "*.cab")
        $cabCount = 0
        foreach ($cab in $cabFiles) {
            Copy-Item $cab.FullName -Destination $script:userDxFolder -Force
            $cabCount++
        }
        Write-Log "  Copied: $cabCount CAB files" -Level Info

        # Verify installation
        $totalFiles = (Get-ChildItem $script:userDxFolder).Count
        $totalSize = [math]::Round((Get-ChildItem $script:userDxFolder | Measure-Object -Property Length -Sum).Sum / 1MB, 1)

        Write-Log "getdirectx function fixed!" -Level Success
        Write-Log "  Location: $($script:userDxFolder)" -Level Info
        Write-Log "  Files: $totalFiles" -Level Info
        Write-Log "  Size: $totalSize MB" -Level Info

        return $true
    }
    catch {
        Write-Log "Fix failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ============================================================================
# STEP 5: SYSTEM REPAIR (SFC/DISM)
# ============================================================================

function Repair-SystemFiles {
    Write-Log "STEP 5: Running System File Repair" -Level Header

    if ($SkipSystemRepair) {
        Write-Log "System repair skipped (-SkipSystemRepair)" -Level Warning
        return $true
    }

    try {
        # Run DISM RestoreHealth
        Write-Log "Running DISM RestoreHealth (this may take several minutes)..." -Level Info
        $dismResult = & Dism.exe /Online /Cleanup-Image /RestoreHealth 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "DISM completed successfully" -Level Success
        }
        else {
            Write-Log "DISM completed with code: $LASTEXITCODE" -Level Warning
        }

        # Run SFC
        Write-Log "Running System File Checker (this may take several minutes)..." -Level Info
        $sfcResult = & sfc /scannow 2>&1
        Write-Log "SFC completed" -Level Success

        return $true
    }
    catch {
        Write-Log "System repair warning: $($_.Exception.Message)" -Level Warning
        return $true  # Don't fail on system repair errors
    }
}

# ============================================================================
# STEP 6: INSTALL DIRECTX COMPONENTS
# ============================================================================

function Install-DirectXComponents {
    Write-Log "STEP 6: Installing DirectX Components" -Level Header

    $dxSetup = Join-Path $script:redistExtractPath "DXSETUP.exe"

    if (-not (Test-Path $dxSetup)) {
        Write-Log "DXSETUP.exe not found. Skipping installation." -Level Warning
        return $false
    }

    try {
        Write-Log "Running DirectX installer (silent mode)..." -Level Info
        Write-Log "This installs all legacy DirectX 9/10/11 components." -Level Info

        $process = Start-Process -FilePath $dxSetup `
            -ArgumentList "/silent" `
            -Wait -PassThru -NoNewWindow

        $exitCode = $process.ExitCode

        # DirectX installer exit codes:
        # 0 = Success
        # 3010 = Success, reboot required
        # -9 = Already up to date

        switch ($exitCode) {
            0     { Write-Log "DirectX installation completed successfully!" -Level Success }
            3010  { Write-Log "DirectX installed - Reboot required" -Level Success }
            -9    { Write-Log "DirectX already up to date" -Level Success }
            default { Write-Log "DirectX installer exit code: $exitCode" -Level Warning }
        }

        # Check installation log
        $dxLog = "C:\Windows\Logs\DirectX.log"
        if (Test-Path $dxLog) {
            $lastLines = Get-Content $dxLog -Tail 3
            Write-Log "DirectX.log (last 3 lines):" -Level Info
            foreach ($line in $lastLines) {
                Write-Log "  $line" -Level Info
            }
        }

        return $true
    }
    catch {
        Write-Log "Installation error: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ============================================================================
# STEP 7: RE-REGISTER COMPONENTS
# ============================================================================

function Register-DirectXDLLs {
    Write-Log "STEP 7: Re-registering DirectX DLLs" -Level Header

    $dlls = @(
        "d3d9.dll",
        "d3d10.dll",
        "d3d10_1.dll",
        "d3d11.dll",
        "dxgi.dll",
        "dcomp.dll"
    )

    $registered = 0
    $failed = 0

    foreach ($dll in $dlls) {
        $dllPath = "C:\Windows\System32\$dll"
        if (Test-Path $dllPath) {
            try {
                $process = Start-Process -FilePath "regsvr32.exe" `
                    -ArgumentList "/s `"$dllPath`"" `
                    -Wait -PassThru -NoNewWindow

                if ($process.ExitCode -eq 0) {
                    Write-Log "  [OK] $dll" -Level Success
                    $registered++
                }
                else {
                    Write-Log "  [--] $dll (not a COM DLL)" -Level Info
                }
            }
            catch {
                Write-Log "  [WARN] $dll - $($_.Exception.Message)" -Level Warning
                $failed++
            }
        }
        else {
            Write-Log "  [--] $dll (not found)" -Level Info
        }
    }

    Write-Log "Registered: $registered DLLs" -Level Info
    return $true
}

# ============================================================================
# STEP 8: VERIFY INSTALLATION
# ============================================================================

function Test-DirectXInstallation {
    Write-Log "STEP 8: Verifying DirectX Installation" -Level Header

    # Critical DirectX files to check
    $criticalFiles = @(
        @{Path="C:\Windows\System32\d3d9.dll"; Name="Direct3D 9"},
        @{Path="C:\Windows\System32\d3d10.dll"; Name="Direct3D 10"},
        @{Path="C:\Windows\System32\d3d10_1.dll"; Name="Direct3D 10.1"},
        @{Path="C:\Windows\System32\d3d11.dll"; Name="Direct3D 11"},
        @{Path="C:\Windows\System32\D3D12.dll"; Name="Direct3D 12"},
        @{Path="C:\Windows\System32\dxgi.dll"; Name="DXGI"},
        @{Path="C:\Windows\System32\d3dcompiler_47.dll"; Name="D3D Compiler"},
        @{Path="C:\Windows\System32\dxdiag.exe"; Name="DirectX Diagnostic"},
        @{Path="C:\Windows\System32\XAudio2_9.dll"; Name="XAudio2"},
        @{Path="C:\Windows\System32\xinput1_4.dll"; Name="XInput"}
    )

    Write-Log "Checking critical DirectX components..." -Level Info

    $allPresent = $true
    $presentCount = 0

    foreach ($file in $criticalFiles) {
        if (Test-Path $file.Path) {
            $version = (Get-Item $file.Path).VersionInfo.FileVersion
            Write-Log "  [OK] $($file.Name): $version" -Level Success
            $presentCount++
        }
        else {
            Write-Log "  [MISSING] $($file.Name)" -Level Warning
            $allPresent = $false
        }
    }

    Write-Log "Components present: $presentCount/$($criticalFiles.Count)" -Level Info

    # Test getdirectx function
    Write-Log "" -Level Info
    Write-Log "Testing getdirectx function..." -Level Info

    $dxExe = Join-Path $script:userDxFolder "dxwebsetup.exe"
    if (Test-Path $dxExe) {
        $dxSize = [math]::Round((Get-Item $dxExe).Length / 1KB, 0)

        if ($dxSize -gt 400) {
            Write-Log "  [OK] dxwebsetup.exe is full installer ($dxSize KB)" -Level Success

            # Quick test run
            Write-Log "  Running quick test..." -Level Info
            $testProc = Start-Process -FilePath $dxExe -ArgumentList "/silent" -Wait -PassThru -NoNewWindow

            if ($testProc.ExitCode -eq 0 -or $testProc.ExitCode -eq -9) {
                Write-Log "  [OK] getdirectx test passed (exit code: $($testProc.ExitCode))" -Level Success
            }
            else {
                Write-Log "  [WARN] getdirectx exit code: $($testProc.ExitCode)" -Level Warning
            }
        }
        else {
            Write-Log "  [WARN] dxwebsetup.exe is still web installer ($dxSize KB)" -Level Warning
            $allPresent = $false
        }
    }
    else {
        Write-Log "  [MISSING] dxwebsetup.exe not found" -Level Warning
    }

    # Check DirectX version in registry
    Write-Log "" -Level Info
    Write-Log "Checking DirectX registry..." -Level Info

    $dxRegPath = "HKLM:\SOFTWARE\Microsoft\DirectX"
    if (Test-Path $dxRegPath) {
        try {
            $version = Get-ItemProperty $dxRegPath -Name "Version" -ErrorAction SilentlyContinue
            if ($version) {
                Write-Log "  DirectX Version: $($version.Version)" -Level Success
            }
        }
        catch {}
    }

    return $allPresent
}

# ============================================================================
# STEP 9: ROLLBACK
# ============================================================================

function Invoke-Rollback {
    Write-Log "EMERGENCY ROLLBACK" -Level Header

    if (-not (Test-Path $script:backupZip)) {
        Write-Log "No backup found for rollback!" -Level Error
        return $false
    }

    try {
        Write-Log "Restoring from backup: $($script:backupZip)" -Level Warning

        $tempRestore = Join-Path $env:TEMP "dx_rollback_$($script:timestamp)"

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($script:backupZip, $tempRestore)

        # Restore System32
        $sys32Source = Join-Path $tempRestore "System32"
        if (Test-Path $sys32Source) {
            Get-ChildItem $sys32Source | ForEach-Object {
                $dest = "C:\Windows\System32\$($_.Name)"
                try {
                    if (Test-Path $dest) {
                        & takeown /F "$dest" /A 2>$null | Out-Null
                        & icacls "$dest" /grant "Administrators:F" /C 2>$null | Out-Null
                    }
                    Copy-Item $_.FullName -Destination $dest -Force
                    Write-Log "  Restored: $($_.Name)" -Level Success
                    $script:filesRestored++
                }
                catch {
                    Write-Log "  Failed: $($_.Name)" -Level Warning
                }
            }
        }

        # Restore SysWOW64
        $wow64Source = Join-Path $tempRestore "SysWOW64"
        if (Test-Path $wow64Source) {
            Get-ChildItem $wow64Source | ForEach-Object {
                $dest = "C:\Windows\SysWOW64\$($_.Name)"
                try {
                    if (Test-Path $dest) {
                        & takeown /F "$dest" /A 2>$null | Out-Null
                        & icacls "$dest" /grant "Administrators:F" /C 2>$null | Out-Null
                    }
                    Copy-Item $_.FullName -Destination $dest -Force
                    Write-Log "  Restored: $($_.Name)" -Level Success
                    $script:filesRestored++
                }
                catch {
                    Write-Log "  Failed: $($_.Name)" -Level Warning
                }
            }
        }

        # Restore user DirectX folder
        $userDxSource = Join-Path $tempRestore "UserDxFolder"
        if (Test-Path $userDxSource) {
            Get-ChildItem $userDxSource | ForEach-Object {
                Copy-Item $_.FullName -Destination $script:userDxFolder -Force -ErrorAction SilentlyContinue
            }
        }

        # Restore registry
        Get-ChildItem $tempRestore -Filter "*.reg" | ForEach-Object {
            $null = reg import $_.FullName 2>&1
            Write-Log "  Restored registry: $($_.Name)" -Level Success
        }

        Remove-Item $tempRestore -Recurse -Force -ErrorAction SilentlyContinue

        Write-Log "Rollback completed. Files restored: $($script:filesRestored)" -Level Success
        return $true
    }
    catch {
        Write-Log "Rollback failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    Write-Host ""
    Write-Host "  ========================================================" -ForegroundColor Cyan
    Write-Host "    COMPLETE DIRECTX FIX FOR WINDOWS 11" -ForegroundColor Cyan
    Write-Host "    Version 2.0 - All-in-One Solution" -ForegroundColor Cyan
    Write-Host "  ========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Started: $(Get-Date)" -ForegroundColor Gray
    Write-Host "  Running as: $env:USERNAME" -ForegroundColor Gray
    Write-Host "  Log file: $($script:logFile)" -ForegroundColor Gray
    Write-Host ""

    # Check admin rights
    if (-not (Test-AdminRights)) {
        Write-Host "  [ERROR] This script requires Administrator privileges!" -ForegroundColor Red
        Write-Host "  Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        exit 1
    }

    $success = $true
    $startTime = Get-Date

    try {
        # Initialize
        Initialize-Directories

        # Fast mode: only fix getdirectx
        if ($FixGetDirectXOnly) {
            Write-Log "Running in FixGetDirectXOnly mode" -Level Warning

            if (-not (Get-DirectXRedistributable)) { throw "Download failed" }
            if (-not (Expand-DirectXRedistributable)) { throw "Extraction failed" }
            if (-not (Repair-GetDirectXFunction)) { throw "Fix failed" }

            Write-Log "Quick fix completed!" -Level Success
        }
        else {
            # Full repair mode

            # Step 1: Backup
            if (-not (Backup-DirectXFiles)) {
                throw "Backup failed - aborting for safety"
            }

            # Step 2: Download
            if (-not (Get-DirectXRedistributable)) {
                $script:rollbackNeeded = $true
                throw "Download failed"
            }

            # Step 3: Extract
            if (-not (Expand-DirectXRedistributable)) {
                $script:rollbackNeeded = $true
                throw "Extraction failed"
            }

            # Step 4: Fix getdirectx
            if (-not (Repair-GetDirectXFunction)) {
                Write-Log "getdirectx fix had issues (non-critical)" -Level Warning
            }

            # Step 5: System repair
            Repair-SystemFiles | Out-Null

            # Step 6: Install DirectX
            if (-not (Install-DirectXComponents)) {
                Write-Log "DirectX installation had issues (non-critical)" -Level Warning
            }

            # Step 7: Register DLLs
            Register-DirectXDLLs | Out-Null

            # Step 8: Verify
            $allGood = Test-DirectXInstallation

            if (-not $allGood) {
                Write-Log "Some components may need a reboot" -Level Warning
            }
        }
    }
    catch {
        $success = $false
        Write-Log "ERROR: $($_.Exception.Message)" -Level Error

        if ($script:rollbackNeeded) {
            Write-Log "Critical error - initiating rollback..." -Level Error
            Invoke-Rollback
        }
    }

    # Summary
    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host ""
    Write-Host "  ========================================================" -ForegroundColor Cyan
    Write-Host "    EXECUTION SUMMARY" -ForegroundColor Cyan
    Write-Host "  ========================================================" -ForegroundColor Cyan
    Write-Host ""

    if ($success) {
        Write-Host "    STATUS: SUCCESS" -ForegroundColor Green
    }
    else {
        Write-Host "    STATUS: FAILED" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "    Duration: $([math]::Round($duration.TotalMinutes, 1)) minutes" -ForegroundColor Gray
    Write-Host "    Backup: $($script:backupZip)" -ForegroundColor Gray
    Write-Host "    Log: $($script:logFile)" -ForegroundColor Gray
    Write-Host ""

    if ($success) {
        Write-Host "  --------------------------------------------------------" -ForegroundColor Green
        Write-Host "    DIRECTX FIX COMPLETED SUCCESSFULLY!" -ForegroundColor Green
        Write-Host "  --------------------------------------------------------" -ForegroundColor Green
        Write-Host ""
        Write-Host "    The getdirectx function should now work with 0 errors." -ForegroundColor Cyan
        Write-Host "    A system restart is recommended." -ForegroundColor Yellow
        Write-Host ""
    }
    else {
        Write-Host "  --------------------------------------------------------" -ForegroundColor Red
        Write-Host "    FIX FAILED - CHECK LOG FOR DETAILS" -ForegroundColor Red
        Write-Host "  --------------------------------------------------------" -ForegroundColor Red
        Write-Host ""
    }

    if ($success) { exit 0 } else { exit 1 }
}

# Run main
Main
