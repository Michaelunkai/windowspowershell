# DBeaver Community - Fully Automatic Setup with TovPlay Database
$ErrorActionPreference = "SilentlyContinue"

# Database credentials
$DB_HOST = "45.148.28.196"
$DB_PORT = "5432"
$DB_NAME = "TovPlay"
$DB_USER = "raz@tovtech.org"
$DB_PASS = "CaptainForgotCreatureBreak"

Write-Host "=== DBeaver Community Edition ===" -ForegroundColor Cyan
Write-Host "Auto-installing and configuring TovPlay database..." -ForegroundColor Yellow

# Find or install DBeaver
$dbeaverPaths = @(
    "$env:ProgramFiles\DBeaver\dbeaver.exe",
    "$env:ProgramFiles\dbeaver-ce\dbeaver.exe",
    "${env:ProgramFiles(x86)}\DBeaver\dbeaver.exe",
    "$env:LOCALAPPDATA\Programs\DBeaver\dbeaver.exe"
)
$dbeaverExe = $null
foreach ($p in $dbeaverPaths) { if (Test-Path $p) { $dbeaverExe = $p; break } }

if (!$dbeaverExe) {
    Write-Host "Installing DBeaver via winget..." -ForegroundColor Cyan
    winget install --id=dbeaver.dbeaver -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Start-Sleep -Seconds 5
    foreach ($p in $dbeaverPaths) { if (Test-Path $p) { $dbeaverExe = $p; break } }
}

if (!$dbeaverExe) {
    # Fallback: direct download
    Write-Host "Downloading DBeaver directly..." -ForegroundColor Cyan
    $installer = "$env:TEMP\dbeaver-setup.exe"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://dbeaver.io/files/dbeaver-ce-latest-x86_64-setup.exe" -OutFile $installer -UseBasicParsing
    Start-Process $installer -ArgumentList "/S" -Wait
    Remove-Item $installer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    foreach ($p in $dbeaverPaths) { if (Test-Path $p) { $dbeaverExe = $p; break } }
}

# Create DBeaver workspace with pre-configured connection
$dbeaverWorkspace = "$env:APPDATA\DBeaverData\workspace6\General\.dbeaver"
if (!(Test-Path $dbeaverWorkspace)) { New-Item -ItemType Directory -Path $dbeaverWorkspace -Force | Out-Null }

# Create data-sources.json with TovPlay connection
$dataSourcesPath = "$dbeaverWorkspace\data-sources.json"
$dataSourcesJson = @"
{
    "folders": {},
    "connections": {
        "postgresql-tovplay-production": {
            "provider": "postgresql",
            "driver": "postgres-jdbc",
            "name": "TovPlay Production",
            "save-password": true,
            "read-only": false,
            "configuration": {
                "host": "$DB_HOST",
                "port": "$DB_PORT",
                "database": "$DB_NAME",
                "user": "$DB_USER",
                "password": "$DB_PASS",
                "url": "jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}",
                "type": "dev",
                "color": "0,128,0"
            }
        }
    },
    "connection-types": {
        "dev": {
            "name": "Development",
            "color": "0,128,0",
            "auto-commit": true
        }
    }
}
"@
$dataSourcesJson | Out-File -FilePath $dataSourcesPath -Encoding UTF8 -Force

# Create credentials file
$credentialsPath = "$dbeaverWorkspace\credentials-config.json"
$credentialsJson = @"
{
    "postgresql-tovplay-production": {
        "#connection": {
            "user": "$DB_USER",
            "password": "$DB_PASS"
        }
    }
}
"@
$credentialsJson | Out-File -FilePath $credentialsPath -Encoding UTF8 -Force

if ($dbeaverExe) {
    Write-Host "Launching DBeaver with TovPlay database..." -ForegroundColor Green
    Start-Process $dbeaverExe
    Write-Host "SUCCESS: DBeaver configured with TovPlay Production database" -ForegroundColor Green
} else {
    Write-Host "DBeaver installed - launch from Start Menu. Connection pre-configured!" -ForegroundColor Yellow
}
