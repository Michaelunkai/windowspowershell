<#
.SYNOPSIS
    dbo
#>
Start-Process "F:\study\Platforms\windows\autohotkey\driverbooster.ahk"; Start-Sleep -Seconds 2; Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait("1")
