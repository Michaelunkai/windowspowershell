<#
.SYNOPSIS
    docker13
#>
# Balanced for development with multiple containers
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=6GB
processors=3
swap=4GB
networkingMode=NAT
localhostForwarding=true' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 6GB RAM, 3 CPUs, 4GB swap, NAT networking'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
