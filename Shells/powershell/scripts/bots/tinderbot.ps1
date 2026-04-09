# TinderBot - Working Version
# Uses Playwright with Google login

Write-Host "`n================================================" -ForegroundColor Green
Write-Host " TinderBot - Auto Login & Swipe" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Green

# Kill existing browsers
Get-Process chrome, chromium -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "Starting TinderBot..." -ForegroundColor Cyan
Write-Host "- Opens Tinder" -ForegroundColor White
Write-Host "- Clicks Google login" -ForegroundColor White
Write-Host "- You complete Google auth (90 sec)" -ForegroundColor Yellow
Write-Host "- Auto-swipes forever!" -ForegroundColor Green

$env:PYTHONUNBUFFERED = "1"
python "$PSScriptRoot\tinderbot.py"
