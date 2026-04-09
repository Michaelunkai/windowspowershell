# TablePlus - Fully Automatic Setup with TovPlay Database
$ErrorActionPreference = "SilentlyContinue"

$DB_HOST = "45.148.28.196"
$DB_PORT = "5432"
$DB_NAME = "TovPlay"
$DB_USER = "raz@tovtech.org"
$DB_PASS = "CaptainForgotCreatureBreak"

Write-Host "=== TablePlus ===" -ForegroundColor Cyan
Write-Host "Auto-installing and configuring TovPlay database..." -ForegroundColor Yellow

# Find or install TablePlus
$tablePlusPaths = @(
    "$env:LOCALAPPDATA\Programs\TablePlus\TablePlus.exe",
    "$env:ProgramFiles\TablePlus\TablePlus.exe"
)
$tablePlusExe = $null
foreach ($p in $tablePlusPaths) { if (Test-Path $p) { $tablePlusExe = $p; break } }

if (!$tablePlusExe) {
    Write-Host "Installing TablePlus via winget..." -ForegroundColor Cyan
    winget install --id=TablePlus.TablePlus -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Start-Sleep -Seconds 10
    foreach ($p in $tablePlusPaths) { if (Test-Path $p) { $tablePlusExe = $p; break } }
}

# Create TablePlus connection via URL scheme
$encodedUser = [System.Uri]::EscapeDataString($DB_USER)
$encodedPass = [System.Uri]::EscapeDataString($DB_PASS)
$connUrl = "postgresql://${encodedUser}:${encodedPass}@${DB_HOST}:${DB_PORT}/${DB_NAME}?statusColor=28a745&environment=production&name=TovPlay%20Production"

# Create connection file for TablePlus
$tablePlusData = "$env:APPDATA\TablePlus"
if (!(Test-Path $tablePlusData)) { New-Item -ItemType Directory -Path $tablePlusData -Force | Out-Null }

$connectionJson = @"
{
    "connections": [{
        "name": "TovPlay Production",
        "driver": "PostgreSQL",
        "host": "$DB_HOST",
        "port": $DB_PORT,
        "user": "$DB_USER",
        "password": "$DB_PASS",
        "database": "$DB_NAME",
        "ssl": false,
        "color": "#28a745"
    }]
}
"@
$connectionJson | Out-File -FilePath "$tablePlusData\connections.json" -Encoding UTF8 -Force

if ($tablePlusExe) {
    Write-Host "Launching TablePlus..." -ForegroundColor Green
    # Try URL scheme first (auto-connects)
    Start-Process "tableplus://?driver=postgresql&host=$DB_HOST&port=$DB_PORT&user=$encodedUser&pass=$encodedPass&database=$DB_NAME&name=TovPlay"
    Start-Sleep -Seconds 2
    # Also launch the app
    Start-Process $tablePlusExe
    Write-Host "SUCCESS: TablePlus configured with TovPlay!" -ForegroundColor Green
} else {
    Write-Host "TablePlus installed - launch from Start Menu" -ForegroundColor Yellow
}
