<#
.SYNOPSIS
    restorestu
#>
docker run -it -v /f/study:/f/ michadockermisha/backup:study sh -c "apk add rsync &&  rsync -av /home/* /f "
