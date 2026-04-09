<#
.SYNOPSIS
    docker6 - PowerShell utility script
.NOTES
    Original function: docker6
    Extracted: 2026-02-19 20:20
#>
# Better for multiple containers
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=2.5GB
processors=2
swap=2GB' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 2.5GB RAM, 2 CPUs, 2GB swap'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
