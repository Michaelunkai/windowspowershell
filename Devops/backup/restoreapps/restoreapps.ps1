<#
.SYNOPSIS
    restoreapps - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
drun windowsapps michadockermisha/backup:windowsapps "sh -c 'apk add rsync && rsync -aP /home /f/backup/ && cd /f/backup/ && mv home windowsapps && exit'"
