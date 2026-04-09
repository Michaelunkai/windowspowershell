# TinderBot - ACTUAL VISIBLE CHROME
# You WILL see Chrome with your own eyes!

$ErrorActionPreference = "Continue"

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host " TinderBot - REAL CHROME VISIBLE MODE" -ForegroundColor Cyan  
Write-Host "================================================`n" -ForegroundColor Cyan

# Find Chrome
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (!(Test-Path $chromePath)) {
    $chromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}

if (!(Test-Path $chromePath)) {
    Write-Host "ERROR: Chrome not found!" -ForegroundColor Red
    exit 1
}

# Launch Chrome in a NEW VISIBLE WINDOW
Write-Host "[STEP 1] Launching Chrome..." -ForegroundColor Yellow
Write-Host "   Opening Tinder in a NEW Chrome window..." -ForegroundColor Cyan
Write-Host "   YOU SHOULD SEE IT NOW!" -ForegroundColor Green

Start-Process $chromePath -ArgumentList @(
    "--new-window",
    "https://tinder.com"
)

Start-Sleep -Seconds 5

Write-Host "`n================================================" -ForegroundColor Green
Write-Host " CHROME IS OPEN!" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Green

Write-Host "DO YOU SEE THE CHROME WINDOW? (Y/N): " -NoNewline -ForegroundColor Yellow
$response = Read-Host

if ($response -ne "Y" -and $response -ne "y") {
    Write-Host "`nCheck your taskbar - Chrome should be there!" -ForegroundColor Red
    exit 1
}

Write-Host "`nOK! Now follow these steps IN THE CHROME WINDOW:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Click 'Log in' button" -ForegroundColor White
Write-Host "2. Click 'Trouble Logging In?'" -ForegroundColor White
Write-Host "3. Enter your phone: 547632418" -ForegroundColor White
Write-Host "4. Enter the SMS code you receive" -ForegroundColor White
Write-Host "5. When you see the swipe screen, press ANY KEY here..." -ForegroundColor Yellow
Write-Host ""

Read-Host "Press ENTER when you're on the swipe screen"

Write-Host "`n================================================" -ForegroundColor Green
Write-Host " STARTING AUTO-SWIPE!" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Green

Write-Host "Now I'll start auto-swiping right in that Chrome window..." -ForegroundColor Cyan
Write-Host "Keep watching the Chrome window!" -ForegroundColor Green
Write-Host ""

# Import the Windows automation library
Add-Type -AssemblyName System.Windows.Forms

$likeCount = 0

for ($i = 1; $i -le 1000; $i++) {
    
    # Simulate Right Arrow keypress (Like)
    [System.Windows.Forms.SendKeys]::SendWait("{RIGHT}")
    $likeCount++
    
    # Progress
    if ($likeCount % 5 -eq 0) {
        Write-Host "   >>> $likeCount LIKES (watch Chrome!)" -ForegroundColor Green
    }
    
    # Human-like delay
    Start-Sleep -Milliseconds 700
    
    # Break every 50
    if ($likeCount % 50 -eq 0) {
        Write-Host "`n   Taking 5 second break...`n" -ForegroundColor Cyan
        Start-Sleep -Seconds 5
    }
    
    # Check if user wants to stop
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Escape') {
            Write-Host "`n`nSTOPPED by user." -ForegroundColor Red
            break
        }
    }
}

Write-Host "`n================================================" -ForegroundColor Green
Write-Host " COMPLETE!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "`n Total likes: $likeCount`n" -ForegroundColor Yellow
