<#
.SYNOPSIS
    docker25
#>
# Maximum performance for development environment
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=24GB
processors=8
swap=24GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60 net.ipv4.tcp_keepalive_intvl=15 net.core.somaxconn=65535 net.core.netdev_max_backlog=16384' > /mnt/c/Users/micha/.wslconfig && echo 'Applied higher Docker WSL2 config: 24GB RAM, 8 CPUs, 24GB swap, optimized networking'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
