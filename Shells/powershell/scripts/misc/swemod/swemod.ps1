<#
.SYNOPSIS
    swemod
#>
Start-Process "F:\backup\windowsapps\install\wemod\WeMod-Setup.exe" -Wait; Start-Sleep -Seconds 2; & "F:\backup\windowsapps\install\wemod\WeModPatcher.exe"
