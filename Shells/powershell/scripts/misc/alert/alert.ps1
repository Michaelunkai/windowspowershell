<#
.SYNOPSIS
    alert
#>
3..1 | ForEach-Object { [console]::beep( 800,500); Start-Sleep -Milliseconds 200 }
