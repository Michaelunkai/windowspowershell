<#
.SYNOPSIS
    time
#>
param (
        [ScriptBlock]$Command
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Command
    $sw.Stop()
    Write-Output "Finished in $($sw.Elapsed.TotalSeconds) seconds"
