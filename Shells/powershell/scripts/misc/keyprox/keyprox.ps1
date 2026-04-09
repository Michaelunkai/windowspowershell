<#
.SYNOPSIS
    keyprox
#>
ssh-keygen -t rsa -b 2048; cat ~/.ssh/id_rsa.pub | ssh root@192.168.1.222 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
