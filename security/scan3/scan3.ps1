<#
.SYNOPSIS
    scan3
#>
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Paths); if(-not $Paths){Write-Host "Usage: scan3 <path1> <path2> ..." -ForegroundColor Yellow; return}; $i=0; $Paths | %{ $i++; Write-Host "[$i/$($Paths.Count)] Scanning: $_" -ForegroundColor Cyan; $j=Start-MpScan -ScanType CustomScan -ScanPath $_ -AsJob; while($j.State -eq 'Running'){ Write-Progress -Activity "Custom Scan [$i/$($Paths.Count)]" -Status $_ -PercentComplete (($i-1)/$Paths.Count*100); Start-Sleep 1 }}; Write-Host "Custom Scan complete" -ForegroundColor Green
