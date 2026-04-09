<#
.SYNOPSIS
    defmod3 - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
$p='C:\Users\micha\.claude\settings.json'; $j=Get-Content $p -Raw | ConvertFrom-Json; $j.model='claude-opus-4-5-20251101'; $j | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8; Write-Host 'Default model set to OPUS 4.5 (most capable) - Restart Claude Code' -ForegroundColor Magenta
