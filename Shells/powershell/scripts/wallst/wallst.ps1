<#
.SYNOPSIS
    wallst - PowerShell utility script
.NOTES
    Original function: wallst
    Extracted: 2026-02-19 20:20
#>
$taskName = 'AutoWallpaperGames'
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Output "?  '$taskName' disabled and removed." -ForegroundColor Yellow
    } else {
        Write-Output "??   No scheduled task named '$taskName' found." -ForegroundColor Cyan
    }
