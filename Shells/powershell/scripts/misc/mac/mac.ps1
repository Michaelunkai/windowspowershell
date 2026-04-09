<#
.SYNOPSIS
    mac
#>
Get-NetAdapter | Select-Object -Property Name, MacAddress
