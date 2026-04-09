<#
.SYNOPSIS
    saveweb - PowerShell utility script
.NOTES
    Original function: saveweb
    Extracted: 2026-02-19 20:20
#>
Set-Location -Path "C:\users\micha\Videos\Webinars";
    drun webinars michadockermisha/backup:webinars "sh -c 'apk add rsync && rsync -av /home/* /c/Users/micha/Videos/Webinars && exit'";
    built michadockermisha/backup:webinars;
    docker push michadockermisha/backup:webinars;
    Remove-Item -Recurse .\*
