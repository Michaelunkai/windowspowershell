<#
.SYNOPSIS
    stov
#>
Write-Host "Connecting to PRODUCTION via staging jump host, then switching to root..."
    wsl -d ubuntu bash -c "sshpass -p '3897ysdkjhHH' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -tt admin@92.113.144.59 'sshpass -p EbTyNkfJG6LM ssh -o StrictHostKeyChecking=no -tt admin@193.181.213.220 sudo\ su\ -'"
