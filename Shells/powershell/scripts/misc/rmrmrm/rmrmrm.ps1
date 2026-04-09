<#
.SYNOPSIS
    rmrmrm
#>
takeown /f "F:\System Volume Information" /r /d Y ; icacls "F:\System Volume Information" /grant administrators:F /t ; Remove-Item "F:\System Volume Information" -Recurse -Force; Set-CimInstance -Query "SELECT * FROM Win32_ComputerSystem" -Property @{AutomaticManagedPagefile=$false}; Get-CimInstance -Query "SELECT * FROM Win32_PageFileSetting" | Remove-CimInstance
