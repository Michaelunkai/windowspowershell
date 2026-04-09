<#
.SYNOPSIS
    rlas - PowerShell utility script
.NOTES
    Original function: rlas
    Extracted: 2026-02-19 20:20
#>
Stop-Process -Name "processlasso" -Force
    Start-Process -FilePath "F:\backup\windowsapps\installed\Process Lasso\ProcessLasso.exe"
