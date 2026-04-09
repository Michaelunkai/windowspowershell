<#
.SYNOPSIS
    backupwsl
#>
$ErrorActionPreference = "Stop"
    Set-Location -Path "F:\backup\linux\wsl"
    built michadockermisha/backup:wsl
