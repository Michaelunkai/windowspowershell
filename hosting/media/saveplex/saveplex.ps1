<#
.SYNOPSIS
    saveplex - PowerShell utility script
.NOTES
    Original function: saveplex
    Extracted: 2026-02-19 20:20
#>
Set-Location -Path "F:\\backup\plex";
    drun plex michadockermisha/backup:plex "sh -c 'apk add rsync && rsync -aP /home/* /c/backup/plex && exit'";
    built michadockermisha/backup:plex;
    docker push michadockermisha/backup:plex;
    Remove-Item -Recurse .\*
