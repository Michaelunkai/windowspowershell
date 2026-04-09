<#
.SYNOPSIS
    rmccc
#>
get-ChildItem -Path "$env:USERPROFILE\.local\bin","$env:USERPROFILE\AppData\Roaming\Claude\claude-code","$env:USERPROFILE\AppData\Local\AnthropicClaude" -Recurse -Filter 'claude.exe' -ErrorAction SilentlyContinue | Sort-Object {[version]((Get-Item $_.FullName).VersionInfo.ProductVersion -replace '\.0$')} -Descending | Select-Object -Skip 1 | ForEach-Object { Remove-Item $_.DirectoryName -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "Deleted: $($_.FullName)" -ForegroundColor Red }
