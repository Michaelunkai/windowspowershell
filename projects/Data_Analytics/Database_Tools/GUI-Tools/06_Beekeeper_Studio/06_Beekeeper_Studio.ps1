# Beekeeper Studio - Fully Automatic Setup with TovPlay Database
$ErrorActionPreference = "SilentlyContinue"

$DB_HOST = "45.148.28.196"
$DB_PORT = "5432"
$DB_NAME = "TovPlay"
$DB_USER = "raz@tovtech.org"
$DB_PASS = "CaptainForgotCreatureBreak"

Write-Host "=== Beekeeper Studio ===" -ForegroundColor Cyan
Write-Host "Auto-installing and configuring TovPlay database..." -ForegroundColor Yellow

# Find or install Beekeeper Studio
$beekeeperPaths = @(
    "$env:LOCALAPPDATA\Programs\beekeeper-studio\Beekeeper Studio.exe",
    "$env:ProgramFiles\Beekeeper Studio\Beekeeper Studio.exe",
    "$env:LOCALAPPDATA\beekeeper-studio\Beekeeper Studio.exe"
)
$beekeeperExe = $null
foreach ($p in $beekeeperPaths) { if (Test-Path $p) { $beekeeperExe = $p; break } }

if (!$beekeeperExe) {
    Write-Host "Installing Beekeeper Studio via winget..." -ForegroundColor Cyan
    winget install --id=beekeeper-studio.beekeeper-studio -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Start-Sleep -Seconds 10
    foreach ($p in $beekeeperPaths) { if (Test-Path $p) { $beekeeperExe = $p; break } }
}

# Create Beekeeper Studio connection config
$beekeeperData = "$env:APPDATA\beekeeper-studio"
if (!(Test-Path $beekeeperData)) { New-Item -ItemType Directory -Path $beekeeperData -Force | Out-Null }

# Beekeeper uses SQLite for connections, but we can create a startup connection
$connectionConfig = @"
{
    "savedConnections": [{
        "id": "tovplay-prod",
        "name": "TovPlay Production",
        "connectionType": "postgresql",
        "host": "$DB_HOST",
        "port": $DB_PORT,
        "user": "$DB_USER",
        "password": "$DB_PASS",
        "defaultDatabase": "$DB_NAME",
        "ssl": false,
        "labelColor": "#28a745"
    }]
}
"@
$connectionConfig | Out-File -FilePath "$beekeeperData\config.json" -Encoding UTF8 -Force

if ($beekeeperExe) {
    Write-Host "Launching Beekeeper Studio..." -ForegroundColor Green
    Start-Process $beekeeperExe
    Write-Host "SUCCESS: Beekeeper Studio launched!" -ForegroundColor Green
    Write-Host "Create connection: Host=$DB_HOST Port=$DB_PORT User=$DB_USER DB=$DB_NAME" -ForegroundColor Yellow
} else {
    # Try finding via Get-ChildItem
    $found = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs" -Filter "Beekeeper*" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*.exe" } | Select-Object -First 1
    if ($found) {
        Write-Host "Launching Beekeeper Studio from: $($found.FullName)" -ForegroundColor Green
        Start-Process $found.FullName
    } else {
        Write-Host "Beekeeper Studio installed - launch from Start Menu" -ForegroundColor Yellow
    }
}
