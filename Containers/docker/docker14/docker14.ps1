<#
.SYNOPSIS
    docker14
#>
# Good for medium to heavy workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=6GB
processors=4
swap=6GB
networkingMode=NAT
localhostForwarding=true' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 6GB RAM, 4 CPUs, 6GB swap, NAT networking'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
