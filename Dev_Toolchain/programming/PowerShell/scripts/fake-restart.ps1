#Requires -RunAsAdministrator
param([switch]$Deep = $false)

$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

Write-Host "`n[1/12] Killing locked processes..." -ForegroundColor Cyan
Get-Process explorer,dwm,SearchIndexer,Cortana,OneDrive,chrome,firefox,AutoHotkey64,node,python,java,git -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Write-Host "OK" -ForegroundColor Green

Write-Host "[2/12] Clearing temp files..." -ForegroundColor Cyan
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "OK" -ForegroundColor Green

Write-Host "[3/12] Clearing Windows Update cache..." -ForegroundColor Cyan
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Remove-Item "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "OK" -ForegroundColor Green

Write-Host "[4/12] Flushing DNS..." -ForegroundColor Cyan
ipconfig /flushdns | Out-Null
Write-Host "OK" -ForegroundColor Green

Write-Host "[5/12] Resetting network..." -ForegroundColor Cyan
netsh winsock reset catalog | Out-Null
netsh int ip reset resetlog.txt | Out-Null
Write-Host "OK" -ForegroundColor Green

Write-Host "[6/12] Clearing printer spooler..." -ForegroundColor Cyan
Stop-Service Spooler -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Remove-Item "$env:WINDIR\System32\spool\PRINTERS\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "OK" -ForegroundColor Green

Write-Host "[7/12] Clearing event logs..." -ForegroundColor Cyan
Get-EventLog -List | ForEach-Object { Clear-EventLog -LogName $_.Log -ErrorAction SilentlyContinue }
Write-Host "OK" -ForegroundColor Green

Write-Host "[8/12] Resetting COM+ services..." -ForegroundColor Cyan
Stop-Service COMSysApp -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Write-Host "OK" -ForegroundColor Green

Write-Host "[9/12] Flushing memory and caches..." -ForegroundColor Cyan
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()
Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
Write-Host "OK" -ForegroundColor Green

Write-Host "[10/12] Resetting Windows Search..." -ForegroundColor Cyan
Stop-Service WSearch -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Remove-Item "$env:PROGRAMDATA\Microsoft\Search\Data\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "OK" -ForegroundColor Green

Write-Host "[11/12] Clearing browser cache..." -ForegroundColor Cyan
Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "OK" -ForegroundColor Green

Write-Host "[12/12] Restarting Explorer..." -ForegroundColor Cyan
Start-Process explorer.exe
Start-Sleep -Seconds 2
Write-Host "OK" -ForegroundColor Green

Write-Host "`n*** FAKE RESTART COMPLETE ***`n" -ForegroundColor Green

Write-Host "Installing Malwarebytes..." -ForegroundColor Magenta
winget install Malwarebytes -e -h --accept-source-agreements --accept-package-agreements

Write-Host "`nAll done!`n" -ForegroundColor Green
