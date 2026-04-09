<#
.SYNOPSIS
    saveweb
#>
Set-Location -Path "C:\users\micha\Videos\Webinars";
    drun webinars michadockermisha/backup:webinars "sh -c 'apk add rsync && rsync -av /home/* /c/Users/micha/Videos/Webinars && exit'";
    built michadockermisha/backup:webinars;
    docker push michadockermisha/backup:webinars;
    Remove-Item -Recurse .\*
