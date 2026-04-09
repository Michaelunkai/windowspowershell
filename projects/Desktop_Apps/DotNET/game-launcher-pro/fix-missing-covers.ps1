# Fix missing cover images for existing games
$ProgressPreference = 'SilentlyContinue'

$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$imageCache = "$env:APPDATA\GameLauncherPro\cache\images"

$games = Get-Content $dbPath | ConvertFrom-Json
$fixed = 0

foreach ($game in $games) {
    if (-not $game.CoverImagePath -or -not (Test-Path $game.CoverImagePath)) {
        Write-Output "Fixing: $($game.Name)"
        
        $imagePath = Join-Path $imageCache "$($game.Id)_cover.jpg"
        
        try {
            $searchUrl = "https://steamcommunity.com/actions/SearchApps/$([uri]::EscapeDataString($game.Name))"
            $response = Invoke-WebRequest -Uri $searchUrl -TimeoutSec 10 -ErrorAction Stop
            
            if ($response.Content -match '"appid":(\d+)') {
                $appid = $matches[1]
                $headerUrl = "https://cdn.cloudflare.steamstatic.com/steam/apps/$appid/header.jpg"
                
                Invoke-WebRequest -Uri $headerUrl -OutFile $imagePath -TimeoutSec 15 -ErrorAction Stop
                
                if (Test-Path $imagePath) {
                    $game.CoverImagePath = $imagePath
                    $fixed++
                    Write-Output "  OK: Downloaded from Steam (ID: $appid)"
                } else {
                    Write-Output "  FAIL: Download failed"
                }
            } else {
                Write-Output "  SKIP: Not found on Steam"
            }
        } catch {
            Write-Output "  ERROR: $($_.Exception.Message)"
        }
        
        Start-Sleep -Milliseconds 500
    }
}

if ($fixed -gt 0) {
    Write-Output ""
    Write-Output "Saving database..."
    $games | ConvertTo-Json -Depth 10 | Set-Content $dbPath
    Write-Output "Fixed $fixed game covers"
} else {
    Write-Output ""
    Write-Output "All games already have covers"
}
