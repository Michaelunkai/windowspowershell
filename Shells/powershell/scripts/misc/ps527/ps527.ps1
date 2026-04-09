<#
.SYNOPSIS
    ps527
#>
Get-ChildItem "$HOME\Documents\WindowsPowerShell\*profile*.ps1" -File | % { $d=$_.FullName -replace 'WindowsPowerShell','PowerShell'; New-Item (Split-Path $d) -ItemType Directory -Force | Out-Null; Copy-Item $_ $d -Force }; . $PROFILE
