<#
.SYNOPSIS
    tstart
#>
(Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational'; ID=100} -MaxEvents 1 -EA SilentlyContinue | ForEach-Object { [xml]$x=$_.ToXml(); '{0:N2} seconds' -f (($x.Event.EventData.Data | Where-Object { $_.Name -eq 'BootTime' }).'#text'/1000) })
