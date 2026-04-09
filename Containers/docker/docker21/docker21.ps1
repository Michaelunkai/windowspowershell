<#
.SYNOPSIS
    docker21
#>
# High resources for intensive workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=16GB
processors=6
swap=16GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60' > /mnt/c/Users/micha/.wslconfig && echo 'Applied higher Docker WSL2 config: 16GB RAM, 6 CPUs, 16GB swap, optimized TCP'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
