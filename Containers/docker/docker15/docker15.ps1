<#
.SYNOPSIS
    docker15
#>
# Higher resources for more intensive workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=8GB
processors=4
swap=8GB
networkingMode=NAT
localhostForwarding=true' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 8GB RAM, 4 CPUs, 8GB swap, NAT networking'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
