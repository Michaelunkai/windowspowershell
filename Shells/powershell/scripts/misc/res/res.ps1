<#
.SYNOPSIS
    res
#>
param([string]$proc)
    & "F:\backup\windowsapps\installed\PSTools\pssuspend.exe" -r $proc
