<#
.SYNOPSIS
    autocomplete
#>
Install-Module -Name PSReadLine -Force -SkipPublisherCheck ; Import-Module PSReadLine ; Set-PSReadLineOption -PredictionSource History ; Set-PSReadLineOption -PredictionViewStyle ListView
