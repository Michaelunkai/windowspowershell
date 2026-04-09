# free - Run commands once after reboot
# Usage: free qbit          → reboots, runs 'qbit' after login
#        free 'qbit; cc'    → reboots, runs 'qbit; cc' after login
param([Parameter(ValueFromRemainingArguments)][string[]]$Args_)

$Command = ($Args_ -join ' ').Trim()
if (-not $Command) { Write-Host "Usage: free <commands>" -ForegroundColor Red; return }

$RunScript = "$env:TEMP\free-run.ps1"
$StartupLnk = [System.Environment]::GetFolderPath('Startup') + "\free-once.lnk"

# Create the one-shot script that runs after reboot then cleans itself up
@"
# One-time post-reboot runner
Start-Sleep -Seconds 2
Write-Host '=== Running post-reboot commands ===' -ForegroundColor Green
Write-Host 'Commands: $($Command -replace "'","''")' -ForegroundColor Cyan
Write-Host ''

`$cmds = '$($Command -replace "'","''")' -split ';' | ForEach-Object { `$_.Trim() } | Where-Object { `$_ }
foreach (`$c in `$cmds) {
    Write-Host ">>> `$c" -ForegroundColor Yellow
    try { Invoke-Expression `$c } catch { Write-Host "ERROR: `$_" -ForegroundColor Red }
    Write-Host ''
}

Write-Host '=== Done ===' -ForegroundColor Green

# Cleanup - remove startup shortcut and this script
Remove-Item '$StartupLnk' -Force -ErrorAction SilentlyContinue
Remove-Item '$RunScript' -Force -ErrorAction SilentlyContinue
"@ | Out-File -FilePath $RunScript -Encoding UTF8 -Force

# Create startup shortcut
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($StartupLnk)
$sc.TargetPath = "powershell.exe"
$sc.Arguments = "-ExecutionPolicy Bypass -NoExit -File `"$RunScript`""
$sc.WindowStyle = 1
$sc.Save()

Write-Host "Registered: $Command" -ForegroundColor Green
Write-Host "Rebooting in 3s... Ctrl+C to cancel" -ForegroundColor Yellow
Start-Sleep 3
Restart-Computer -Force
