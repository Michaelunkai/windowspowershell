# Auto-fix missing covers - runs silently after scan
param([switch]$ShowOutput)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$imageCache = "$env:APPDATA\GameLauncherPro\cache\images"

if (-not (Test-Path $dbPath)) { exit 0 }
if (-not (Test-Path $imageCache)) { New-Item -ItemType Directory -Path $imageCache -Force | Out-Null }

$games = Get-Content $dbPath -Raw | ConvertFrom-Json
$updated = [System.Collections.ArrayList]@()
$fixed = 0

foreach ($game in $games) {
    $needsFix = -not $game.CoverImagePath -or -not (Test-Path $game.CoverImagePath -ErrorAction SilentlyContinue)
    
    if ($needsFix) {
        if ($ShowOutput) { Write-Host "Downloading: $($game.Name)" -ForegroundColor Cyan }
        
        $imagePath = Join-Path $imageCache "$($game.Id)_cover.jpg"
        
        try {
            # Clean game name for better search
            $searchName = $game.Name -replace 'Test$','' -replace '\s*\d+$','' -replace '30thanniversaryedition',''
            $searchName = $searchName -replace 'SquarePants','' -replace 'Titans Of The Tide',''
            $searchName = $searchName.Trim()
            
            if ($searchName.Length -lt 2) { $searchName = $game.Name }
            
            $searchUrl = "https://steamcommunity.com/actions/SearchApps/$([uri]::EscapeDataString($searchName))"
            $response = Invoke-RestMethod -Uri $searchUrl -TimeoutSec 5 -ErrorAction Stop
            
            if ($response -and $response.Count -gt 0) {
                $appid = $response[0].appid
                $headerUrl = "https://cdn.cloudflare.steamstatic.com/steam/apps/$appid/header.jpg"
                
                Invoke-WebRequest -Uri $headerUrl -OutFile $imagePath -TimeoutSec 8 -ErrorAction Stop
                
                if ((Test-Path $imagePath) -and (Get-Item $imagePath).Length -gt 1000) {
                    $game.CoverImagePath = $imagePath
                    $fixed++
                    if ($ShowOutput) { Write-Host "  OK: Steam ID $appid" -ForegroundColor Green }
                } else {
                    Remove-Item $imagePath -Force -ErrorAction SilentlyContinue
                    if ($ShowOutput) { Write-Host "  SKIP: Bad image" -ForegroundColor Yellow }
                }
            } else {
                if ($ShowOutput) { Write-Host "  SKIP: Not found on Steam" -ForegroundColor Yellow }
            }
        } catch {
            if ($ShowOutput) { Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red }
        }
        
        Start-Sleep -Milliseconds 150
    }
    
    [void]$updated.Add($game)
}

if ($fixed -gt 0) {
    $updated | ConvertTo-Json -Depth 10 | Set-Content $dbPath -Encoding UTF8
    if ($ShowOutput) { Write-Host "`nFixed $fixed covers!" -ForegroundColor Green }
}

exit 0
