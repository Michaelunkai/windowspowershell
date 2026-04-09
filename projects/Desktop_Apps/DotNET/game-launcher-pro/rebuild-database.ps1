# Rebuild game database with correct paths and names
$ProgressPreference = 'SilentlyContinue'

$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$imageCache = "$env:APPDATA\GameLauncherPro\cache\images"

# Clear and rebuild
$games = @()

# Define games with correct info
$gameDefinitions = @(
    @{ Name = "The Witcher 3: Wild Hunt"; Exe = "E:\games\TheWitcher3WildHunt\bin\x64\witcher3.exe"; SteamId = 292030 },
    @{ Name = "Metal Gear Solid 3: Snake Eater"; Exe = "E:\games\METALGEARSOLID3SnakeEaterMasterCollection\METAL GEAR SOLID3.exe"; SteamId = 2131640 },
    @{ Name = "Metal Gear Rising: Revengeance"; Exe = "E:\games\MetalGearRisingRevengeance\METAL GEAR RISING REVENGEANCE.exe"; SteamId = 235460 },
    @{ Name = "Ninja Gaiden 2 Black"; Exe = "E:\games\NINJAGAIDEN2Black\NINJAGAIDEN2BLACK.exe"; SteamId = 1580790 },
    @{ Name = "Rise of the Ronin"; Exe = "E:\games\Rise of the Ronin\Ronin\Ronin.exe"; SteamId = 2296100 },
    @{ Name = "Mewgenics"; Exe = "E:\games\mewgenics\Mewgenics.exe"; SteamId = 2655250 },
    @{ Name = "Cairn"; Exe = "E:\games\cairn\Cairn.exe"; SteamId = 1434530 },
    @{ Name = "High On Life 2"; Exe = "E:\games\HighOnLife2\HighOnLife2.exe"; SteamId = 1583230 },
    @{ Name = "Sonic Frontiers"; Exe = "E:\games\SonicFrontiers\SonicFrontiers.exe"; SteamId = 1237320 },
    @{ Name = "Bayonetta"; Exe = "E:\games\Bayonetta\Bayonetta.exe"; SteamId = 460790 },
    @{ Name = "Harold Halibut"; Exe = "E:\games\haroldhalibut\Harold Halibut.exe"; SteamId = 1058020 },
    @{ Name = "Dispatch"; Exe = "F:\games\dispatch\Dispatch.exe"; SteamId = 0 }
)

Write-Output "Building clean game database..."
Write-Output ""

foreach ($def in $gameDefinitions) {
    if (!(Test-Path $def.Exe)) {
        Write-Output "SKIP: $($def.Name) - EXE not found"
        continue
    }
    
    $id = [guid]::NewGuid().ToString()
    $imagePath = Join-Path $imageCache "${id}_cover.jpg"
    
    # Download cover from Steam
    if ($def.SteamId -gt 0) {
        try {
            $headerUrl = "https://cdn.cloudflare.steamstatic.com/steam/apps/$($def.SteamId)/header.jpg"
            Invoke-WebRequest -Uri $headerUrl -OutFile $imagePath -TimeoutSec 15 -ErrorAction Stop
            Write-Output "OK: $($def.Name) - Image downloaded"
        } catch {
            Write-Output "WARN: $($def.Name) - Image failed, using placeholder"
            $imagePath = ""
        }
    } else {
        Write-Output "OK: $($def.Name) - No Steam ID"
        $imagePath = ""
    }
    
    $game = @{
        Id = $id
        Name = $def.Name
        ExecutablePath = $def.Exe
        InstallDirectory = Split-Path $def.Exe
        CoverImagePath = $imagePath
        BackgroundImagePath = ""
        Description = ""
        DateAdded = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        LastPlayed = $null
        PlayCount = 0
        PlaytimeMinutes = 0
        IsFavorite = $false
        Tags = @()
    }
    
    $games += $game
    Start-Sleep -Milliseconds 300
}

Write-Output ""
Write-Output "Saving database with $($games.Count) games..."
$games | ConvertTo-Json -Depth 10 | Set-Content $dbPath

Write-Output "Done!"
