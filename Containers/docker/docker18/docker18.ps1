<#
.SYNOPSIS
    docker18
#>
# Good for multiple containers and builds
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=12GB
processors=4
swap=10GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60' > /mnt/c/Users/micha/.wslconfig && echo 'Applied higher Docker WSL2 config: 12GB RAM, 4 CPUs, 10GB swap, optimized TCP'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
