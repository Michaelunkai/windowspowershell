<#
.SYNOPSIS
    gcode
#>
[Environment]::SetEnvironmentVariable("PATH", [Environment]::GetEnvironmentVariable("PATH", "User") + ";F:\backup\windowsapps\installed\AI\VSCode", "User"); $env:PATH += ";F:\backup\windowsapps\installed\VSCode"
