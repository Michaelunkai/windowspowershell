<#
.SYNOPSIS
    smisha
#>
$excludeFile="$env:TEMP\exclude.txt";"*.log`n*.tmp`n*.bak" | Out-File -FilePath $excludeFile -Encoding ASCII;Measure-Command { xcopy C:\Users\micha F:\backup\micha /E /D /C /R /H /I /O /X /EXCLUDE:$excludeFile 2>$null };Remove-Item $excludeFile
