# TinderBot - VISIBLE Chrome Version
# You can SEE it working in real-time!

$ErrorActionPreference = "Continue"

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host " TinderBot - VISIBLE MODE" -ForegroundColor Cyan  
Write-Host " Watch it work in Chrome!" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Cyan

$phoneNumber = "547632418"

# Step 1: Open Tinder in VISIBLE Chrome
Write-Host "[1/6] Opening Tinder in Chrome (VISIBLE)..." -ForegroundColor Yellow
openclaw browser --action=open --profile=chrome --targetUrl="https://tinder.com" 2>&1 | Out-Null
Start-Sleep -Seconds 6

Write-Host "   > Chrome window should be visible now!" -ForegroundColor Green

# Step 2: Click Login
Write-Host "[2/6] Clicking login button..." -ForegroundColor Yellow
openclaw browser --action=act --profile=chrome --request='{\"kind\":\"click\",\"ref\":\"e46\"}' 2>&1 | Out-Null
Start-Sleep -Seconds 4

# Step 3: Handle "Trouble Logging In" for phone option
Write-Host "[3/6] Looking for phone login..." -ForegroundColor Yellow
$snapshot = openclaw browser --action=snapshot --profile=chrome --refs=aria 2>&1 | Out-String

if ($snapshot -match 'button "Trouble Logging In\?" \[ref=([^\]]+)\]') {
    $troubleRef = $matches[1]
    Write-Host "   > Clicking 'Trouble Logging In'..." -ForegroundColor Green
    openclaw browser --action=act --profile=chrome --request="{`"kind`":`"click`",`"ref`":`"$troubleRef`"}" 2>&1 | Out-Null
    Start-Sleep -Seconds 3
}

# Step 4: Enter phone number
Write-Host "[4/6] Auto-typing phone number..." -ForegroundColor Yellow
Write-Host "   > +972$phoneNumber" -ForegroundColor Cyan
Write-Host "   > WATCH THE CHROME WINDOW!" -ForegroundColor Green

openclaw browser --action=act --profile=chrome --request="{`"kind`":`"type`",`"text`":`"$phoneNumber`"}" 2>&1 | Out-Null
Start-Sleep -Seconds 2

openclaw browser --action=act --profile=chrome --request='{\"kind\":\"press\",\"key\":\"Enter\"}' 2>&1 | Out-Null
Start-Sleep -Seconds 3

Write-Host "`n   =====================================" -ForegroundColor Red
Write-Host "   ENTER SMS CODE IN THE CHROME WINDOW" -ForegroundColor Red
Write-Host "   Waiting 60 seconds..." -ForegroundColor Yellow
Write-Host "   =====================================" -ForegroundColor Red
Write-Host ""

Start-Sleep -Seconds 60

# Step 5: Navigate to swipe screen
Write-Host "[5/6] Loading swipe screen..." -ForegroundColor Yellow
openclaw browser --action=navigate --profile=chrome --targetUrl="https://tinder.com/app/recs" 2>&1 | Out-Null
Start-Sleep -Seconds 7

# Step 6: AUTO-LIKE LOOP (VISIBLE!)
Write-Host "[6/6] AUTO-LIKE STARTING...`n" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host " WATCH THE CHROME WINDOW!" -ForegroundColor Green
Write-Host " You'll see profiles swiping automatically!" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Cyan

$likeCount = 0

for ($i = 1; $i -le 1000; $i++) {
    
    # Check for limit every 15 likes
    if ($i % 15 -eq 1 -and $i -gt 1) {
        $snapshot = openclaw browser --action=snapshot --profile=chrome 2>&1 | Out-String
        
        if ($snapshot -match "out of.*like|limit|Get Tinder|Plus|Gold") {
            Write-Host "`n================================================" -ForegroundColor Red
            Write-Host " DAILY LIMIT REACHED!" -ForegroundColor Red  
            Write-Host "================================================" -ForegroundColor Red
            Write-Host "`n Total: $likeCount likes`n" -ForegroundColor Yellow
            break
        }
    }
    
    # Send like (Right Arrow) - WATCH IT SWIPE!
    openclaw browser --action=act --profile=chrome --request='{\"kind\":\"press\",\"key\":\"ArrowRight\"}' 2>&1 | Out-Null
    $likeCount++
    
    # Show progress
    if ($likeCount % 5 -eq 0) {
        Write-Host " >>> $likeCount LIKES SENT (watch Chrome!)" -ForegroundColor Green
    }
    
    # Slower delay so you can SEE each swipe (800ms = 0.8 seconds)
    Start-Sleep -Milliseconds 800
    
    # Break every 80 likes
    if ($likeCount % 80 -eq 0 -and $likeCount -gt 0) {
        Write-Host "`n --- Break after $likeCount ---`n" -ForegroundColor Cyan
        Start-Sleep -Seconds 7
    }
}

Write-Host "`n================================================" -ForegroundColor Green
Write-Host " COMPLETE!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "`n Total: $likeCount likes" -ForegroundColor Yellow
Write-Host " Chrome window will stay open`n" -ForegroundColor Gray
