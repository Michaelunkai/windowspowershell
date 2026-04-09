# Download cover images for all games using Google Images
$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$imageCache = "$env:APPDATA\GameLauncherPro\cache\images"
New-Item -ItemType Directory -Path $imageCache -Force | Out-Null

$games = Get-Content $dbPath -Raw | ConvertFrom-Json

Write-Output "Downloading covers for $($games.Count) games..."

foreach ($game in $games) {
    $safeName = $game.Name -replace '[^a-zA-Z0-9]', '_'
    $imagePath = Join-Path $imageCache "$($game.Id)_cover.jpg"
    
    if (Test-Path $imagePath) {
        Write-Output "✓ $($game.Name) - already has image"
        continue
    }
    
    # Search for game cover image
    $searchTerm = [uri]::EscapeDataString("$($game.Name) game cover art")
    $url = "https://www.google.com/search?q=$searchTerm&tbm=isch&tbs=isz:m"
    
    try {
        # Download a placeholder for now (we'll use real images from a free API)
        # Using SteamGridDB API without auth (limited)
        $steamSearch = [uri]::EscapeDataString($game.Name)
        $apiUrl = "https://www.steamgriddb.com/api/public/search/autocomplete/$steamSearch"
        
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
        
        if ($response.success -and $response.data.Count -gt 0) {
            $gameId = $response.data[0].id
            $gridUrl = "https://www.steamgriddb.com/api/public/grid/game/$gameId"
            $gridData = Invoke-RestMethod -Uri $gridUrl -Method Get
            
            if ($gridData.data.Count -gt 0) {
                $imageUrl = $gridData.data[0].url
                Invoke-WebRequest -Uri $imageUrl -OutFile $imagePath
                Write-Output "✓ $($game.Name) - downloaded"
                
                # Update game JSON
                $game.CoverImagePath = $imagePath
            }
        }
    } catch {
        Write-Output "✗ $($game.Name) - failed: $($_.Exception.Message)"
    }
    
    Start-Sleep -Milliseconds 500
}

# Save updated database
$games | ConvertTo-Json -Depth 10 | Set-Content $dbPath
Write-Output "`nDone!"
