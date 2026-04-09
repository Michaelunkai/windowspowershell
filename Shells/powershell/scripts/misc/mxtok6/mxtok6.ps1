<#
.SYNOPSIS
    mxtok6
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', '24576', 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=4096 --expose-gc --no-warnings', 'User'); refreshenv; Write-Host 'mxtok6: 24K tokens - Restart Claude Code' -ForegroundColor Green
