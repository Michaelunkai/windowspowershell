# Azure Data Studio - Fully Automatic Setup with TovPlay Database
$ErrorActionPreference = "SilentlyContinue"

$DB_HOST = "45.148.28.196"
$DB_PORT = "5432"
$DB_NAME = "TovPlay"
$DB_USER = "raz@tovtech.org"
$DB_PASS = "CaptainForgotCreatureBreak"

Write-Host "=== Azure Data Studio ===" -ForegroundColor Cyan
Write-Host "Auto-installing and configuring TovPlay database..." -ForegroundColor Yellow

# Find or install Azure Data Studio
$adsPaths = @(
    "$env:LOCALAPPDATA\Programs\Azure Data Studio\azuredatastudio.exe",
    "$env:ProgramFiles\Azure Data Studio\azuredatastudio.exe"
)
$adsExe = $null
foreach ($p in $adsPaths) { if (Test-Path $p) { $adsExe = $p; break } }

if (!$adsExe) {
    Write-Host "Installing Azure Data Studio via winget..." -ForegroundColor Cyan
    winget install --id=Microsoft.AzureDataStudio -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Start-Sleep -Seconds 15
    foreach ($p in $adsPaths) { if (Test-Path $p) { $adsExe = $p; break } }
}

# Create Azure Data Studio connection settings
$adsConfig = "$env:APPDATA\azuredatastudio\User"
if (!(Test-Path $adsConfig)) { New-Item -ItemType Directory -Path $adsConfig -Force | Out-Null }

# Create settings.json with PostgreSQL extension and connection
$settingsJson = @"
{
    "workbench.enablePreviewFeatures": true,
    "datasource.connectionGroups": [
        {
            "name": "TovPlay",
            "id": "tovplay-group"
        }
    ],
    "datasource.connections": [
        {
            "options": {
                "connectionName": "TovPlay Production",
                "server": "$DB_HOST",
                "database": "$DB_NAME",
                "authenticationType": "SqlLogin",
                "user": "$DB_USER",
                "password": "$DB_PASS",
                "port": "$DB_PORT",
                "encrypt": false,
                "trustServerCertificate": true,
                "groupId": "tovplay-group"
            },
            "providerName": "PGSQL",
            "savePassword": true,
            "id": "tovplay-prod"
        }
    ]
}
"@
$settingsJson | Out-File -FilePath "$adsConfig\settings.json" -Encoding UTF8 -Force

if ($adsExe) {
    Write-Host "Launching Azure Data Studio..." -ForegroundColor Green
    Start-Process $adsExe
    Write-Host "SUCCESS: Azure Data Studio launched!" -ForegroundColor Green
    Write-Host "NOTE: Install PostgreSQL extension from Extensions tab" -ForegroundColor Yellow
} else {
    Write-Host "Azure Data Studio installed - launch from Start Menu" -ForegroundColor Yellow
}
