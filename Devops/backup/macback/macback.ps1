<#
.SYNOPSIS
    macback - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
& "F:\backup\windowsapps\installed\reflect\mrauto.exe"  -b "F:\win11recovery" "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" C: --stealth --quiet
