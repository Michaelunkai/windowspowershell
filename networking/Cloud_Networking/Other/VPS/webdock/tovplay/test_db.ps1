# Test script to trace DB query
$credFile = "F:\tovplay\.claude\credentials.json"
$creds = Get-Content $credFile -Raw | ConvertFrom-Json
$dbHost = $creds.servers.database.host
$dbUser = $creds.servers.database.user
$dbPass = $creds.servers.database.password
$dbName = $creds.servers.database.database

$query = "SELECT version()"
$queryBytes = [System.Text.Encoding]::UTF8.GetBytes($query)
$queryBase64 = [Convert]::ToBase64String($queryBytes)

Write-Host "Base64: $queryBase64"
Write-Host ""

# Pipe the command to bash instead of using -c
$bashCmd = "PAGER=cat PGPASSWORD=$dbPass psql -h $dbHost -U $dbUser -d $dbName -c `"`$(echo $queryBase64 | base64 -d)`""
Write-Host "Bash cmd: $bashCmd"
Write-Host ""

Write-Host "Result:"
$bashCmd | wsl -d ubuntu bash
