<#
.SYNOPSIS
    getkuma
#>
docker run -d --restart always -p 3001:3001 -v /var/kuma:/app/data louislam/uptime-kuma:1;
    Start-Process chrome "http://localhost:3001"
