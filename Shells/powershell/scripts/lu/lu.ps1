<#
.SYNOPSIS
    lu
#>
Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods |
        Invoke-CimMethod -MethodName WmiSetBrightness -Arguments @{Brightness=100; Timeout=1}
