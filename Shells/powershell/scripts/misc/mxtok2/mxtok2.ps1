<#
.SYNOPSIS
    mxtok2
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', '2048', 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=1024 --expose-gc --no-warnings', 'User'); refreshenv; Write-Host 'mxtok2: 2K tokens - Restart Claude Code' -ForegroundColor Green
