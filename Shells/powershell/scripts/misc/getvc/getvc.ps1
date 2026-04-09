<#
.SYNOPSIS
    getvc
#>
winget install --id abbodi1406.vcredist --silent --accept-source-agreements --force; Write-Host "All VC++ Redistributables installed via AIO installer!" -ForegroundColor Green
