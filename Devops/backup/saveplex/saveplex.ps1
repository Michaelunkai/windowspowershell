<#
.SYNOPSIS
    saveplex
#>
Set-Location -Path "F:\\backup\plex";
    drun plex michadockermisha/backup:plex "sh -c 'apk add rsync && rsync -aP /home/* /c/backup/plex && exit'";
    built michadockermisha/backup:plex;
    docker push michadockermisha/backup:plex;
    Remove-Item -Recurse .\*
