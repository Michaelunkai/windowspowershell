<#
.SYNOPSIS
    rmdefender
#>
Get-ChildItem "C:\Program Files\Windows Defender","C:\ProgramData\Microsoft\Windows Defender","C:\Windows\System32\drivers\wd*","C:\Windows\System32\*defender*" -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
