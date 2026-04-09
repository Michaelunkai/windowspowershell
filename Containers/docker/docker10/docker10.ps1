<#
.SYNOPSIS
    docker10
#>
# Best for medium workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=4GB
processors=2
swap=4GB
networkingMode=NAT
localhostForwarding=true' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 4GB RAM, 2 CPUs, 4GB swap, NAT networking'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
