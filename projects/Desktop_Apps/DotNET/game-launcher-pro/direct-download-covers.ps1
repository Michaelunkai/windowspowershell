# Direct download game covers with known working URLs
$ProgressPreference = 'SilentlyContinue'

$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$imageCache = "$env:APPDATA\GameLauncherPro\cache\images"

# Known Steam App IDs for direct download
$steamAppIds = @{
    "Games" = 292030  # Witcher 3
    "Metal Gear Solid 3 Snake Eater Master Collection" = 2131640
    "Metal Gear Rising Revengeance" = 235460
    "Ninja Gaiden 2 Black" = 1580790  # Ninja Gaiden Master Collection
    "Rise Of The Ronin" = 2126740
    "Mewgenics" = 2162270
    "Cairn" = 1434530
    "High On Life 2" = 1583230  # High On Life (original)
    "Sonic Frontiers" = 1237320
    "Dispatch" = 0  # Not on Steam
    "Bayonetta" = 460790
    "Haroldhalibut" = 1059030
}

$games = Get-Content $dbPath -Raw | ConvertFrom-Json

Write-Output "Downloading covers using Steam CDN..."

foreach ($game in $games) {
    $appId = $steamAppIds[$game.Name]
    $imagePath = Join-Path $imageCache "$($game.Id)_cover.jpg"
    
    Write-Output "Processing: $($game.Name)"
    
    if ($appId -and $appId -gt 0) {
        try {
            $headerUrl = "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg"
            Invoke-WebRequest -Uri $headerUrl -OutFile $imagePath -TimeoutSec 30 -ErrorAction Stop
            
            if ((Get-Item $imagePath).Length -gt 5000) {
                $game.CoverImagePath = $imagePath
                Write-Output "  Downloaded (Steam ID: $appId)"
            } else {
                Write-Output "  File too small, trying library image..."
                $libraryUrl = "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/library_600x900.jpg"
                Invoke-WebRequest -Uri $libraryUrl -OutFile $imagePath -TimeoutSec 30 -ErrorAction SilentlyContinue
                if ((Test-Path $imagePath) -and (Get-Item $imagePath).Length -gt 5000) {
                    $game.CoverImagePath = $imagePath
                    Write-Output "  Downloaded library image"
                }
            }
        } catch {
            Write-Output "  Error: $($_.Exception.Message)"
        }
    } else {
        Write-Output "  No Steam ID, keeping placeholder"
    }
    
    Start-Sleep -Milliseconds 200
}

$games | ConvertTo-Json -Depth 10 | Set-Content $dbPath
Write-Output ""
Write-Output "Done! Verifying images..."

$count = (Get-ChildItem $imageCache -Filter "*.jpg" | Where-Object { $_.Length -gt 5000 }).Count
Write-Output "Valid images: $count"
