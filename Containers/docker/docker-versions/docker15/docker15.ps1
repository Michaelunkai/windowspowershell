<#
.SYNOPSIS
    docker15 - PowerShell utility script
.NOTES
    Original function: docker15
    Extracted: 2026-02-19 20:20
#>
# Higher resources for more intensive workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=8GB
processors=4
swap=8GB
networkingMode=NAT
localhostForwarding=true' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 8GB RAM, 4 CPUs, 8GB swap, NAT networking'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
