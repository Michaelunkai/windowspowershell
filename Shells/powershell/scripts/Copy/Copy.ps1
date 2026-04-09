<#
.SYNOPSIS
    Copy
#>
param (
        [string[]]$InputObject
    )
    $InputObject -join "`n" | Set-Clipboard
    Write-Output "Copied to clipboard."
