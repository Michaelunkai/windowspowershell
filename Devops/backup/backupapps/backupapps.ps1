<#
.SYNOPSIS
    backupapps
#>
$ErrorActionPreference = "Stop"
    Set-Location -Path "F:\backup\windowsapps"
    built michadockermisha/backup:windowsapps
