<#
.SYNOPSIS
    mxtok3
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', '4096', 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=2048 --expose-gc --no-warnings', 'User'); refreshenv; Write-Host 'mxtok3: 4K tokens - Restart Claude Code' -ForegroundColor Green
