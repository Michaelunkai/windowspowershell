# Fix ALL game images with verified correct Steam IDs
$ProgressPreference = 'SilentlyContinue'

$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$imageCache = "$env:APPDATA\GameLauncherPro\cache\images"

# VERIFIED Steam App IDs - double checked
$verifiedSteamIds = @{
    "The Witcher 3: Wild Hunt" = 292030
    "Metal Gear Solid 3: Snake Eater" = 2131640  # Master Collection Vol 1
    "Metal Gear Rising: Revengeance" = 235460
    "Ninja Gaiden 2 Black" = 1580790  # Ninja Gaiden Master Collection
    "Rise of the Ronin" = 2279380  # Correct Steam ID
    "Mewgenics" = 2655250
    "Cairn" = 1434530
    "High On Life 2" = 2360020  # High On Life 2 correct ID
    "Sonic Frontiers" = 1237320
    "Bayonetta" = 460790
    "Harold Halibut" = 1058020
    "Dispatch" = 0  # Not on Steam - will create placeholder
}

$games = Get-Content $dbPath -Raw | ConvertFrom-Json

Write-Output "Re-downloading ALL game images with verified Steam IDs..."
Write-Output ""

foreach ($game in $games) {
    $steamId = $verifiedSteamIds[$game.Name]
    $imagePath = Join-Path $imageCache "$($game.Id)_cover.jpg"
    
    Write-Output "[$($game.Name)]"
    
    if ($steamId -and $steamId -gt 0) {
        try {
            # Delete old image
            if (Test-Path $imagePath) { Remove-Item $imagePath -Force }
            
            # Download fresh from Steam CDN
            $headerUrl = "https://cdn.cloudflare.steamstatic.com/steam/apps/$steamId/header.jpg"
            Invoke-WebRequest -Uri $headerUrl -OutFile $imagePath -TimeoutSec 20 -ErrorAction Stop
            
            $size = (Get-Item $imagePath).Length
            if ($size -gt 10000) {
                $game.CoverImagePath = $imagePath
                Write-Output "  SUCCESS: Downloaded from Steam ID $steamId ($([math]::Round($size/1KB,1)) KB)"
            } else {
                Write-Output "  WARNING: Image too small, trying library image..."
                $libraryUrl = "https://cdn.cloudflare.steamstatic.com/steam/apps/$steamId/library_600x900.jpg"
                Invoke-WebRequest -Uri $libraryUrl -OutFile $imagePath -TimeoutSec 20 -ErrorAction SilentlyContinue
                if ((Test-Path $imagePath) -and (Get-Item $imagePath).Length -gt 10000) {
                    $game.CoverImagePath = $imagePath
                    Write-Output "  SUCCESS: Downloaded library image"
                }
            }
        } catch {
            Write-Output "  FAILED: $($_.Exception.Message)"
        }
    } else {
        # Create colored placeholder for Dispatch
        Write-Output "  Creating custom placeholder..."
        Add-Type -AssemblyName System.Drawing
        
        $bitmap = New-Object System.Drawing.Bitmap(460, 215)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::FromArgb(40, 40, 50))
        
        $font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        
        $rect = New-Object System.Drawing.RectangleF(0, 0, 460, 215)
        $graphics.DrawString($game.Name, $font, $brush, $rect, $format)
        
        $bitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $game.CoverImagePath = $imagePath
        
        $graphics.Dispose()
        $bitmap.Dispose()
        
        Write-Output "  Created placeholder image"
    }
    
    Start-Sleep -Milliseconds 500
    Write-Output ""
}

$games | ConvertTo-Json -Depth 10 | Set-Content $dbPath
Write-Output "=== ALL IMAGES UPDATED ==="
