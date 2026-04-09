<#
.SYNOPSIS
    mxtok4
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', '8192', 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=2048 --expose-gc --no-warnings', 'User'); refreshenv; Write-Host 'mxtok4: 8K tokens (default) - Restart Claude Code' -ForegroundColor Green
