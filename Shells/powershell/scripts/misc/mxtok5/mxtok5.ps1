<#
.SYNOPSIS
    mxtok5
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', '16384', 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=4096 --expose-gc --no-warnings', 'User'); refreshenv; Write-Host 'mxtok5: 16K tokens - Restart Claude Code' -ForegroundColor Green
