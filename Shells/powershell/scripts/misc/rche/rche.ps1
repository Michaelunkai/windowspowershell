<#
.SYNOPSIS
    rche
#>
Stop-Process -Name "cheatengine-x86_64" -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath 'F:\backup\windowsapps\installed\Cheat Engine 7.5\Cheat Engine.exe'
