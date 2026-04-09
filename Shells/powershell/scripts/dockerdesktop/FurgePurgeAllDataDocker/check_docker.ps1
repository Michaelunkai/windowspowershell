Write-Host "[CHECKING] Docker Desktop processes..."
Get-Process | Where-Object {$_.ProcessName -like '*Docker*'} | Format-Table ProcessName, Id -AutoSize
