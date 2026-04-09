<#
.SYNOPSIS
    updates
#>
wsl --distribution ubuntu --user root -- bash -c "apt update && apt upgrade -y"; wsl --distribution ubuntu2 --user root -- bash -c "apt update && apt upgrade -y"; update
