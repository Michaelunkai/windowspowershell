# ============================================================
# cleanup-c-drive.ps1 - Safe C Drive Cleanup Script
# Usage: Run directly or via `cleanup` alias in profile
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

function Get-FreeSpaceGB {
    $disk = Get-PSDrive C
    return [math]::Round($disk.Free / 1GB, 2)
}

function Get-FreeMB {
    $disk = Get-PSDrive C
    return [math]::Round($disk.Free / 1MB, 0)
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  C Drive Cleanup Script" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$beforeMB = Get-FreeMB
$beforeGB = Get-FreeSpaceGB
Write-Host "BEFORE: C drive free space = ${beforeGB} GB (${beforeMB} MB)" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# SECTION 1: Windows Temp Files
# ============================================================
Write-Host "[1/7] Cleaning Windows Temp files..." -ForegroundColor Green
Remove-Item "$env:TEMP\*" -Recurse -Force
Remove-Item "C:\Windows\Temp\*" -Recurse -Force

# ============================================================
# SECTION 2: Prefetch
# ============================================================
Write-Host "[2/7] Cleaning Prefetch..." -ForegroundColor Green
Remove-Item "C:\Windows\Prefetch\*" -Recurse -Force

# ============================================================
# SECTION 3: Windows Error Reporting (WER)
# ============================================================
Write-Host "[3/7] Cleaning Windows Error Reporting..." -ForegroundColor Green
Remove-Item "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force
Remove-Item "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*" -Recurse -Force
Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\WER\*" -Recurse -Force

# ============================================================
# SECTION 4: Browser Caches
# ============================================================
Write-Host "[4/7] Cleaning browser caches..." -ForegroundColor Green
# Chrome
Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force
Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*" -Recurse -Force
Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache\*" -Recurse -Force
# Edge
Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force
Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\*" -Recurse -Force
# Firefox
$firefoxProfiles = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $firefoxProfiles) {
    Get-ChildItem $firefoxProfiles -Directory | ForEach-Object {
        Remove-Item "$($_.FullName)\cache2\*" -Recurse -Force
    }
}

# ============================================================
# SECTION 5: Thumbnail Cache
# ============================================================
Write-Host "[5/7] Cleaning thumbnail cache..." -ForegroundColor Green
Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force

# ============================================================
# SECTION 6: Windows Update Cache (SoftwareDistribution\Download)
# ============================================================
Write-Host "[6/7] Cleaning Windows Update download cache..." -ForegroundColor Green
Stop-Service -Name wuauserv -Force
Start-Sleep -Seconds 2
Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force
Start-Service -Name wuauserv

# ============================================================
# SECTION 7: npm and pip caches
# ============================================================
Write-Host "[7/7] Cleaning npm and pip caches..." -ForegroundColor Green
# npm
$npmCache = "$env:APPDATA\npm-cache"
if (Test-Path $npmCache) {
    Remove-Item "$npmCache\*" -Recurse -Force
}
# pip
$pipCache = "$env:LOCALAPPDATA\pip\cache"
if (Test-Path $pipCache) {
    Remove-Item "$pipCache\*" -Recurse -Force
}

# ============================================================
# RESULTS
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
$afterMB = Get-FreeMB
$afterGB = Get-FreeSpaceGB
$freedMB = $afterMB - $beforeMB
$freedGB = [math]::Round($freedMB / 1024, 2)

Write-Host "AFTER:  C drive free space = ${afterGB} GB (${afterMB} MB)" -ForegroundColor Yellow
Write-Host ""
if ($freedMB -gt 0) {
    Write-Host "Freed: ${freedMB} MB (${freedGB} GB)" -ForegroundColor Green
} else {
    Write-Host "No significant space freed (already clean or files in use)" -ForegroundColor Gray
}
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
