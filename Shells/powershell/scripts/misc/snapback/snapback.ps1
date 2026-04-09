<#
.SYNOPSIS
    snapback
#>
& 'C:\Program Files\Shield\ShdCmd.exe' /snapshot /n "Auto_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
