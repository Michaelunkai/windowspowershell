# Test all game launches
$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$games = Get-Content $dbPath -Raw | ConvertFrom-Json

Write-Output "Testing $($games.Count) game launches..."
Write-Output ""

$working = 0
$failed = 0

foreach ($game in $games) {
    Write-Output "Testing: $($game.Name)"
    
    if (!(Test-Path $game.ExecutablePath)) {
        Write-Output "  ✗ EXE NOT FOUND: $($game.ExecutablePath)"
        $failed++
        continue
    }
    
    try {
        $process = Start-Process -FilePath $game.ExecutablePath -WorkingDirectory (Split-Path $game.ExecutablePath) -PassThru -ErrorAction Stop
        Start-Sleep -Seconds 2
        
        if ($process.HasExited) {
            Write-Output "  ⚠ Launched but exited immediately"
            $working++
        } else {
            Write-Output "  ✓ WORKING - Process running (PID: $($process.Id))"
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $working++
        }
    } catch {
        Write-Output "  ✗ FAILED: $($_.Exception.Message)"
        $failed++
    }
    
    Write-Output ""
}

Write-Output "Results: $working working, $failed failed"
