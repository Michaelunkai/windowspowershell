<#
.SYNOPSIS
    mxtok10
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', '64000', 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=8192 --expose-gc --no-warnings', 'User'); refreshenv; Write-Host 'mxtok10: 64K tokens (MAXIMUM) - Restart Claude Code' -ForegroundColor Cyan
