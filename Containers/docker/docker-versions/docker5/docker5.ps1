<#
.SYNOPSIS
    docker5 - PowerShell utility script
.NOTES
    Original function: docker5
    Extracted: 2026-02-19 20:20
#>
# Balanced for medium workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=2GB
processors=2
swap=2GB' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 2GB RAM, 2 CPUs, 2GB swap'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
