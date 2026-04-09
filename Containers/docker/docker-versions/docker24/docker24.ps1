<#
.SYNOPSIS
    docker24 - PowerShell utility script
.NOTES
    Original function: docker24
    Extracted: 2026-02-19 20:20
#>
# Very high resources for multiple complex containers
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=24GB
processors=8
swap=24GB
networkingMode=NAT
localhostForwarding=true
kernelCommandLine=net.ipv4.tcp_keepalive_time=60 net.ipv4.tcp_keepalive_intvl=15 net.core.somaxconn=65535' > /mnt/c/Users/micha/.wslconfig && echo 'Applied higher Docker WSL2 config: 24GB RAM, 8 CPUs, 24GB swap, optimized TCP'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
