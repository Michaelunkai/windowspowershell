<#
.SYNOPSIS
    docker26
#>
# Maximum performance for complex containers
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=28GB
processors=10
swap=28GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60 net.ipv4.tcp_keepalive_intvl=15 net.core.somaxconn=65535 net.core.netdev_max_backlog=16384' > /mnt/c/Users/micha/.wslconfig && echo 'Applied higher Docker WSL2 config: 28GB RAM, 10 CPUs, 28GB swap, optimized networking'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
