<#
.SYNOPSIS
    ccreg - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
gccleaner; Start-Process F:\study\shells\powershell\scripts\CcleanerRegistryAutoClean\a.ahk; Start-Sleep -Seconds 1; Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait("1")
