<#
.SYNOPSIS
    docker20
#>
# Better for multiple complex containers
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=14GB
processors=6
swap=12GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60' > /mnt/c/Users/micha/.wslconfig && echo 'Applied higher Docker WSL2 config: 14GB RAM, 6 CPUs, 12GB swap, optimized TCP'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
