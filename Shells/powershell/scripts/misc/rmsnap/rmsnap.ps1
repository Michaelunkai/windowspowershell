<#
.SYNOPSIS
    rmsnap
#>
Remove-Item -Path "C:\Users\micha\AppData\Local\Microsoft\Edge\User Data\ProvenanceData\*\*.quant.ort" -Force -ErrorAction SilentlyContinue; Remove-Item -Path "C:\ProgramData\Microsoft\Windows\Containers\Snapshots\*\*.vmrs" -Force -ErrorAction SilentlyContinue
