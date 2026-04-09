<#
.SYNOPSIS
    gsystemd
#>
wsl --shutdown; wsl --update; wsl -d ubuntu -- bash -c "echo -e '[boot]\nsystemd=true' | sudo tee /etc/wsl.conf"; wsl --shutdown
