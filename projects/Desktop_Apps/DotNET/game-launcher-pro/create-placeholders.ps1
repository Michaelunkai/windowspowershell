# Create placeholder images for all games
Add-Type -AssemblyName System.Drawing

$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$imageCache = "$env:APPDATA\GameLauncherPro\cache\images"
New-Item -ItemType Directory -Path $imageCache -Force | Out-Null

$games = Get-Content $dbPath -Raw | ConvertFrom-Json

Write-Output "Creating placeholders for $($games.Count) games..."

foreach ($game in $games) {
    $imagePath = Join-Path $imageCache "$($game.Id)_cover.jpg"
    
    if (Test-Path $imagePath) {
        Write-Output "Skip: $($game.Name)"
        continue
    }
    
    # Create a simple colored placeholder
    $bitmap = New-Object System.Drawing.Bitmap(400, 300)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    
    # Random dark color
    $colors = @(
        [System.Drawing.Color]::FromArgb(14, 99, 156),
        [System.Drawing.Color]::FromArgb(120, 40, 140),
        [System.Drawing.Color]::FromArgb(180, 50, 50),
        [System.Drawing.Color]::FromArgb(50, 150, 90),
        [System.Drawing.Color]::FromArgb(200, 120, 40)
    )
    $color = $colors[(Get-Random -Maximum $colors.Length)]
    
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.FillRectangle($brush, 0, 0, 400, 300)
    
    # Add game name text
    $font = New-Object System.Drawing.Font("Arial", 24, [System.Drawing.FontStyle]::Bold)
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    
    $rect = New-Object System.Drawing.RectangleF(0, 0, 400, 300)
    $graphics.DrawString($game.Name, $font, $textBrush, $rect, $format)
    
    $bitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    
    $graphics.Dispose()
    $bitmap.Dispose()
    
    # Update game JSON
    $game.CoverImagePath = $imagePath
    
    Write-Output "Created: $($game.Name)"
}

# Save updated database
$games | ConvertTo-Json -Depth 10 | Set-Content $dbPath
Write-Output "`nDone! All games have images now."
