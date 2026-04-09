<#
.SYNOPSIS
    rmwinold
#>
takeown /f "C:\Windows.old" /r /d y; icacls "C:\Windows.old" /grant administrators:F /t; Remove-Item -Path "C:\Windows.old" -Recurse -Force; rd /s /q "C:\Windows.old";  cleanmgr /sageset:65535; DISM /online /Cleanup-Image /StartComponentCleanup /ResetBase
