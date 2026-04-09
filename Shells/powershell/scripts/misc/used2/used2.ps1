<#
.SYNOPSIS
    used2
#>
(Get-Content "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -ErrorAction SilentlyContinue) | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { ($_ -ne $null) -and (Get-Command $_ -ErrorAction SilentlyContinue).CommandType -eq 'Function' } | Group-Object | Sort-Object Count -Descending | Select-Object -First 100 | Format-Table Count, Name -AutoSize
