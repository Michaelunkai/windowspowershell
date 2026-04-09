Add-Type -AssemblyName System.Drawing

# Create 256x256 bitmap
$bmp = New-Object System.Drawing.Bitmap(256, 256)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# Background circle (blue)
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(37, 99, 235))
$bgPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(30, 64, 175), 4)
$g.FillEllipse($bgBrush, 8, 8, 240, 240)
$g.DrawEllipse($bgPen, 8, 8, 240, 240)

# Rocket body (white rectangle)
$bodyBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$g.FillRectangle($bodyBrush, 105, 60, 46, 90)

# Rocket nose (gold triangle)
$noseBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(251, 191, 36))
$nosePoints = @(
    (New-Object System.Drawing.Point(128, 20)),
    (New-Object System.Drawing.Point(105, 60)),
    (New-Object System.Drawing.Point(151, 60))
)
$g.FillPolygon($noseBrush, $nosePoints)

# Windows (blue circles)
$windowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(96, 165, 250))
$g.FillEllipse($windowBrush, 116, 73, 24, 24)
$g.FillEllipse($windowBrush, 120, 107, 16, 16)

# Left fin (red)
$finBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(239, 68, 68))
$leftFinPoints = @(
    (New-Object System.Drawing.Point(105, 130)),
    (New-Object System.Drawing.Point(85, 150)),
    (New-Object System.Drawing.Point(85, 170)),
    (New-Object System.Drawing.Point(105, 150))
)
$g.FillPolygon($finBrush, $leftFinPoints)

# Right fin (red)
$rightFinPoints = @(
    (New-Object System.Drawing.Point(151, 130)),
    (New-Object System.Drawing.Point(171, 150)),
    (New-Object System.Drawing.Point(171, 170)),
    (New-Object System.Drawing.Point(151, 150))
)
$g.FillPolygon($finBrush, $rightFinPoints)

# Flames (orange/yellow)
$flame1 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 249, 115, 22))
$flame2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 251, 191, 36))
$flame3 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(254, 243, 199))
$g.FillEllipse($flame1, 110, 140, 36, 50)
$g.FillEllipse($flame2, 114, 150, 28, 40)
$g.FillEllipse($flame3, 118, 160, 20, 30)

# Save PNG
$bmp.Save("F:\study\Dev_Toolchain\programming\.NET\projects\C#\StartupMaster\icon.png", [System.Drawing.Imaging.ImageFormat]::Png)

# Convert to ICO
$icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
$fs = New-Object System.IO.FileStream("F:\study\Dev_Toolchain\programming\.NET\projects\C#\StartupMaster\icon.ico", [System.IO.FileMode]::Create)
$icon.Save($fs)
$fs.Close()

# Cleanup
$g.Dispose()
$bmp.Dispose()
$bgBrush.Dispose()
$bgPen.Dispose()
$bodyBrush.Dispose()
$noseBrush.Dispose()
$windowBrush.Dispose()
$finBrush.Dispose()
$flame1.Dispose()
$flame2.Dispose()
$flame3.Dispose()
$icon.Dispose()

Write-Host "Icon created successfully at icon.ico"
