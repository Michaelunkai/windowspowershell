<#
.SYNOPSIS
    getps7
#>
if (!(Test-Path "C:\Program Files\PowerShell\7\pwsh.exe")) { iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet" }
