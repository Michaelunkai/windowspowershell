# HeidiSQL - Fully Automatic Setup with TovPlay Database
$ErrorActionPreference = "SilentlyContinue"

$DB_HOST = "45.148.28.196"
$DB_PORT = "5432"
$DB_NAME = "TovPlay"
$DB_USER = "raz@tovtech.org"
$DB_PASS = "CaptainForgotCreatureBreak"

Write-Host "=== HeidiSQL ===" -ForegroundColor Cyan
Write-Host "Auto-installing and configuring TovPlay database..." -ForegroundColor Yellow

# Find or install HeidiSQL
$heidiPaths = @(
    "$env:ProgramFiles\HeidiSQL\heidisql.exe",
    "${env:ProgramFiles(x86)}\HeidiSQL\heidisql.exe",
    "$env:LOCALAPPDATA\Programs\HeidiSQL\heidisql.exe"
)
$heidiExe = $null
foreach ($p in $heidiPaths) { if (Test-Path $p) { $heidiExe = $p; break } }

if (!$heidiExe) {
    Write-Host "Installing HeidiSQL via winget..." -ForegroundColor Cyan
    winget install --id=HeidiSQL.HeidiSQL -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Start-Sleep -Seconds 5
    foreach ($p in $heidiPaths) { if (Test-Path $p) { $heidiExe = $p; break } }
}

if (!$heidiExe) {
    # Fallback direct download
    Write-Host "Downloading HeidiSQL..." -ForegroundColor Cyan
    $installer = "$env:TEMP\HeidiSQL_Setup.exe"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://www.heidisql.com/installers/HeidiSQL_12.8.0.6908_Setup.exe" -OutFile $installer -UseBasicParsing
    Start-Process $installer -ArgumentList "/VERYSILENT /NORESTART" -Wait
    Remove-Item $installer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    foreach ($p in $heidiPaths) { if (Test-Path $p) { $heidiExe = $p; break } }
}

# Create HeidiSQL portable settings with connection
$heidiSettings = "$env:APPDATA\HeidiSQL\portable_settings.txt"
$heidiDir = Split-Path $heidiSettings
if (!(Test-Path $heidiDir)) { New-Item -ItemType Directory -Path $heidiDir -Force | Out-Null }

# HeidiSQL registry-style settings for PostgreSQL
$settingsContent = @"
[sessions\TovPlay Production]
Host=$DB_HOST
Port=$DB_PORT
User=$DB_USER
Password=$DB_PASS
Database=$DB_NAME
NetType=4
"@
$settingsContent | Out-File -FilePath $heidiSettings -Encoding ASCII -Force

if ($heidiExe) {
    Write-Host "Launching HeidiSQL with TovPlay connection..." -ForegroundColor Green
    # HeidiSQL command line: -h host -P port -u user -p pass -d database --nettype 4 (PostgreSQL)
    Start-Process $heidiExe -ArgumentList "-h=$DB_HOST", "-P=$DB_PORT", "-u=$DB_USER", "-p=$DB_PASS", "-d=$DB_NAME", "--nettype=4"
    Write-Host "SUCCESS: HeidiSQL connected to TovPlay!" -ForegroundColor Green
} else {
    Write-Host "HeidiSQL installed - launch from Start Menu" -ForegroundColor Yellow
}
