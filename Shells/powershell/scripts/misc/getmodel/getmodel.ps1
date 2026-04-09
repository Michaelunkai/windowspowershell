<#
.SYNOPSIS
    getmodel
#>
Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Model
