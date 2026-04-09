<#
.SYNOPSIS
    mxtok1
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', '1024', 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=1024 --expose-gc --no-warnings', 'User'); refreshenv; Write-Host 'mxtok1: 1K tokens - Restart Claude Code' -ForegroundColor Green
