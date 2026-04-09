<#
.SYNOPSIS
    dcreds
#>
Set-Location -Path "F:\\backup\windowsapps\Credentials";
    built michadockermisha/backup:creds;
    docker push michadockermisha/backup:creds
