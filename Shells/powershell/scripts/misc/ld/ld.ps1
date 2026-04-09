<#
.SYNOPSIS
    ld
#>
Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods |
        Invoke-CimMethod -MethodName WmiSetBrightness -Arguments @{Brightness=30; Timeout=1}
