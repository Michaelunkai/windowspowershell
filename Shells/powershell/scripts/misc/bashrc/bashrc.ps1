<#
.SYNOPSIS
    bashrc
#>
Copy-Item -Path "\\wsl$\Ubuntu\root\.bashrc" -Destination "\\wsl$\kali-linux\root\.bashrc" -Force; Copy-Item -Path "\\wsl$\Ubuntu\root\.bashrc" -Destination "\\wsl$\kali-linux\home\$env:UserName\.bashrc" -Force; Write-Output "Copied .bashrc to both /root/.bashrc and ~/.bashrc in Kali Linux WSL2"
