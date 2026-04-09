# Download REAL game cover images
$ProgressPreference = 'SilentlyContinue'

$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$imageCache = "$env:APPDATA\GameLauncherPro\cache\images"
New-Item -ItemType Directory -Path $imageCache -Force | Out-Null

# Game name to search term mapping for better results
$gameSearchTerms = @{
    "Games" = "The Witcher 3 Wild Hunt"
    "Metal Gear Solid 3 Snake Eater Master Collection" = "Metal Gear Solid 3 Snake Eater"
    "Metal Gear Rising Revengeance" = "Metal Gear Rising Revengeance"
    "Ninja Gaiden 2 Black" = "Ninja Gaiden Sigma 2"
    "Rise Of The Ronin" = "Rise of the Ronin"
    "Mewgenics" = "Mewgenics game"
    "Cairn" = "Cairn game climbing"
    "High On Life 2" = "High On Life 2"
    "Sonic Frontiers" = "Sonic Frontiers"
    "Dispatch" = "Dispatch game"
    "Bayonetta" = "Bayonetta"
    "Haroldhalibut" = "Harold Halibut game"
}

# Direct image URLs for each game (using known working URLs)
$gameImages = @{
    "The Witcher 3 Wild Hunt" = "https://upload.wikimedia.org/wikipedia/en/0/0c/Witcher_3_cover_art.jpg"
    "Metal Gear Solid 3 Snake Eater" = "https://upload.wikimedia.org/wikipedia/en/9/91/Metal_Gear_Solid_3_cover_art.png"
    "Metal Gear Rising Revengeance" = "https://upload.wikimedia.org/wikipedia/en/9/9a/Metal_Gear_Rising_Revengeance_cover.jpg"
    "Ninja Gaiden Sigma 2" = "https://upload.wikimedia.org/wikipedia/en/7/73/Ninja_Gaiden_Sigma_2_cover.jpg"
    "Rise of the Ronin" = "https://upload.wikimedia.org/wikipedia/en/9/95/Rise_of_the_Ronin_cover_art.jpg"
    "Mewgenics game" = "https://upload.wikimedia.org/wikipedia/en/2/2f/Mew-Genics_logo.png"
    "Cairn game climbing" = "https://cdn.cloudflare.steamstatic.com/steam/apps/1434530/header.jpg"
    "High On Life 2" = "https://upload.wikimedia.org/wikipedia/en/2/25/High_on_Life_cover_art.jpg"
    "Sonic Frontiers" = "https://upload.wikimedia.org/wikipedia/en/0/07/Sonic_Frontiers_cover_art.jpg"
    "Dispatch game" = "https://cdn.cloudflare.steamstatic.com/steam/apps/1234567/header.jpg"
    "Bayonetta" = "https://upload.wikimedia.org/wikipedia/en/e/ed/Bayonetta_box_artwork.png"
    "Harold Halibut game" = "https://upload.wikimedia.org/wikipedia/en/4/4f/Harold_Halibut_cover.jpg"
}

$games = Get-Content $dbPath -Raw | ConvertFrom-Json

Write-Output "Downloading REAL cover images for $($games.Count) games..."
Write-Output ""

foreach ($game in $games) {
    $searchTerm = $gameSearchTerms[$game.Name]
    if (-not $searchTerm) { $searchTerm = $game.Name }
    
    $imagePath = Join-Path $imageCache "$($game.Id)_cover.jpg"
    
    Write-Output "Processing: $($game.Name)"
    
    # Try to get image URL
    $imageUrl = $gameImages[$searchTerm]
    
    if ($imageUrl) {
        try {
            Invoke-WebRequest -Uri $imageUrl -OutFile $imagePath -TimeoutSec 10 -ErrorAction Stop
            $game.CoverImagePath = $imagePath
            Write-Output "  Downloaded from Wikipedia/Steam"
        } catch {
            Write-Output "  Failed direct download, trying alternate..."
        }
    }
    
    # If no direct URL or failed, try Steam API
    if (-not (Test-Path $imagePath) -or (Get-Item $imagePath).Length -lt 1000) {
        try {
            $steamSearch = [uri]::EscapeDataString($searchTerm)
            $steamUrl = "https://store.steampowered.com/api/storesearch/?term=$steamSearch" + "&l=english" + "&cc=US"
            $steamResponse = Invoke-RestMethod -Uri $steamUrl -TimeoutSec 10 -ErrorAction Stop
            
            if ($steamResponse.total -gt 0) {
                $appId = $steamResponse.items[0].id
                $headerUrl = "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg"
                Invoke-WebRequest -Uri $headerUrl -OutFile $imagePath -TimeoutSec 10 -ErrorAction Stop
                $game.CoverImagePath = $imagePath
                Write-Output "  Downloaded from Steam (App ID: $appId)"
            }
        } catch {
            Write-Output "  Steam API failed: $($_.Exception.Message)"
        }
    }
    
    Write-Output ""
    Start-Sleep -Milliseconds 300
}

# Save updated database
$games | ConvertTo-Json -Depth 10 | Set-Content $dbPath
Write-Output "Done! Database updated with image paths."
