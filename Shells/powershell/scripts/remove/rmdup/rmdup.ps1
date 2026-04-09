<#
.SYNOPSIS
    rmdup - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
$c=gc $PROFILE -Raw;$f=[regex]::Matches($c,'(?ms)^function\s+(\w+).*?(?=^function|\z)');$d=$f|group {$_.Groups[1].Value}|?{$_.Count-gt1}|%{$_.Group[0..($_.Count-2)]};$d|sort Index -Desc|%{$c=$c.Remove($_.Index,$_.Length)};$c|sc $PROFILE
