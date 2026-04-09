<#
.SYNOPSIS
    bbel
#>
robocopy "$env:APPDATA\EldenRing" "F:\backup\gamesaves\EldenRing" /E /XO /NFL /NDL /NJH /NJS /NP; ws savegames
