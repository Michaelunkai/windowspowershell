<#
.SYNOPSIS
    ctemp
#>
Write-Host 'Cleaning all temp files, logs, and cache...' -ForegroundColor Yellow
    Stop-Service -Name 'wuauserv' -Force -ErrorAction SilentlyContinue
    @('C:\Windows\Temp\*', 'C:\Temp\*', 'C:\Users\*\AppData\Local\Temp\*', 'C:\Users\*\AppData\Roaming\Microsoft\Windows\Recent\*', 'C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*', 'C:\Users\*\AppData\Local\Microsoft\Internet Explorer\DOMStore\*', 'C:\Users\*\AppData\Local\Google\Chrome\User Data\*\Cache\*', 'C:\Users\*\AppData\Local\Mozilla\Firefox\Profiles\*\cache2\*', 'C:\Users\*\AppData\Local\Microsoft\Edge\User Data\*\Cache\*', 'C:\Windows\Logs\*', 'C:\Windows\SoftwareDistribution\Download\*', 'C:\Windows\System32\LogFiles\*', 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*', 'C:\Users\*\AppData\Local\CrashDumps\*', 'C:\Windows\Minidump\*', 'C:\Users\*\AppData\Local\Microsoft\Windows\WebCache\*', 'C:\Windows\Prefetch\*.pf', 'C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\*', 'C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\*', 'C:\ProgramData\USOPrivate\UpdateStore\*', 'C:\Windows\SystemTemp\*') | ForEach-Object { Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue } | Where-Object { !$_.PSIsContainer -and $_.Name -notlike '*.exe' -and $_.Name -notlike '*.dll' } | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    Start-Service -Name 'wuauserv' -ErrorAction SilentlyContinue
    [System.GC]::Collect()
    Write-Host 'Temp cleanup completed successfully!' -ForegroundColor Green
