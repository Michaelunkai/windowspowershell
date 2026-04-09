<#
.SYNOPSIS
    add_keys - PowerShell utility script
.NOTES
    Original function: add_keys
    Extracted: 2026-02-19 20:20
#>
# Generate SSH key
    ssh-keygen -t rsa -b 2048
    # Add key to the first server
    cat ~/.ssh/id_rsa.pub | ssh ubuntu@192.168.1.193 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
    # Add key to the second server
    cat ~/.ssh/id_rsa.pub | ssh root@192.168.1.222 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
    # Add key to the third server
    cat ~/.ssh/id_rsa.pub | ssh root@192.168.1.101 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
