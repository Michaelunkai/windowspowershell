# fixc - Schedule REAL thorough chkdsk scan for next reboot
function fixc {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $be = (Get-ItemProperty $regPath).BootExecute
    
    foreach ($entry in $be) {
        if ($entry -match 'autochk\s+/' -and $entry -ne "autocheck autochk *") {
            Write-Host "Already scheduled for next reboot!" -ForegroundColor Green
            Write-Host "  Entry: $entry" -ForegroundColor Cyan
            return
        }
    }
    
    $newEntry = "autocheck autochk /R /B \??\C:"
    $newBE = @($newEntry) + $be
    Set-ItemProperty -Path $regPath -Name BootExecute -Value $newBE -Type MultiString
    chkntfs /T:0 | Out-Null
    
    Write-Host ""
    Write-Host "✅ Thorough disk check SCHEDULED for next reboot" -ForegroundColor Green
    Write-Host "  Flags: /R (surface scan) + /B (re-evaluate bad clusters)" -ForegroundColor Cyan
    Write-Host "  You will see: Stage 1 of 5: XX% complete" -ForegroundColor Cyan
    Write-Host "  Reboot now: shutdown /r /t 0" -ForegroundColor Yellow
}

# Claude Code launcher with pre-flight checks (prevents ENOENT errors)
function clau { & powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\claude-launch.ps1" @args }

# === C: Drive Cleanup Aliases ===
function Invoke-CCleanup { powershell -ExecutionPolicy Bypass -File "C:\Users\micha\.openclaw\scripts\monthly-cleanup.ps1" }
function Invoke-CCleanupDry { powershell -ExecutionPolicy Bypass -File "C:\Users\micha\.openclaw\scripts\monthly-cleanup.ps1" -DryRun }
Set-Alias cleanup Invoke-CCleanup
Set-Alias cleanup-dry Invoke-CCleanupDry
