<#
.SYNOPSIS
    savesnap
#>
Add-Type -AssemblyName System.Windows.Forms; $img = [System.Windows.Forms.Clipboard]::GetImage(); if($img) { $img.Save("F:\downloads\clipboard_$(Get-Date -Format 'yyyyMMdd_HHmmss').png", [System.Drawing.Imaging.ImageFormat]::Png); Write-Host "Image saved successfully" } else { Write-Host "No image found in clipboard" }
