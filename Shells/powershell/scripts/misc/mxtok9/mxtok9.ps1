<#
.SYNOPSIS
    mxtok9
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', '51200', 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=6144 --expose-gc --no-warnings', 'User'); refreshenv; Write-Host 'mxtok9: 50K tokens - Restart Claude Code' -ForegroundColor Green
