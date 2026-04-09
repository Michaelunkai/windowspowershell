$tvIP = '192.168.1.100'
$outFile = 'C:\Users\micha\Documents\WindowsPowerShell\tv-apps-discovered.json'
try {
    $apps = Invoke-RestMethod -Uri "http://${tvIP}:8001/api/v2/applications" -TimeoutSec 10
    $json = $apps | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($outFile, $json, [System.Text.Encoding]::UTF8)
    Write-Host ("SUCCESS: App count = " + $apps.data.Count)
    $netflix = $apps.data | Where-Object { $_.name -like '*Netflix*' -or $_.appId -like '*Netflix*' }
    if ($netflix) { Write-Host ("Netflix found: " + $netflix.appId) } else { Write-Host "Netflix not found in list" }
} catch {
    Write-Host ("ERROR: " + $_.Exception.Message)
    # TV may be offline - create placeholder file
    $placeholder = @{ error = $_.Exception.Message; tvIP = $tvIP; timestamp = (Get-Date -Format 'o') }
    $placeholder | ConvertTo-Json | Set-Content $outFile -Encoding UTF8
    Write-Host "Placeholder file created due to connection failure"
}
