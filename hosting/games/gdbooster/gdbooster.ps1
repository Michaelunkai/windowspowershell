<#
.SYNOPSIS
    gdbooster
#>
$fullSourceFolder="F:\backup\windowsapps\install\Cracked\IObit Driver Booster Pro 12.3.0.557 Multilingual"
    Remove-ForceFully $fullSourceFolder
    Get-Process | Where-Object { $_.Name -like "*DriverBooster*" -or $_.Path -like "*IObit*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Service | Where-Object { $_.Name -like "*DriverBooster*" -or $_.DisplayName -like "*IObit*" } | Stop-Service -Force -ErrorAction SilentlyContinue
    $targetRoot="F:\backup\windowsapps\installed\DriverBooster"
    $extractPath="F:\backup\windowsapps\install\Cracked\IObit_Extracted"
    # Add Defender exclusions before extracting crack files
    Add-MpPreference -ExclusionPath $targetRoot -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath $extractPath -ErrorAction SilentlyContinue
    Remove-ForceFully $targetRoot
    Remove-ForceFully $extractPath
    & "C:\Program Files\7-Zip\7z.exe" x "F:\backup\windowsapps\install\Cracked\IObit Driver Booster Pro 12.3.0.557 Multilingual [FileCR].zip" -p123 -o"$extractPath" -y
    $installDir="$extractPath\IObit Driver Booster Pro 12.3.0.557 Multilingual"
    while(!(Test-Path "$installDir\driver_booster_setup.exe")){ Start-Sleep 1 }
    Start-Process "$installDir\driver_booster_setup.exe" -ArgumentList "/VERYSILENT","/NORESTART","/NoAutoRun","/DIR=$targetRoot" -Wait
    & "C:\Program Files\7-Zip\7z.exe" x "$installDir\Activator_By_ActVer.zip" -p123 -o"$installDir" -y
    $finalDllDest="$targetRoot\12.3.0"
    New-Item -ItemType Directory -Path $finalDllDest -Force > $null
    Move-Item "$installDir\version.dll" -Destination $finalDllDest -Force
    Remove-ForceFully $extractPath
    Remove-ForceFully $fullSourceFolder
    $taskbarDir="$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    Get-ChildItem -Path $taskbarDir -Filter "*Driver*Booster*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force
    Start-Process "$finalDllDest\DriverBooster.exe"
    Start-Sleep -Seconds 4
    & "F:\study\Platforms\windows\AutoHotkey\DriverBoosterscan.ahk"
