<#
.SYNOPSIS
    nodecontext1mb
#>
[System.Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--max-old-space-size=8192 --max-http-header-size=1048576 --expose-gc --no-warnings', 'User')
    [System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_MAX_MEMORY', '8192', 'User')
    [System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_TIMEOUT', '0', 'User')
    [System.Environment]::SetEnvironmentVariable('CLAUDE_CODE_RETRY', 'true', 'User')
    [System.Environment]::SetEnvironmentVariable('UV_THREADPOOL_SIZE', '128', 'User')
    [System.Environment]::SetEnvironmentVariable('UV_USE_IO_URING', '0', 'User')
    refreshenv
    Write-Host "Permanent 1MB context size applied for ALL future sessions!" -ForegroundColor Green
    Write-Host "NODE_OPTIONS: $env:NODE_OPTIONS" -ForegroundColor Cyan
    Write-Host "Restart ALL terminals to see changes everywhere" -ForegroundColor Yellow
