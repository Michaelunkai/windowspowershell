<#
.SYNOPSIS
    kim
#>
Invoke-RestMethod -Uri "https://time.tovtech.org/api/timesheets" -Method POST -Headers @{"X-AUTH-USER"="Michael Fedorovsky"; "X-AUTH-TOKEN"="13571357"; "Content-Type"="application/json"} -Body '{"project":44,"activity":112,"description":""}'
