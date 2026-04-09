<#
.SYNOPSIS
    docker3
#>
# Balanced for small workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=1GB
processors=1
swap=1GB' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 1GB RAM, 1 CPU, 1GB swap'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
