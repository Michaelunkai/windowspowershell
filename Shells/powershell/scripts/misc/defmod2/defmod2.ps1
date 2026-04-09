<#
.SYNOPSIS
    defmod2
#>
$p='C:\Users\micha\.claude\settings.json'; $j=Get-Content $p -Raw | ConvertFrom-Json; $j.model='claude-sonnet-4-5-20250929'; $j | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8; Write-Host 'Default model set to SONNET 4.5 (balanced) - Restart Claude Code' -ForegroundColor Cyan
