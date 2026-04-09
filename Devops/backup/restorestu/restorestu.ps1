<#
.SYNOPSIS
    restorestu - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
docker run -it -v /f/study:/f/ michadockermisha/backup:study sh -c "apk add rsync &&  rsync -av /home/* /f "
