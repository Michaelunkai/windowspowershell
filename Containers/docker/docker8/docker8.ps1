<#
.SYNOPSIS
    docker8
#>
# Balanced for heavier workloads
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=3.5GB
processors=2
swap=3GB' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 3.5GB RAM, 2 CPUs, 3GB swap'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
