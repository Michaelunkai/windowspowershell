<#
.SYNOPSIS
    sg
#>
Start-Process "F:\backup\windowsapps\installed\ludusavi\ludusavi.exe"
      Start-Process "F:\backup\windowsapps\installed\gameSaveManager\gs_mngr_3.exe"
      start-process "F:\backup\windowsapps\installed\savestate\SaveState.exe"
      Start-Sleep -Seconds 120; ws 'gg && sprofile && savegames'
