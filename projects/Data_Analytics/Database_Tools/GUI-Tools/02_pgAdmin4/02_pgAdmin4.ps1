# pgAdmin 4 - Fully Automatic Setup with TovPlay Database
$ErrorActionPreference = "SilentlyContinue"

$DB_HOST = "45.148.28.196"
$DB_PORT = "5432"
$DB_NAME = "TovPlay"
$DB_USER = "raz@tovtech.org"
$DB_PASS = "CaptainForgotCreatureBreak"

Write-Host "=== pgAdmin 4 ===" -ForegroundColor Cyan
Write-Host "Auto-installing and configuring TovPlay database..." -ForegroundColor Yellow

# Find or install pgAdmin
$pgAdminPaths = @(
    "${env:ProgramFiles}\pgAdmin 4\runtime\pgAdmin4.exe",
    "${env:ProgramFiles}\pgAdmin 4\bin\pgAdmin4.exe",
    "$env:LOCALAPPDATA\Programs\pgAdmin 4\runtime\pgAdmin4.exe"
)
$pgAdminExe = $null
foreach ($p in $pgAdminPaths) { if (Test-Path $p) { $pgAdminExe = $p; break } }

if (!$pgAdminExe) {
    Write-Host "Installing pgAdmin 4 via winget..." -ForegroundColor Cyan
    winget install --id=PostgreSQL.pgAdmin -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Start-Sleep -Seconds 10
    foreach ($p in $pgAdminPaths) { if (Test-Path $p) { $pgAdminExe = $p; break } }
}

# Create pgAdmin servers.json for auto-import
$pgAdminData = "$env:APPDATA\pgAdmin"
if (!(Test-Path $pgAdminData)) { New-Item -ItemType Directory -Path $pgAdminData -Force | Out-Null }

$serversJson = @"
{
    "Servers": {
        "1": {
            "Name": "TovPlay Production",
            "Group": "TovPlay",
            "Host": "$DB_HOST",
            "Port": $DB_PORT,
            "MaintenanceDB": "$DB_NAME",
            "Username": "$DB_USER",
            "SSLMode": "prefer",
            "PassFile": "",
            "Comment": "TovPlay Production Database - Auto-configured"
        }
    }
}
"@
$serversJson | Out-File -FilePath "$pgAdminData\servers.json" -Encoding UTF8 -Force

# Also create in common locations
$commonPaths = @(
    "$env:USERPROFILE\Documents\servers.json",
    "$env:TEMP\pgadmin_servers.json"
)
foreach ($path in $commonPaths) {
    $serversJson | Out-File -FilePath $path -Encoding UTF8 -Force
}

if ($pgAdminExe) {
    Write-Host "Launching pgAdmin 4..." -ForegroundColor Green
    Start-Process $pgAdminExe
    Write-Host "SUCCESS: pgAdmin 4 launched" -ForegroundColor Green
    Write-Host "Import servers from: $pgAdminData\servers.json" -ForegroundColor Yellow
    Write-Host "Password: $DB_PASS" -ForegroundColor Yellow
} else {
    Write-Host "pgAdmin 4 installed - launch from Start Menu" -ForegroundColor Yellow
}
