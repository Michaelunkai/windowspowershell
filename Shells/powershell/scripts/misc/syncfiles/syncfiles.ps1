<#
.SYNOPSIS
    syncfiles
#>
robocopy .\gamesaves .\SyncFiles\gamesaves *.txt /S; robocopy .\linux .\SyncFiles\linux *.txt /S; robocopy .\windowsapps .\SyncFiles\windowsapps *.txt /S; robocopy C:\Users\micha\Documents .\SyncFiles\Documents /S
