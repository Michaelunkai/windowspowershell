<#
.SYNOPSIS
    docker23
#>
# High performance for complex projects
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=20GB
processors=8
swap=20GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60' > /mnt/c/Users/micha/.wslconfig && echo 'Applied higher Docker WSL2 config: 20GB RAM, 8 CPUs, 20GB swap, optimized TCP'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
