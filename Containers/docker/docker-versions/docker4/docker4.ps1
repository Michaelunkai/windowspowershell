<#
.SYNOPSIS
    docker4 - PowerShell utility script
.NOTES
    Original function: docker4
    Extracted: 2026-02-19 20:20
#>
# Good for development containers
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=1.5GB
processors=1
swap=2GB' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 1.5GB RAM, 1 CPU, 2GB swap'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
