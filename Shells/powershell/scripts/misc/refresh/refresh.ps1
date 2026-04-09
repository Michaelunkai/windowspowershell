<#
.SYNOPSIS
    refresh
#>
Stop-Process -Name explorer -Force; Start-Sleep 2; Start-Process "$env:windir\explorer.exe"
