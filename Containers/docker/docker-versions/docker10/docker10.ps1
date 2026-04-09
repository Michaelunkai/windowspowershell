<#
.SYNOPSIS
    docker10 - PowerShell utility script
.NOTES
    Original function: docker10
    Extracted: 2026-02-19 20:20
#>
# Best for medium workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=4GB
processors=2
swap=4GB
networkingMode=NAT
localhostForwarding=true' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 4GB RAM, 2 CPUs, 4GB swap, NAT networking'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
