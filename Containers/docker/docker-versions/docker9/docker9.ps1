<#
.SYNOPSIS
    docker9 - PowerShell utility script
.NOTES
    Original function: docker9
    Extracted: 2026-02-19 20:20
#>
# Good for multiple development containers
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=4GB
processors=2
swap=4GB' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 4GB RAM, 2 CPUs, 4GB swap'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
