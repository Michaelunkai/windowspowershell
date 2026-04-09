# onstart.ps1 - Register ANY file to run SILENTLY at Windows startup
# Universal: works with exe, ahk, ps1, bat, cmd, vbs, msi, lnk, py, js, etc.
# ALL launches are HIDDEN - no terminal popups, only tray icons if the app has one
# Usage: onstart "C:\path\to\anything.ext" "D:\path\to\script.ahk"
# Stop mode: onstart "STOP:C:\path\to\app.exe"

<#
.SYNOPSIS
    Registers ANY file type to run SILENTLY at Windows logon.
.DESCRIPTION
    Creates Task Scheduler tasks that trigger immediately at logon.
    All launches are HIDDEN - no terminal windows, no popups.
    Apps with tray icons will show in tray only.
.PARAMETER FilePaths
    One or more full file paths to any file type.
.EXAMPLE
    onstart "C:\scripts\auto.ahk" "D:\apps\tool.exe"
.EXAMPLE
    onstart "STOP:C:\unwanted\app.exe"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$FilePaths
)

$ahkPath = "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$wrappersDir = "$env:USERPROFILE\.openclaw\startup-wrappers"

# Create wrappers directory if needed
if (-not (Test-Path $wrappersDir)) {
    New-Item -ItemType Directory -Path $wrappersDir -Force | Out-Null
}

foreach ($path in $FilePaths) {
    # Check if this is a STOP directive
    $isStopTask = $path -match "^STOP:"
    $cleanPath = $path -replace "^STOP:", ""

    if (-not (Test-Path $cleanPath)) {
        Write-Warning "Path not found: $cleanPath - Skipping."
        continue
    }

    $ext = [System.IO.Path]::GetExtension($cleanPath).ToLower()
    $appName = [System.IO.Path]::GetFileNameWithoutExtension($cleanPath)
    $appDir = [System.IO.Path]::GetDirectoryName($cleanPath)

    if ($isStopTask) {
        # ===== STOP TASK: Kill process at startup =====
        $taskName = "FastStop_$appName"
        $stopScript = "Stop-Process -Name '$appName' -Force -ErrorAction SilentlyContinue"
        
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$stopScript`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
        $trigger.Delay = "PT5S"
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Seconds 30) -Priority 0 -StartWhenAvailable
        $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest

        try {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
            Write-Host "'$appName' configured to STOP at startup (Task: $taskName)" -ForegroundColor Yellow
        }
        catch {
            Write-Error "Failed to create stop task for '$appName': $_"
        }
    } 
    else {
        # ===== STARTUP TASK: Run file SILENTLY at logon =====
        $taskName = "FastStartup_$appName"
        $usePersistentWrapper = $false
        $execPath = ""
        $arguments = ""

        switch ($ext) {
            # ===== VBS: wscript runs hidden by default =====
            ".vbs" {
                $execPath = "wscript.exe"
                $arguments = "//B `"$cleanPath`""  # //B = batch mode, no popups
            }
            # ===== BAT/CMD: Run through PowerShell hidden =====
            ".bat" {
                $execPath = "powershell.exe"
                $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"& cmd.exe /c '`"$cleanPath`"'`""
            }
            ".cmd" {
                $execPath = "powershell.exe"
                $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"& cmd.exe /c '`"$cleanPath`"'`""
            }
            # ===== PS1: PowerShell hidden =====
            ".ps1" {
                $execPath = "powershell.exe"
                $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$cleanPath`""
            }
            # ===== AHK: AutoHotkey runs hidden by default =====
            ".ahk" {
                if (-not (Test-Path $ahkPath)) {
                    Write-Warning "AutoHotkey not found at '$ahkPath' - trying default handler"
                    $execPath = "powershell.exe"
                    $arguments = "-NoProfile -WindowStyle Hidden -Command `"Start-Process -FilePath '$cleanPath' -WindowStyle Hidden`""
                } else {
                    $execPath = $ahkPath
                    $arguments = "`"$cleanPath`""
                }
            }
            # ===== Python: Run through PowerShell hidden =====
            ".py" {
                $execPath = "powershell.exe"
                $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"& python '$cleanPath'`""
            }
            # ===== Node.js: Run through PowerShell hidden =====
            ".js" {
                $execPath = "powershell.exe"
                $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"& node '$cleanPath'`""
            }
            # ===== EXE: Use persistent wrapper =====
            ".exe" {
                $usePersistentWrapper = $true
            }
            # ===== Shortcuts: Start hidden =====
            ".lnk" {
                $execPath = "powershell.exe"
                $arguments = "-NoProfile -WindowStyle Hidden -Command `"Start-Process -FilePath '$cleanPath' -WindowStyle Hidden`""
            }
            ".url" {
                $execPath = "powershell.exe"
                $arguments = "-NoProfile -WindowStyle Hidden -Command `"Start-Process -FilePath '$cleanPath'`""
            }
            # ===== DEFAULT: Open with default handler, hidden =====
            default {
                $execPath = "powershell.exe"
                $arguments = "-NoProfile -WindowStyle Hidden -Command `"Start-Process -FilePath '$cleanPath' -WindowStyle Hidden`""
            }
        }

        if ($usePersistentWrapper) {
            # ===== PERSISTENT WRAPPER for EXE files =====
            $wrapperPath = "$wrappersDir\$appName`_persistent.ps1"
            
            $wrapperContent = @"
# Auto-generated persistent wrapper for: $appName
# Source: $cleanPath
# Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# SILENT: No terminal windows, tray icon only

`$ErrorActionPreference = 'SilentlyContinue'

while (`$true) {
    # Check if process is running by name
    `$running = Get-Process -Name '$appName' -ErrorAction SilentlyContinue
    
    if (-not `$running) {
        # Launch the application HIDDEN
        Start-Process -FilePath "$cleanPath" -WorkingDirectory "$appDir" -WindowStyle Hidden
    }
    
    # Check every 30 seconds
    Start-Sleep -Seconds 30
}
"@
            Set-Content -Path $wrapperPath -Value $wrapperContent -Force
            
            $execPath = "powershell.exe"
            $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$wrapperPath`""
            
            Write-Host "'$appName' ($ext) configured for PERSISTENT startup (Task: $taskName)" -ForegroundColor Green
            Write-Host "  Wrapper: $wrapperPath" -ForegroundColor DarkGray
        }
        else {
            Write-Host "'$appName' ($ext) configured for startup (Task: $taskName)" -ForegroundColor Green
        }

        # Create the scheduled task
        $action = New-ScheduledTaskAction -Execute $execPath -Argument $arguments -WorkingDirectory $appDir
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
        $trigger.Delay = "PT0S"  # Immediate - no delay
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -Priority 0 -StartWhenAvailable -DontStopOnIdleEnd
        $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest

        try {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
        }
        catch {
            Write-Error "Failed to create startup task for '$appName': $_"
        }
    }
}
