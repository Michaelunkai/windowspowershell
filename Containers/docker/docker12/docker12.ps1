<#
.SYNOPSIS
    docker12
#>
# Good balance for most workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=5GB
processors=3
swap=4GB
networkingMode=NAT
localhostForwarding=true' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 5GB RAM, 3 CPUs, 4GB swap, NAT networking'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
