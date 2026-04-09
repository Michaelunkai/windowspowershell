<#
.SYNOPSIS
    rche - PowerShell utility script
.NOTES
    Original function: rche
    Extracted: 2026-02-19 20:20
#>
Stop-Process -Name "cheatengine-x86_64" -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath 'F:\backup\windowsapps\installed\Cheat Engine 7.5\Cheat Engine.exe'
