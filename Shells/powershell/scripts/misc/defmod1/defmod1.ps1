<#
.SYNOPSIS
    defmod1
#>
$p='C:\Users\micha\.claude\settings.json'; $j=Get-Content $p -Raw | ConvertFrom-Json; $j.model='haiku'; $j | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8; Write-Host 'Default model set to HAIKU (fastest) - Restart Claude Code' -ForegroundColor Green
