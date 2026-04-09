Get-Service | Where-Object {$_.Name -like '*docker*' -or $_.Name -like '*vm*'} | Format-Table Name, Status, StartType -AutoSize
