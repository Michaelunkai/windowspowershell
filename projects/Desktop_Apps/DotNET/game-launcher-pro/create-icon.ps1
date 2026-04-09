# Create a game controller icon
Add-Type -AssemblyName System.Drawing

$iconPath = "F:\study\Dev_Toolchain\programming\.NET\projects\C#\game-launcher-winforms\game-icon.ico"

# Create 256x256 bitmap
$sizes = @(256, 128, 64, 48, 32, 16)
$bitmaps = @()

foreach ($size in $sizes) {
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::FromArgb(0, 150, 220))  # Blue background
    
    # Draw game controller shape
    $scale = $size / 256
    
    # Controller body
    $bodyBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (4 * $scale))
    
    # Draw ellipse for body
    $bodyRect = New-Object System.Drawing.RectangleF((30 * $scale), (70 * $scale), (196 * $scale), (120 * $scale))
    $graphics.FillEllipse($bodyBrush, $bodyRect)
    
    # Draw handles (left and right)
    $leftHandle = New-Object System.Drawing.RectangleF((20 * $scale), (90 * $scale), (60 * $scale), (80 * $scale))
    $rightHandle = New-Object System.Drawing.RectangleF((176 * $scale), (90 * $scale), (60 * $scale), (80 * $scale))
    $graphics.FillEllipse($bodyBrush, $leftHandle)
    $graphics.FillEllipse($bodyBrush, $rightHandle)
    
    # Draw D-pad (left side)
    $dpadBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 120, 180))
    $dpadWidth = 12 * $scale
    $dpadHeight = 35 * $scale
    $dpadX = 75 * $scale
    $dpadY = 115 * $scale
    $graphics.FillRectangle($dpadBrush, $dpadX, $dpadY, $dpadWidth, $dpadHeight)
    $graphics.FillRectangle($dpadBrush, ($dpadX - 11 * $scale), ($dpadY + 11 * $scale), $dpadHeight, $dpadWidth)
    
    # Draw buttons (right side) - ABXY
    $buttonBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 120, 180))
    $btnSize = 18 * $scale
    $graphics.FillEllipse($buttonBrush, (155 * $scale), (100 * $scale), $btnSize, $btnSize)  # Y
    $graphics.FillEllipse($buttonBrush, (155 * $scale), (135 * $scale), $btnSize, $btnSize)  # A
    $graphics.FillEllipse($buttonBrush, (138 * $scale), (118 * $scale), $btnSize, $btnSize)  # X
    $graphics.FillEllipse($buttonBrush, (172 * $scale), (118 * $scale), $btnSize, $btnSize)  # B
    
    # Draw analog sticks
    $stickSize = 25 * $scale
    $graphics.FillEllipse($dpadBrush, (55 * $scale), (145 * $scale), $stickSize, $stickSize)
    $graphics.FillEllipse($dpadBrush, (135 * $scale), (145 * $scale), $stickSize, $stickSize)
    
    $graphics.Dispose()
    $bitmaps += $bitmap
}

# Save as ICO (simplified - just use largest size)
$bitmaps[0].Save($iconPath.Replace(".ico", ".png"), [System.Drawing.Imaging.ImageFormat]::Png)

# Convert PNG to ICO using a different approach
$pngPath = $iconPath.Replace(".ico", ".png")
Write-Output "Created PNG icon at: $pngPath"
Write-Output "For ICO conversion, use the PNG as application icon"

# Clean up
foreach ($bmp in $bitmaps) {
    $bmp.Dispose()
}
