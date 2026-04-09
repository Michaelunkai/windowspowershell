<#
.SYNOPSIS
    rlas
#>
Stop-Process -Name "processlasso" -Force
    Start-Process -FilePath "F:\backup\windowsapps\installed\Process Lasso\ProcessLasso.exe"
