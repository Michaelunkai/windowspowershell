<#
.SYNOPSIS
    rmd
#>
Add-Type -AssemblyName System.Windows.Forms
    $proc = Start-Process "F:\study\automation\bots\MacroCreator\rmod\rmod.exe" -PassThru
    Start-Sleep -Seconds 2
    [System.Windows.Forms.SendKeys]::SendWait("1")
