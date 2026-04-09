<#
.SYNOPSIS
    restoreapps
#>
drun windowsapps michadockermisha/backup:windowsapps "sh -c 'apk add rsync && rsync -aP /home /f/backup/ && cd /f/backup/ && mv home windowsapps && exit'"
