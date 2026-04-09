<#
.SYNOPSIS
    3dd - PowerShell utility script
.NOTES
    Original function: 3dd
    Extracted: 2026-02-19 20:20
#>
# DISABLED 2026-02-19 - Was causing terminal windows to spawn every few minutes
    # Original: Opens new Windows Terminal tab for each command
    # $cmd = $args -join ' '
    # $profilePath = $PROFILE
    # $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
    # Set-Content -Path $tempScript -Value ". '$profilePath'; $cmd"
    # wt new-tab powershell.exe -NoExit -ExecutionPolicy Bypass -File $tempScript
    Write-Host "3dd function disabled - was causing terminal spam" -ForegroundColor Yellow
