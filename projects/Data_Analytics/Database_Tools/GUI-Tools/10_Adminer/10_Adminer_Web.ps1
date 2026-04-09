# Adminer - Fully Automatic Web-Based Database GUI
$ErrorActionPreference = "SilentlyContinue"

$DB_HOST = "45.148.28.196"
$DB_PORT = "5432"
$DB_NAME = "TovPlay"
$DB_USER = "raz@tovtech.org"
$DB_PASS = "CaptainForgotCreatureBreak"

Write-Host "=== Adminer (Web-Based) ===" -ForegroundColor Cyan
Write-Host "Auto-configuring TovPlay database access..." -ForegroundColor Yellow

# Method 1: Try Docker (cleanest)
$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($docker) {
    Write-Host "Starting Adminer via Docker..." -ForegroundColor Green
    docker rm -f adminer-tovplay 2>$null
    docker run -d --name adminer-tovplay -p 8080:8080 -e ADMINER_DEFAULT_SERVER="${DB_HOST}:${DB_PORT}" adminer
    Start-Sleep -Seconds 3
    
    $encodedUser = [System.Uri]::EscapeDataString($DB_USER)
    $url = "http://localhost:8080/?pgsql=${DB_HOST}%3A${DB_PORT}&username=${encodedUser}&db=${DB_NAME}"
    Start-Process $url
    Write-Host "SUCCESS: Adminer running at http://localhost:8080" -ForegroundColor Green
    Write-Host "Password: $DB_PASS" -ForegroundColor Yellow
    exit 0
}

# Method 2: Try PHP if installed
$php = Get-Command php -ErrorAction SilentlyContinue
if ($php) {
    $adminerDir = "$env:TEMP\adminer"
    if (!(Test-Path $adminerDir)) { New-Item -ItemType Directory -Path $adminerDir -Force | Out-Null }
    
    Write-Host "Downloading Adminer PHP..." -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php" -OutFile "$adminerDir\adminer.php" -UseBasicParsing
    
    $encodedUser = [System.Uri]::EscapeDataString($DB_USER)
    $url = "http://localhost:8080/adminer.php?pgsql=${DB_HOST}%3A${DB_PORT}&username=${encodedUser}&db=${DB_NAME}"
    
    Write-Host "Starting PHP server..." -ForegroundColor Green
    Start-Process powershell -ArgumentList "-Command", "cd '$adminerDir'; php -S localhost:8080" -WindowStyle Minimized
    Start-Sleep -Seconds 2
    Start-Process $url
    Write-Host "SUCCESS: Adminer running at $url" -ForegroundColor Green
    Write-Host "Password: $DB_PASS" -ForegroundColor Yellow
    exit 0
}

# Method 3: Use online Adminer alternative
Write-Host "Opening online database viewer..." -ForegroundColor Yellow
Write-Host "Use these credentials:" -ForegroundColor Cyan
Write-Host "  Host: $DB_HOST" -ForegroundColor White
Write-Host "  Port: $DB_PORT" -ForegroundColor White  
Write-Host "  Database: $DB_NAME" -ForegroundColor White
Write-Host "  User: $DB_USER" -ForegroundColor White
Write-Host "  Password: $DB_PASS" -ForegroundColor White

# Open a web-based SQL client
Start-Process "https://sqlectron.github.io/"

Write-Host "`nAlternatively, install Docker Desktop for full Adminer support" -ForegroundColor Yellow
