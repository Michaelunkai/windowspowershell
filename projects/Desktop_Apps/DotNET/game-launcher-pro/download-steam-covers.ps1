# Download game covers from Steam store
$ProgressPreference = 'SilentlyContinue'

$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$imageCache = "$env:APPDATA\GameLauncherPro\cache\images"

# Better search terms for Steam
$steamSearchTerms = @{
    "Games" = "Witcher 3"
    "Metal Gear Solid 3 Snake Eater Master Collection" = "Metal Gear Solid Master Collection"
    "Metal Gear Rising Revengeance" = "Metal Gear Rising"
    "Ninja Gaiden 2 Black" = "Ninja Gaiden"
    "Rise Of The Ronin" = "Rise of the Ronin"
    "Mewgenics" = "Mewgenics"
    "Cairn" = "Cairn"
    "High On Life 2" = "High On Life"
    "Sonic Frontiers" = "Sonic Frontiers"
    "Dispatch" = "Dispatch"
    "Bayonetta" = "Bayonetta"
    "Haroldhalibut" = "Harold Halibut"
}

$games = Get-Content $dbPath -Raw | ConvertFrom-Json

Write-Output "Downloading covers from Steam..."

foreach ($game in $games) {
    $searchTerm = $steamSearchTerms[$game.Name]
    if (-not $searchTerm) { $searchTerm = $game.Name }
    
    $imagePath = Join-Path $imageCache "$($game.Id)_cover.jpg"
    
    Write-Output "[$($game.Name)] -> Searching: $searchTerm"
    
    try {
        $encoded = [uri]::EscapeDataString($searchTerm)
        $url = "https://store.steampowered.com/api/storesearch/?term=$encoded&l=english&cc=US"
        
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 15 -ErrorAction Stop
        
        if ($response.total -gt 0) {
            $appId = $response.items[0].id
            $appName = $response.items[0].name
            
            # Download header image (460x215)
            $headerUrl = "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg"
            Invoke-WebRequest -Uri $headerUrl -OutFile $imagePath -TimeoutSec 15 -ErrorAction Stop
            
            $game.CoverImagePath = $imagePath
            Write-Output "  SUCCESS: $appName (ID: $appId)"
        } else {
            Write-Output "  NOT FOUND on Steam"
        }
    } catch {
        Write-Output "  ERROR: $($_.Exception.Message)"
    }
    
    Start-Sleep -Milliseconds 500
}

$games | ConvertTo-Json -Depth 10 | Set-Content $dbPath
Write-Output ""
Write-Output "Done!"
