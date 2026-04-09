<#
.SYNOPSIS
    unsnap
#>
Write-Host "Force deleting ALL Rollback Rx snapshots..." -ForegroundColor Yellow
    
    # Check if Rollback Rx is installed
    $shieldPath = "C:\Program Files\Shield"
    if (-not (Test-Path $shieldPath)) {
        Write-Host "ERROR: Rollback Rx not found at $shieldPath" -ForegroundColor Red
        Write-Host "Please verify Rollback Rx installation" -ForegroundColor Yellow
        return
    }
    
    # Check if Rollback Rx service is running
    $shdService = Get-Service -Name "*Shield*" -ErrorAction SilentlyContinue
    if (-not $shdService -or $shdService.Status -ne "Running") {
        Write-Host "WARNING: Rollback Rx service may not be running" -ForegroundColor Yellow
    } else {
        Write-Host "Rollback Rx service is active" -ForegroundColor Green
    }
    
    try {
        # Method 1: Try command-line deletion
        Write-Host "Attempting to delete all Rollback Rx snapshots..." -ForegroundColor Cyan
        $shieldExe = Join-Path $shieldPath "Shield.exe"
        
        # Try various command line formats for deletion
        $commands = @(
            "/delete /all",
            "-delete -all",
            "/deleteall", 
            "-deleteall",
            "/clear",
            "-clear"
        )
        
        $success = $false
        foreach ($cmd in $commands) {
            try {
                Write-Host "Trying: $shieldExe $cmd" -ForegroundColor Gray
                $result = Start-Process -FilePath $shieldExe -ArgumentList $cmd -Wait -PassThru -WindowStyle Hidden -Timeout 30
                if ($result.ExitCode -eq 0) {
                    Write-Host "Rollback Rx snapshots deleted via command-line" -ForegroundColor Green
                    $success = $true
                    break
                }
            } catch {
                # Continue to next command
            }
        }
        
        if (-not $success) {
            Write-Host "Command-line deletion failed, trying GUI automation..." -ForegroundColor Yellow
            
            # Method 2: GUI automation approach (based on Rollback Rx Home interface)
            try {
                Write-Host "Launching Rollback Rx GUI for snapshot deletion..." -ForegroundColor Cyan
                $process = Start-Process -FilePath $shieldExe -PassThru -WindowStyle Normal
                Start-Sleep 3
                
                # Navigate to Snapshots section
                Add-Type -AssemblyName System.Windows.Forms
                
                # Click on Snapshots in the left menu
                [System.Windows.Forms.SendKeys]::SendWait("{TAB}{TAB}{DOWN}{DOWN}")  # Navigate to Snapshots
                Start-Sleep 1
                [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")  # Enter Snapshots section
                Start-Sleep 2
                
                # Select all snapshots (Ctrl+A) then delete (Del key)
                [System.Windows.Forms.SendKeys]::SendWait("^a")  # Select All snapshots
                Start-Sleep 1
                [System.Windows.Forms.SendKeys]::SendWait("{DELETE}")  # Delete selected snapshots
                Start-Sleep 1
                [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")  # Confirm deletion
                
                Write-Host "GUI automation attempted for snapshot deletion" -ForegroundColor Green
                Write-Host "All snapshots should be selected and deleted" -ForegroundColor Yellow
                Write-Host "Check Rollback Rx Snapshots section to confirm deletion" -ForegroundColor Cyan
                Write-Host "WARNING: This deletes ALL snapshots - cannot be undone!" -ForegroundColor Red
            } catch {
                Write-Host "GUI automation failed: $_" -ForegroundColor Red
            }
        }
        
        # Method 3: Direct file/registry cleanup
        Write-Host "Performing additional cleanup..." -ForegroundColor Cyan
        try {
            # Clear Rollback Rx temporary files
            $rollbackTempPaths = @(
                "$env:TEMP\*shield*",
                "$env:TEMP\*rollback*", 
                "$env:LOCALAPPDATA\Shield\*",
                "$env:PROGRAMDATA\Shield\*"
            )
            
            foreach ($path in $rollbackTempPaths) {
                Get-ChildItem $path -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
            Write-Host "Cleared Rollback Rx temp files" -ForegroundColor Green
            
        } catch {
            Write-Host "Temp file cleanup partially failed" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "Error during Rollback Rx snapshot deletion: $_" -ForegroundColor Red
    }
    
    # Always provide manual instructions
    Write-Host ""
    Write-Host "=== MANUAL ROLLBACK RX CLEANUP ===" -ForegroundColor Cyan
    Write-Host "If automatic deletion failed:" -ForegroundColor White
    Write-Host "1. Open Rollback Rx (Start Menu > RollBack Rx Home)" -ForegroundColor Green
    Write-Host "2. Click 'Snapshots' in the left navigation menu" -ForegroundColor Green
    Write-Host "3. Select snapshots you want to delete (Ctrl+A for all)" -ForegroundColor Green
    Write-Host "4. Press Delete key or right-click > Delete" -ForegroundColor Green
    Write-Host "5. Confirm the deletion when prompted" -ForegroundColor Green
    Write-Host ""
    Write-Host "Alternative: Right-click Rollback Rx tray icon > Settings > Manage Snapshots" -ForegroundColor Cyan
    Write-Host "WARNING: Deleting ALL snapshots removes all restore points - cannot be undone!" -ForegroundColor Red
