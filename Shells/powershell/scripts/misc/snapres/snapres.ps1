<#
.SYNOPSIS
    snapres - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Write-Host "Checking Rollback Rx snapshots..." -ForegroundColor Cyan
    
    # Check if Rollback Rx is installed
    $shieldPath = "C:\Program Files\Shield"
    if (-not (Test-Path $shieldPath)) {
        Write-Host "ERROR: Rollback Rx not found at $shieldPath" -ForegroundColor Red
        Write-Host "Please verify Rollback Rx installation" -ForegroundColor Yellow
        return
    }
    
    # Check Rollback Rx service status
    Write-Host "Checking Rollback Rx service..." -ForegroundColor Cyan
    $shdService = Get-Service -Name "*Shield*" -ErrorAction SilentlyContinue
    if ($shdService) {
        Write-Host "Service Status: $($shdService.Status)" -ForegroundColor $(if ($shdService.Status -eq "Running") { "Green" } else { "Yellow" })
        Write-Host "Service Name: $($shdService.Name)" -ForegroundColor White
    } else {
        Write-Host "Rollback Rx service not found" -ForegroundColor Red
    }
    
    try {
        # Method 1: Try command-line listing
        Write-Host ""
        Write-Host "Attempting to list Rollback Rx snapshots..." -ForegroundColor Cyan
        $shieldExe = Join-Path $shieldPath "Shield.exe"
        
        # Try various command line formats for listing
        $commands = @(
            "/list",
            "-list",
            "/snapshotlist",
            "-snapshotlist",
            "/show",
            "-show"
        )
        
        $success = $false
        foreach ($cmd in $commands) {
            try {
                Write-Host "Trying: $shieldExe $cmd" -ForegroundColor Gray
                $result = Start-Process -FilePath $shieldExe -ArgumentList $cmd -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\rollback_list.txt" -Timeout 15
                
                if ($result.ExitCode -eq 0) {
                    $output = Get-Content "$env:TEMP\rollback_list.txt" -ErrorAction SilentlyContinue
                    if ($output) {
                        Write-Host "Rollback Rx snapshots found:" -ForegroundColor Green
                        $output | ForEach-Object {
                            if ($_ -match "(snapshot|backup|restore|point)") {
                                Write-Host "  $_" -ForegroundColor Yellow
                            }
                        }
                        $success = $true
                        break
                    }
                }
            } catch {
                # Continue to next command
            }
        }
        
        # Clean up temp file
        Remove-Item "$env:TEMP\rollback_list.txt" -ErrorAction SilentlyContinue
        
        if (-not $success) {
            Write-Host "Command-line listing failed or no snapshots found" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "Error listing Rollback Rx snapshots: $_" -ForegroundColor Red
    }
    
    # Method 2: Check Rollback Rx configuration files
    Write-Host ""
    Write-Host "Checking Rollback Rx configuration..." -ForegroundColor Cyan
    try {
        $configFiles = @(
            "$shieldPath\Settings.ini",
            "$shieldPath\shield.dat", 
            "$env:PROGRAMDATA\Shield\*",
            "$env:LOCALAPPDATA\Shield\*"
        )
        
        $foundConfigs = 0
        foreach ($configPath in $configFiles) {
            if (Test-Path $configPath) {
                $foundConfigs++
            }
        }
        
        if ($foundConfigs -gt 0) {
            Write-Host "Found $foundConfigs Rollback Rx configuration file(s)" -ForegroundColor Green
            Write-Host "Rollback Rx appears to be properly configured" -ForegroundColor Green
        } else {
            Write-Host "No Rollback Rx configuration files found" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "Unable to check configuration files" -ForegroundColor Yellow
    }
    
    # Method 3: Check disk space and provide manual instructions
    Write-Host ""
    Write-Host "=== MANUAL ROLLBACK RX SNAPSHOT CHECK ===" -ForegroundColor Cyan
    Write-Host "To manually view snapshots:" -ForegroundColor White
    Write-Host "1. Open Rollback Rx (Start Menu > RollBack Rx Home)" -ForegroundColor Green
    Write-Host "2. Click 'Snapshots' in the left navigation menu" -ForegroundColor Green
    Write-Host "3. Browse available restore points and their details" -ForegroundColor Green
    Write-Host "4. Check creation dates, descriptions, and sizes" -ForegroundColor Green
    Write-Host ""
    Write-Host "Alternative: Right-click Rollback Rx tray icon > View Snapshots" -ForegroundColor Cyan
    
    try {
        $drive = "C:"
        $vol = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE DriveLetter='$drive'" -Timeout 5 -ErrorAction SilentlyContinue
        if ($vol) {
            $total = [math]::Round($vol.Capacity/1GB, 2)
            $free = [math]::Round($vol.FreeSpace/1GB, 2)
            $used = $total - $free
            Write-Host ""
            Write-Host "Disk Usage on $drive" -ForegroundColor Cyan
            Write-Host "  Total: ${total} GB" -ForegroundColor White
            Write-Host "  Free: ${free} GB" -ForegroundColor Green
            Write-Host "  Used: ${used} GB" -ForegroundColor Yellow
        }
    } catch {
        Write-Host ""
        Write-Host "Note: Unable to check disk usage" -ForegroundColor Gray
    }
