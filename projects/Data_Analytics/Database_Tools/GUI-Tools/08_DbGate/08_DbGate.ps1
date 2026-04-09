# DbGate - Fully Automatic Setup with TovPlay Database
$ErrorActionPreference = "SilentlyContinue"

$DB_HOST = "45.148.28.196"
$DB_PORT = "5432"
$DB_NAME = "TovPlay"
$DB_USER = "raz@tovtech.org"
$DB_PASS = "CaptainForgotCreatureBreak"

Write-Host "=== DbGate ===" -ForegroundColor Cyan
Write-Host "Auto-installing and configuring TovPlay database..." -ForegroundColor Yellow

# Find or install DbGate
$dbgatePaths = @(
    "$env:LOCALAPPDATA\Programs\dbgate\DbGate.exe",
    "$env:ProgramFiles\DbGate\DbGate.exe",
    "$env:LOCALAPPDATA\dbgate\DbGate.exe"
)
$dbgateExe = $null
foreach ($p in $dbgatePaths) { if (Test-Path $p) { $dbgateExe = $p; break } }

if (!$dbgateExe) {
    Write-Host "Installing DbGate via winget..." -ForegroundColor Cyan
    winget install --id=JanProchazka.dbgate -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Start-Sleep -Seconds 10
    foreach ($p in $dbgatePaths) { if (Test-Path $p) { $dbgateExe = $p; break } }
}

# Create DbGate connection configuration
$dbgateData = "$env:APPDATA\dbgate-data"
if (!(Test-Path $dbgateData)) { New-Item -ItemType Directory -Path $dbgateData -Force | Out-Null }

# DbGate uses YAML-like files for connections
$connectionsDir = "$dbgateData\connections"
if (!(Test-Path $connectionsDir)) { New-Item -ItemType Directory -Path $connectionsDir -Force | Out-Null }

$connectionYaml = @"
displayName: TovPlay Production
engine: postgres@dbgate-plugin-postgres
server: $DB_HOST
port: $DB_PORT
user: $DB_USER
password: $DB_PASS
defaultDatabase: $DB_NAME
singleDatabase: true
isReadOnly: false
"@
$connectionYaml | Out-File -FilePath "$connectionsDir\tovplay-prod.con.yaml" -Encoding UTF8 -Force

if ($dbgateExe) {
    Write-Host "Launching DbGate..." -ForegroundColor Green
    Start-Process $dbgateExe
    Write-Host "SUCCESS: DbGate configured with TovPlay!" -ForegroundColor Green
} else {
    # Search more locations
    $found = Get-ChildItem -Path "$env:LOCALAPPDATA" -Filter "DbGate.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        Write-Host "Launching DbGate from: $($found.FullName)" -ForegroundColor Green
        Start-Process $found.FullName
    } else {
        Write-Host "DbGate installed - launch from Start Menu" -ForegroundColor Yellow
    }
}
