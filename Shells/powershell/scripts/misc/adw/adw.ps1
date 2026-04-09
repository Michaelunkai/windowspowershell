<#
.SYNOPSIS
    adw
#>
& "F:\backup\windowsapps\installed\adw\AdwCleaner.exe" /eula /clean /noreboot; for ($i=0; $i -lt 10; $i++) { Start-Sleep -Seconds 2; $log = Get-ChildItem -Path "$env:HOMEDRIVE\AdwCleaner\Logs" -Filter "*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if ($log -and (Test-Path $log.FullName)) { Get-Content $log.FullName; break } }
