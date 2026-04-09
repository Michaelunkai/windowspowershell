<#
.SYNOPSIS
    docker7
#>
# Good for medium development environments
    wsl -d ubuntu --user root -- bash -c "echo '[wsl2]
memory=3GB
processors=2
swap=2GB' > /mnt/c/Users/micha/.wslconfig && echo 'Applied Docker WSL2 config: 3GB RAM, 2 CPUs, 2GB swap'"
    wsl --shutdown
    wsl -d ubuntu --user root -- bash -c "docker info"
