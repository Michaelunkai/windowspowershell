<#
.SYNOPSIS
    rmdmp - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
gci $env:TEMP,C:\Windows\Temp -Include *.tmp,*.dmp -Recurse -Force -EA 0 | ri -Force -EA 0
