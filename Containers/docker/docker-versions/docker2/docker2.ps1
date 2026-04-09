<#
.SYNOPSIS
    docker2 - PowerShell utility script
.NOTES
    Original function: docker2
    Extracted: 2026-02-19 20:20
#>
# Slightly more resources
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=768MB
processors=1
swap=1GB' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 768MB RAM, 1 CPU, 1GB swap'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
