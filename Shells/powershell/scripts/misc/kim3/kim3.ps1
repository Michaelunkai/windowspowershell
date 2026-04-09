<#
.SYNOPSIS
    kim3
#>
$timesheets = Invoke-RestMethod -Uri "https://time.tovtech.org/api/timesheets" -Method GET -Headers @{"X-AUTH-USER"="Michael Fedorovsky"; "X-AUTH-TOKEN"="13571357"; "Content-Type"="application/json"}; $now = Get-Date; $startDate = if ($now.Day -ge 10) { Get-Date -Day 10 -Hour 0 -Minute 0 -Second 0 } else { (Get-Date -Day 10 -Hour 0 -Minute 0 -Second 0).AddMonths(-1) }; $filtered = $timesheets | Where-Object { $_.begin -ge $startDate.ToString("yyyy-MM-ddTHH:mm:sszzz") }; $totalSeconds = ($filtered | ForEach-Object { if ($_.end) { (Get-Date $_.end) - (Get-Date $_.begin) } else { (Get-Date) - (Get-Date $_.begin) } } | Measure-Object -Property TotalSeconds -Sum).Sum; [Math]::Round($totalSeconds / 3600, 2)
