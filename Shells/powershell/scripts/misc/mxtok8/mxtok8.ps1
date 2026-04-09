<#
.SYNOPSIS
    mxtok8
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', '40960', 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=6144 --expose-gc --no-warnings', 'User'); refreshenv; Write-Host 'mxtok8: 40K tokens - Restart Claude Code' -ForegroundColor Green
