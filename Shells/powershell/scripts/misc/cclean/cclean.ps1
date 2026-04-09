<#
.SYNOPSIS
    cclean
#>
gccleaner; Write-Host "Testing CCleaner functionality..." -ForegroundColor Yellow; & "F:\backup\windowsapps\installed\ccleaner\CCleaner64.exe" /?; Write-Host "`nRunning with verbose logging..." -ForegroundColor Cyan; & "F:\backup\windowsapps\installed\ccleaner\CCleaner64.exe" /AUTO /REGISTRY /S /LOGFILE="F:\temp\ccleaner_detailed.log"; Start-Sleep 5; if(Test-Path "F:\temp\ccleaner_detailed.log") { Write-Host "Detailed log created:" -ForegroundColor Green; Get-Content "F:\temp\ccleaner_detailed.log" } else { Write-Host "No detailed log created - checking standard logs..." -ForegroundColor Red; Get-ChildItem "F:\backup\windowsapps\installed\ccleaner\LOG" | ForEach-Object { Write-Host "File: $($_.Name) - Modified: $($_.LastWriteTime)" } }
