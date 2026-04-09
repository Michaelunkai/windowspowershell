# Test Scanner Script
Write-Host "Testing GameLauncherPro Scanner..." -ForegroundColor Cyan

# Check if app is running
$proc = Get-Process -Name "GameLauncherPro" -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "✓ GameLauncherPro is running (PID: $($proc.Id))" -ForegroundColor Green
}
else {
    Write-Host "✗ GameLauncherPro is not running" -ForegroundColor Red
}

# Check database
$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
if (Test-Path $dbPath) {
    $games = Get-Content $dbPath | ConvertFrom-Json
    Write-Host "`n=== Current Database ===" -ForegroundColor Cyan
    Write-Host "Total games: $($games.Count)" -ForegroundColor Yellow
    
    # Check for the missing games
    $missingGames = @("ninjagaidenragebound", "Nioh3", "Resident Evil 4")
    $found = @()
    $missing = @()
    
    foreach ($testGame in $missingGames) {
        $match = $games | Where-Object { $_.Name -like "*$testGame*" }
        if ($match) {
            $found += $testGame
            Write-Host "  ✓ Found: $($match.Name)" -ForegroundColor Green
        }
        else {
            $missing += $testGame
            Write-Host "  ✗ Missing: $testGame" -ForegroundColor Red
        }
    }
    
    Write-Host "`n=== Test Results ===" -ForegroundColor Cyan
    Write-Host "Found: $($found.Count)/$($missingGames.Count)" -ForegroundColor Yellow
    Write-Host "Missing: $($missing.Count)/$($missingGames.Count)" -ForegroundColor Yellow
    
    if ($missing.Count -eq 0) {
        Write-Host "`n🎉 ALL TESTS PASSED!" -ForegroundColor Green
    }
    else {
        Write-Host "`n⚠️ Tests incomplete - scan needed" -ForegroundColor Yellow
    }
}
else {
    Write-Host "✗ Database not found at: $dbPath" -ForegroundColor Red
}
