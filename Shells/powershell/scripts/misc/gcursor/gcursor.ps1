<#
.SYNOPSIS
    gcursor
#>
New-Item -Path "F:\backup\windowsapps\installed\cursor" -ItemType Directory -Force; Set-Location "F:\backup\windowsapps\installed\cursor"; Invoke-WebRequest -Uri "https://downloads.cursor.com/production/e86fcc937643bc6385aebd982c1c66012c98caec/win32/x64/system-setup/CursorSetup-x64-1.1.4.exe" -OutFile "CursorSetup-x64-1.1.4.exe"; Start-Process "CursorSetup-x64-1.1.4.exe"
