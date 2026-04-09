<#
.SYNOPSIS
    timel
#>
$boot = Get-WinEvent -FilterHashtable @{LogName='System';ID=6005} -MaxEvents 1; $shutdown = Get-WinEvent -FilterHashtable @{LogName='System';ID=6006} -MaxEvents 1; ($boot.TimeCreated - $shutdown.TimeCreated).ToString()
