# ReShade Auto-Updater
# Double-click Update-ReShade.bat to run

$GameDir = "E:\games\The Witcher 3- Wild Hunt\bin\x64"
$TempDir = "$env:TEMP\reshade-updater"
$BaseUrl = "https://reshade.me"
$7zPath  = "C:\Program Files\7-Zip\7z.exe"

$ErrorActionPreference = "Stop"
Write-Host "=== ReShade Auto-Updater ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Fetch latest version from reshade.me
Write-Host "[1/5] Fetching latest version from reshade.me..." -ForegroundColor Yellow
try {
    $html = (Invoke-WebRequest -Uri "$BaseUrl/" -UseBasicParsing -Headers @{"User-Agent"="Mozilla/5.0"} -TimeoutSec 30).Content
} catch {
    Write-Host "ERROR: Cannot reach reshade.me - $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}
if ($html -match '/downloads/ReShade_Setup_(\d+\.\d+\.\d+)\.exe') {
    $LatestVersion = $Matches[1]
    $DownloadUrl = "$BaseUrl/downloads/ReShade_Setup_$LatestVersion.exe"
} else {
    Write-Host "ERROR: Could not parse version from reshade.me" -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}
Write-Host "  Latest version: $LatestVersion" -ForegroundColor Green

# Step 2: Show currently installed version
Write-Host "[2/5] Checking installed version..." -ForegroundColor Yellow
if (Test-Path "$GameDir\dxgi.dll") {
    $logLine = Get-Content "$GameDir\ReShade.log" -ErrorAction SilentlyContinue | Select-String "version '" | Select-Object -First 1
    if ($logLine -match "version '([^']+)'") { $inst = $Matches[1] } else { $inst = "unknown" }
    Write-Host "  Installed: $inst" -ForegroundColor Cyan
} else {
    Write-Host "  No existing ReShade found." -ForegroundColor Gray
}

# Step 3: Download installer (skip if already cached for this version)
Write-Host "[3/5] Downloading ReShade $LatestVersion installer..." -ForegroundColor Yellow
if (-not (Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir -Force | Out-Null }
Get-ChildItem $TempDir -Filter "ReShade_Setup_*.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "ReShade_Setup_$LatestVersion.exe" } |
    Remove-Item -Force -ErrorAction SilentlyContinue
$InstallerPath = "$TempDir\ReShade_Setup_$LatestVersion.exe"
if (-not (Test-Path $InstallerPath)) {
    $ProgressPreference = "SilentlyContinue"
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing -Headers @{"User-Agent"="Mozilla/5.0"} -TimeoutSec 120
        Write-Host "  Downloaded." -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Download failed - $_" -ForegroundColor Red
        Read-Host "Press Enter to exit"; exit 1
    }
} else {
    Write-Host "  Using cached installer." -ForegroundColor Gray
}

# Step 4: Extract ReShade64.dll from installer using 7-Zip
Write-Host "[4/5] Extracting ReShade64.dll from installer..." -ForegroundColor Yellow
$ExtractDir = "$TempDir\extracted_$LatestVersion"
if (-not (Test-Path $ExtractDir)) { New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null }
& $7zPath e $InstallerPath -o"$ExtractDir" "ReShade64.dll" -y | Out-Null
$NewDll = "$ExtractDir\ReShade64.dll"
if (-not (Test-Path $NewDll)) {
    Write-Host "ERROR: ReShade64.dll not found in installer." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}
$newSizeMB = [math]::Round((Get-Item $NewDll).Length / 1MB, 2)
Write-Host "  Extracted ReShade64.dll ($newSizeMB MB)" -ForegroundColor Green

# Step 5: Replace dxgi.dll and clean old log
Write-Host "[5/5] Replacing dxgi.dll in game directory..." -ForegroundColor Yellow
$TargetDll = "$GameDir\dxgi.dll"
try {
    Copy-Item $NewDll $TargetDll -Force
    Remove-Item "$GameDir\ReShade.log" -Force -ErrorAction SilentlyContinue
    Write-Host "  Replaced dxgi.dll." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Could not replace dxgi.dll - $_" -ForegroundColor Red
    Write-Host "  Make sure The Witcher 3 is NOT running, then try again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"; exit 1
}

# Verify
Write-Host ""
Write-Host "=== Result ===" -ForegroundColor Cyan
$installed = Get-Item $TargetDll
$installedSizeMB = [math]::Round($installed.Length / 1MB, 2)
if ($installed.Length -eq (Get-Item $NewDll).Length) {
    Write-Host "  dxgi.dll: $installedSizeMB MB - VERIFIED" -ForegroundColor Green
    Write-Host ""
    Write-Host "SUCCESS: ReShade $LatestVersion installed for The Witcher 3!" -ForegroundColor Green
} else {
    Write-Host "  WARNING: File size mismatch - install may have failed." -ForegroundColor Red
}
Write-Host ""
Read-Host "Press Enter to exit"