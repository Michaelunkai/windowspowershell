<#
.SYNOPSIS
    docker30 - PowerShell utility script
.NOTES
    Original function: docker30
    Extracted: 2026-02-19 20:20
#>
# Maximum system resources
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=64GB
processors=16
swap=64GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60 net.ipv4.tcp_keepalive_intvl=15 net.core.somaxconn=65535 net.core.netdev_max_backlog=16384 net.ipv4.tcp_rmem=4096 87380 33554432 net.ipv4.tcp_wmem=4096 16384 33554432' > /mnt/c/Users/micha/.wslconfig && echo 'Applied maximum Docker WSL2 config: 64GB RAM, 16 CPUs, 64GB swap, optimized networking and bandwidth'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
