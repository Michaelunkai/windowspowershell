<#
.SYNOPSIS
    macres
#>
$latest = (Get-ChildItem "F:\win11recovery\*.mrimg" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName; echo "YES" | F:\backup\windowsapps\installed\reflect\mrauto.exe -r "$latest"
