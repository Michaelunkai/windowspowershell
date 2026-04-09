<#
.SYNOPSIS
    cccc
#>
# Close WinOptimize if it's running
    Get-Process -Name "WinOptimize" -ErrorAction SilentlyContinue | Stop-Process -Force
    # Get all shortcuts in the maintenance directory except IObit Unlocker
    $shortcuts = Get-ChildItem -Path "C:\users\micha\Desktop\maintaince" -Filter "*.lnk" |
                Where-Object { $_.Name -notmatch "IObit Unlocker" }
    # Create shell object to read shortcuts
    $shell = New-Object -ComObject WScript.Shell
    # Close each application launched from the shortcuts
    foreach ($shortcut in $shortcuts) {
        $shortcutPath = $shell.CreateShortcut($shortcut.FullName)
        $targetExe = [System.IO.Path]::GetFileNameWithoutExtension($shortcutPath.TargetPath)
        # Try to gracefully close the application
        Get-Process -Name $targetExe -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $_.CloseMainWindow() > $null
                # If the process doesn't close after 5 seconds, force close it
                Start-Sleep -Seconds 5
                if (!$_.HasExited) {
                    $_ | Stop-Process -Force
                }
            }
            catch {
                # If graceful close fails, force close the process
                $_ | Stop-Process -Force
            }
        }
    }
    # Clean up COM object
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) > $null
    Remove-Variable shell
