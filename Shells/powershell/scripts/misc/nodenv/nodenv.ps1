<#
.SYNOPSIS
    nodenv
#>
Write-Host "CLAUDE_CODE_MAX_OUTPUT_TOKENS: $([System.Environment]::GetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', 'User'))" -ForegroundColor Cyan; Write-Host "NODE_OPTIONS: $([System.Environment]::GetEnvironmentVariable('NODE_OPTIONS', 'User'))" -ForegroundColor Yellow; $s=(Get-Content 'C:\Users\micha\.claude\settings.json' -Raw | ConvertFrom-Json); Write-Host "autoCompact.threshold: $($s.autoCompact.threshold)" -ForegroundColor Magenta
