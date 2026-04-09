#Requires -RunAsAdministrator
# aa.ps1 - Consolidate ALL .NET paths to default location permanently

$ErrorActionPreference = "Stop"
$defaultDotnet = "C:\Program Files\dotnet"

Write-Host "=== .NET Path Consolidation Script ===" -ForegroundColor Cyan
Write-Host "Target: $defaultDotnet" -ForegroundColor Yellow

# Get current Machine PATH
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")

Write-Host "`n[1/4] Current .NET paths in Machine PATH:" -ForegroundColor Green
$machinePath -split ";" | Where-Object { $_ -match "dotnet|\.net" } | ForEach-Object { Write-Host "  $_" }

Write-Host "`n[2/4] Current .NET paths in User PATH:" -ForegroundColor Green
$userPath -split ";" | Where-Object { $_ -match "dotnet|\.net" } | ForEach-Object { Write-Host "  $_" }

# Remove ALL dotnet-related paths from Machine PATH
Write-Host "`n[3/4] Removing all .NET paths from Machine PATH..." -ForegroundColor Yellow
$cleanMachinePaths = ($machinePath -split ";" | Where-Object {
    $_ -and ($_ -notmatch "dotnet|\.net|microsoft\.net")
}) -join ";"

# Remove ALL dotnet-related paths from User PATH
Write-Host "[3/4] Removing all .NET paths from User PATH..." -ForegroundColor Yellow
$cleanUserPaths = ($userPath -split ";" | Where-Object {
    $_ -and ($_ -notmatch "dotnet|\.net|microsoft\.net")
}) -join ";"

# Add default path to Machine PATH (at beginning for priority)
Write-Host "`n[4/4] Adding default path: $defaultDotnet" -ForegroundColor Yellow
$newMachinePath = "$defaultDotnet;$cleanMachinePaths"

# Apply changes permanently
[Environment]::SetEnvironmentVariable("Path", $newMachinePath, "Machine")
[Environment]::SetEnvironmentVariable("Path", $cleanUserPaths, "User")

# Also update current session
$env:Path = "$defaultDotnet;$cleanMachinePaths;$cleanUserPaths"

Write-Host "`n=== DONE ===" -ForegroundColor Green
Write-Host "New .NET paths in Machine PATH:" -ForegroundColor Cyan
[Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" | Where-Object { $_ -match "dotnet|\.net" } | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

Write-Host "`nVerification:" -ForegroundColor Cyan
where.exe dotnet
dotnet --version

Write-Host "`nRestart any open terminals for changes to take effect." -ForegroundColor Yellow

refreshenv; where.exe dotnet; dotnet --list-sdks; dotnet --list-runtimes
