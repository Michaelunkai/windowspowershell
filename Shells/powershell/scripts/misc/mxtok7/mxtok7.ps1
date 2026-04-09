<#
.SYNOPSIS
    mxtok7
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', '32768', 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=4096 --expose-gc --no-warnings', 'User'); refreshenv; Write-Host 'mxtok7: 32K tokens - Restart Claude Code' -ForegroundColor Green
