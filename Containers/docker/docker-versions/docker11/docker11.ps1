<#
.SYNOPSIS
    docker11 - PowerShell utility script
.NOTES
    Original function: docker11
    Extracted: 2026-02-19 20:20
#>
# Better for heavier development
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=4.5GB
processors=3
swap=4GB
networkingMode=NAT
localhostForwarding=true' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 4.5GB RAM, 3 CPUs, 4GB swap, NAT networking'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
