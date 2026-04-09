<#
.SYNOPSIS
    rmn
#>
param(
        [string]$filename
    )
    # Remove the file, forcing removal even if it's read-only
    Remove-Item -Path $filename -Force
    # Open the file in nano editor
    nano $filename
