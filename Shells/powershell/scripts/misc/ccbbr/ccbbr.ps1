<#
.SYNOPSIS
    ccbbr
#>
$p1 = Start-Process powershell -ArgumentList "-Command clean" -NoNewWindow -PassThru; $p2 = Start-Process powershell -ArgumentList "-Command ws backitup" -NoNewWindow -PassThru; $p1.WaitForExit(); $p2.WaitForExit(); rrewsl
