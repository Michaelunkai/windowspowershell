<#
.SYNOPSIS
    mkc - PowerShell utility script
.NOTES
    Original function: mkc
    Extracted: 2026-02-19 20:20
#>
param([string]$name)
    if (-not $name) {
        Write-Host "Usage: mkc <directory_name>" -ForegroundColor Yellow
        return
    }
    mkdir $name
    if ($?) {
        cd $name
    }
