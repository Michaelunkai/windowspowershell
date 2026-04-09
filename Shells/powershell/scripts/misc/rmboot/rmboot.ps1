<#
.SYNOPSIS
    rmboot
#>
bcdedit /delete ((bcdedit /enum | Out-String) -split 'Windows Boot Loader' | ? {$_ -match 'Macrium'} | % {[regex]::Match($_,'{[a-f0-9-]{36}}').Value})
