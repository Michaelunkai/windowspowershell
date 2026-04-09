<#
.SYNOPSIS
    docker1
#>
# Minimal resources for small containers
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=512MB
processors=1
swap=1GB' > /mnt/c/Users/micha/.wslconfig && echo 'Applied minimal Docker WSL2 config: 512MB RAM, 1 CPU, 1GB swap'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
