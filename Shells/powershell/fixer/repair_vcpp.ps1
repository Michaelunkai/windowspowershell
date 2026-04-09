# Repair VC++ x86 Redistributable - Complete Fix
$ErrorActionPreference = 'Continue'

Write-Host "=== VC++ 2015-2022 x86 Repair Script ===" -ForegroundColor Cyan

# Check if already present
if (Test-Path "C:\WINDOWS\SysWOW64\vcruntime140_1.dll") {
    Write-Host "DLL already exists - skipping repair" -ForegroundColor Green
    exit 0
}

# First uninstall old x86 version if present
Write-Host "Step 1: Checking for old x86 installation..."
$uninstall = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA 0 |
             Where-Object { $_.DisplayName -match "Visual C\+\+ 2015-2022.*x86" }
if ($uninstall) {
    Write-Host "  Found: $($uninstall.DisplayName)"
    Write-Host "  Uninstalling old version..."
    $uninstallString = $uninstall.UninstallString -replace '"',''
    if ($uninstallString) {
        Start-Process -FilePath $uninstallString -ArgumentList "/uninstall", "/quiet", "/norestart" -Wait -EA 0
        Start-Sleep -Seconds 5
    }
}

# Download fresh installer
Write-Host "Step 2: Downloading fresh VC++ x86 installer..."
$downloadPath = "$env:TEMP\vc_redist_x86_fresh.exe"
try {
    Invoke-WebRequest "https://aka.ms/vs/17/release/vc_redist.x86.exe" -OutFile $downloadPath -UseBasicParsing
    Write-Host "  Downloaded to: $downloadPath"
} catch {
    Write-Host "  Download failed: $_" -ForegroundColor Red
    exit 1
}

# Install fresh
Write-Host "Step 3: Installing fresh VC++ x86..."
$proc = Start-Process -FilePath $downloadPath -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru
Write-Host "  Installer exit code: $($proc.ExitCode)"

Start-Sleep -Seconds 5

# Final check
Write-Host "Step 4: Verifying installation..."
if (Test-Path "C:\WINDOWS\SysWOW64\vcruntime140_1.dll") {
    $info = Get-Item "C:\WINDOWS\SysWOW64\vcruntime140_1.dll"
    Write-Host "SUCCESS: vcruntime140_1.dll exists!" -ForegroundColor Green
    Write-Host "  Size: $($info.Length) bytes"
    Write-Host "  Date: $($info.LastWriteTime)"
} else {
    Write-Host "FAILED: DLL still missing after install" -ForegroundColor Red

    # Try to copy from System32 if x64 version exists
    if (Test-Path "C:\WINDOWS\System32\vcruntime140_1.dll") {
        Write-Host "  Attempting to copy from WinSxS..."
        $winsxsSrc = Get-ChildItem "C:\Windows\WinSxS\*vcruntime140_1*" -File -Recurse -EA 0 |
                     Where-Object { $_.DirectoryName -match 'x86' } |
                     Sort-Object LastWriteTime -Descending |
                     Select-Object -First 1
        if ($winsxsSrc) {
            Copy-Item $winsxsSrc.FullName -Destination "C:\WINDOWS\SysWOW64\vcruntime140_1.dll" -Force
            Write-Host "  Copied from WinSxS: $($winsxsSrc.FullName)" -ForegroundColor Green
        }
    }
}

Write-Host "=== Complete ===" -ForegroundColor Cyan
