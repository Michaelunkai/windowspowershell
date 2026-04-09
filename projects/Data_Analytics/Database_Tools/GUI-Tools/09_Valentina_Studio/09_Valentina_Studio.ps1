# Valentina Studio - Fully Automatic Setup with TovPlay Database
$ErrorActionPreference = "SilentlyContinue"

$DB_HOST = "45.148.28.196"
$DB_PORT = "5432"
$DB_NAME = "TovPlay"
$DB_USER = "raz@tovtech.org"
$DB_PASS = "CaptainForgotCreatureBreak"

Write-Host "=== Valentina Studio ===" -ForegroundColor Cyan
Write-Host "Auto-installing and configuring TovPlay database..." -ForegroundColor Yellow

# Find or install Valentina Studio
$valentinaPaths = @(
    "${env:ProgramFiles}\Valentina\Valentina Studio\VStudio.exe",
    "${env:ProgramFiles}\Valentina\VStudio.exe",
    "${env:ProgramFiles(x86)}\Valentina\Valentina Studio\VStudio.exe",
    "$env:LOCALAPPDATA\Programs\Valentina\VStudio.exe"
)
$valentinaExe = $null
foreach ($p in $valentinaPaths) { if (Test-Path $p) { $valentinaExe = $p; break } }

if (!$valentinaExe) {
    Write-Host "Downloading Valentina Studio..." -ForegroundColor Cyan
    $installer = "$env:TEMP\vstudio_setup.exe"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Try multiple download sources
    $urls = @(
        "https://www.valentina-db.com/download/studio/win64/vstudio_x64_14_5.exe",
        "https://www.valentina-db.com/download/studio/win64/vstudio_x64_14_4.exe",
        "https://valentina-db.com/download/studio/win64/vstudio_x64_latest.exe"
    )
    
    $downloaded = $false
    foreach ($url in $urls) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing -TimeoutSec 60
            if (Test-Path $installer) { $downloaded = $true; break }
        } catch { continue }
    }
    
    if ($downloaded) {
        Write-Host "Installing Valentina Studio..." -ForegroundColor Cyan
        Start-Process $installer -ArgumentList "/VERYSILENT /NORESTART" -Wait
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        foreach ($p in $valentinaPaths) { if (Test-Path $p) { $valentinaExe = $p; break } }
    }
}

# Create Valentina Studio bookmarks
$valentinaConfig = "$env:APPDATA\Paradigma Software\Valentina Studio"
if (!(Test-Path $valentinaConfig)) { New-Item -ItemType Directory -Path $valentinaConfig -Force | Out-Null }

$bookmarkXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Bookmarks>
    <Bookmark name="TovPlay Production">
        <Server>$DB_HOST</Server>
        <Port>$DB_PORT</Port>
        <Database>$DB_NAME</Database>
        <User>$DB_USER</User>
        <Type>PostgreSQL</Type>
    </Bookmark>
</Bookmarks>
"@
$bookmarkXml | Out-File -FilePath "$valentinaConfig\bookmarks.xml" -Encoding UTF8 -Force

if ($valentinaExe) {
    Write-Host "Launching Valentina Studio..." -ForegroundColor Green
    Start-Process $valentinaExe
    Write-Host "SUCCESS: Valentina Studio launched!" -ForegroundColor Green
} else {
    Write-Host "Valentina Studio: Download from https://valentina-db.com/en/studio/download" -ForegroundColor Yellow
    Start-Process "https://valentina-db.com/en/studio/download"
}
Write-Host "Connection: Host=$DB_HOST Port=$DB_PORT User=$DB_USER Pass=$DB_PASS" -ForegroundColor Yellow
