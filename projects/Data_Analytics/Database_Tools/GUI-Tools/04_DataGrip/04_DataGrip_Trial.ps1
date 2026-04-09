# DataGrip by JetBrains - Fully Automatic Setup (30-day trial)
$ErrorActionPreference = "SilentlyContinue"

$DB_HOST = "45.148.28.196"
$DB_PORT = "5432"
$DB_NAME = "TovPlay"
$DB_USER = "raz@tovtech.org"
$DB_PASS = "CaptainForgotCreatureBreak"

Write-Host "=== DataGrip (JetBrains) ===" -ForegroundColor Cyan
Write-Host "Auto-installing and configuring TovPlay database..." -ForegroundColor Yellow

# Find DataGrip
$dataGripPaths = @(
    "$env:ProgramFiles\JetBrains\DataGrip*\bin\datagrip64.exe",
    "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\datagrip\ch-0\*\bin\datagrip64.exe"
)
$dataGripExe = $null
foreach ($pattern in $dataGripPaths) {
    $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $dataGripExe = $found.FullName; break }
}

if (!$dataGripExe) {
    Write-Host "Installing DataGrip via winget..." -ForegroundColor Cyan
    winget install --id=JetBrains.DataGrip -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Start-Sleep -Seconds 10
    foreach ($pattern in $dataGripPaths) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $dataGripExe = $found.FullName; break }
    }
}

# Create DataGrip data source configuration
$dataGripConfig = "$env:APPDATA\JetBrains\DataGrip*"
$configDirs = Get-ChildItem -Path "$env:APPDATA\JetBrains" -Filter "DataGrip*" -Directory -ErrorAction SilentlyContinue
foreach ($dir in $configDirs) {
    $optionsDir = Join-Path $dir.FullName "options"
    if (!(Test-Path $optionsDir)) { New-Item -ItemType Directory -Path $optionsDir -Force | Out-Null }
    
    $dataSourceXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="DataSourceManagerImpl" format="xml" multifile-model="true">
    <data-source source="LOCAL" name="TovPlay Production" uuid="tovplay-prod">
      <driver-ref>postgresql</driver-ref>
      <synchronize>true</synchronize>
      <jdbc-driver>org.postgresql.Driver</jdbc-driver>
      <jdbc-url>jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}</jdbc-url>
      <user-name>$DB_USER</user-name>
    </data-source>
  </component>
</project>
"@
    $dataSourceXml | Out-File -FilePath "$optionsDir\dataSources.xml" -Encoding UTF8 -Force
}

if ($dataGripExe) {
    Write-Host "Launching DataGrip..." -ForegroundColor Green
    Start-Process $dataGripExe
    Write-Host "SUCCESS: DataGrip configured with TovPlay!" -ForegroundColor Green
    Write-Host "Password when prompted: $DB_PASS" -ForegroundColor Yellow
} else {
    Write-Host "DataGrip installed - launch from Start Menu" -ForegroundColor Yellow
    Write-Host "Connection: Host=$DB_HOST Port=$DB_PORT DB=$DB_NAME User=$DB_USER" -ForegroundColor Yellow
}
