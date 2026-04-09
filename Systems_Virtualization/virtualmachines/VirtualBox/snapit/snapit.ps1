<#
.SYNOPSIS
    snapit
#>
param([string]$Description = "Manual-$(Get-Date -Format 'yyyyMMdd-HHmmss')")
    Write-Host "Creating Rollback Rx snapshot: $Description" -ForegroundColor Yellow
    
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
        # Method 1: Try Shield.exe command line approach
        Write-Host "Attempting to create Rollback Rx snapshot..." -ForegroundColor Cyan
        $shieldExe = Join-Path $shieldPath "Shield.exe"
        
        # Try various command line formats based on research
        $commands = @(
            "/snapshot /n `"$Description`"",
            "-snapshot -n `"$Description`"", 
            "/create `"$Description`"",
            "-create `"$Description`""
        )
        
        $success = $false
        foreach ($cmd in $commands) {
            try {
                Write-Host "Trying: $shieldExe $cmd" -ForegroundColor Gray
                $result = Start-Process -FilePath $shieldExe -ArgumentList $cmd -Wait -PassThru -WindowStyle Hidden -Timeout 30
                if ($result.ExitCode -eq 0) {
                    Write-Host "Rollback Rx snapshot created successfully: $Description" -ForegroundColor Green
                    $success = $true
                    break
                }
            } catch {
                # Continue to next command
            }
        }
        
        if (-not $success) {
            Write-Host "Command-line creation failed, trying GUI automation..." -ForegroundColor Yellow
            
            # Method 2: GUI automation approach (based on Rollback Rx Home interface)
            try {
                Write-Host "Launching Rollback Rx GUI..." -ForegroundColor Cyan
                $process = Start-Process -FilePath $shieldExe -PassThru -WindowStyle Normal
                Start-Sleep 3
                
                # Navigate to Snapshots section and create snapshot
                Add-Type -AssemblyName System.Windows.Forms
                
                # Click on Snapshots in the left menu
                [System.Windows.Forms.SendKeys]::SendWait("{TAB}{TAB}{DOWN}{DOWN}")  # Navigate to Snapshots
                Start-Sleep 1
                [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")  # Enter Snapshots section
                Start-Sleep 2
                
                # Look for Create/Take Snapshot button (usually Ctrl+N or dedicated button)
                [System.Windows.Forms.SendKeys]::SendWait("^n")  # Ctrl+N for New Snapshot
                Start-Sleep 1
                
                # Enter description if dialog appears
                [System.Windows.Forms.SendKeys]::SendWait($Description)
                Start-Sleep 1
                [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")  # Confirm
                
                Write-Host "GUI automation attempted for snapshot creation" -ForegroundColor Green
                Write-Host "Description: $Description" -ForegroundColor Cyan
                Write-Host "Check Rollback Rx Snapshots section to confirm creation" -ForegroundColor Cyan
            } catch {
                Write-Host "GUI automation failed: $_" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Error creating Rollback Rx snapshot: $_" -ForegroundColor Red
    }
    
    # Always provide manual instructions
    Write-Host ""
    Write-Host "=== MANUAL ROLLBACK RX SNAPSHOT ===" -ForegroundColor Cyan
    Write-Host "If automatic creation failed:" -ForegroundColor White
    Write-Host "1. Open Rollback Rx (Start Menu > RollBack Rx Home)" -ForegroundColor Green
    Write-Host "2. Click 'Snapshots' in the left navigation menu" -ForegroundColor Green
    Write-Host "3. Look for 'Take Snapshot' or 'Create' button" -ForegroundColor Green
    Write-Host "4. Enter description: $Description" -ForegroundColor Green
    Write-Host "5. Click 'OK' or 'Create' to save the snapshot" -ForegroundColor Green
    Write-Host ""
    Write-Host "Alternative: Right-click Rollback Rx system tray icon > Take Snapshot" -ForegroundColor Cyan
