<#
.SYNOPSIS
    docker22 - PowerShell utility script
.NOTES
    Original function: docker22
    Extracted: 2026-02-19 20:20
#>
# Very high resources for demanding workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=16GB
processors=8
swap=16GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60' > /mnt/c/Users/micha/.wslconfig && echo 'Applied higher Docker WSL2 config: 16GB RAM, 8 CPUs, 16GB swap, optimized TCP'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
