<#
.SYNOPSIS
    docker27
#>
# Very high bandwidth and resources
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=32GB
processors=10
swap=32GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60 net.ipv4.tcp_keepalive_intvl=15 net.core.somaxconn=65535 net.core.netdev_max_backlog=16384 net.ipv4.tcp_rmem=4096 87380 33554432 net.ipv4.tcp_wmem=4096 16384 33554432' > /mnt/c/Users/micha/.wslconfig && echo 'Applied higher Docker WSL2 config: 32GB RAM, 10 CPUs, 32GB swap, optimized networking and bandwidth'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
