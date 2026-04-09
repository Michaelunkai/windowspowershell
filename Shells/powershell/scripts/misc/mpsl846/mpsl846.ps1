<#
.SYNOPSIS
    mpsl846
#>
"[wsl2]`r`nmemory=8GB`r`nprocessors=4`r`nswap=6GB`r`nlocalhostForwarding=true" | Out-File -FilePath "$env:USERPROFILE\.wslconfig" -Encoding UTF8; wsl --shutdown
