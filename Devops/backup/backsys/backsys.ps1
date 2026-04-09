<#
.SYNOPSIS
    backsys
#>
# Format the F drive
    Format-Volume -DriveLetter F -FileSystem NTFS -NewFileSystemLabel "F" -Confirm:$false
    $reflectPath = "F:\\backup\windowsapps\installed\reflect\reflect\Reflect.exe"
    $xmlFile = "F:\\backup\windowsapps\installed\reflect\Reflect\Backup.xml"
    $logFile = "F:\\backup\windowsapps\installed\reflect\Reflect\backup_log.txt"
    $logDir = Split-Path $logFile
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir > $null
    }
    Write-Output "Starting backup in the background..." -ForegroundColor Yellow
    # Start the backup in a background job so the shell remains interactive
    Start-Job -ScriptBlock {
        param($reflectPath, $xmlFile, $logFile)
        & $reflectPath -e -full $xmlFile -log > $logFile 2>&1
    } -ArgumentList $reflectPath, $xmlFile, $logFile
    Write-Output "Backup has been initiated. Use Get-Job and Receive-Job to track progress. Returning to shell now..." -ForegroundColor Green
