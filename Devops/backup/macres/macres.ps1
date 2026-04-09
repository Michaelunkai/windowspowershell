<#
.SYNOPSIS
    macres - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
$latest = (Get-ChildItem "F:\win11recovery\*.mrimg" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName; echo "YES" | F:\backup\windowsapps\installed\reflect\mrauto.exe -r "$latest"
