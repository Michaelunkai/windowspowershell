<#
.SYNOPSIS
    mxtokoff
#>
[System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_OUTPUT_TOKENS', $null, 'User'); [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', $null, 'User'); refreshenv; Write-Host 'mxtokoff: Reset to defaults - Restart Claude Code' -ForegroundColor Yellow
