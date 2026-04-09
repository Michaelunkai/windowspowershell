<#
.SYNOPSIS
    nodenocap
#>
[System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', $null, 'User')
    [System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', $null, 'Machine')
    [System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_MEMORY', $null, 'User')
    [System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_TIMEOUT', $null, 'User')
    [System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_RETRY', $null, 'User')
    [System.Environment]::SetEnvironmentVariable('UV_THREADPOOL_SIZE', $null, 'User')
    [System.Environment]::SetEnvironmentVariable('UV_USE_IO_URING', $null, 'User')
    $env:NODE_OPTIONS = $null
    refreshenv
    Write-Host "All Node.js restrictions removed permanently!" -ForegroundColor Green
    Write-Host "NODE_OPTIONS: $env:NODE_OPTIONS" -ForegroundColor Cyan
    Write-Host "Restart ALL terminals to see changes everywhere" -ForegroundColor Yellow
