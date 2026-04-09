<#
.SYNOPSIS
    docker17
#>
# Better for more demanding applications
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=10GB
processors=4
swap=8GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60' > /mnt/c/Users/micha/.wslconfig && echo 'Applied higher Docker WSL2 config: 10GB RAM, 4 CPUs, 8GB swap, optimized TCP'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
