<#
.SYNOPSIS
    killgame
#>
param([string]$name)
    
    if ($name) {
        Write-Host "Killing $name..." -ForegroundColor Yellow
        cmd /c "taskkill /F /IM `"$name.exe`" /T" 2>$null
        Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "Killing all unresponsive games..." -ForegroundColor Yellow
        Get-Process | Where-Object { 
            $_.MainWindowHandle -ne [IntPtr]::Zero -and 
            $_.WorkingSet64 -gt 500MB -and 
            -not $_.Responding 
        } | ForEach-Object {
            Write-Host "  Killing $($_.ProcessName)..." -ForegroundColor Red
            cmd /c "taskkill /F /IM `"$($_.ProcessName).exe`" /T" 2>$null
            Stop-Process -Name $_.ProcessName -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Kill helper processes
    Stop-Process -Name "bridge32" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "bridge64" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "crs-handler" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "crs-uploader" -Force -ErrorAction SilentlyContinue
    
    Write-Host "Done!" -ForegroundColor Green
