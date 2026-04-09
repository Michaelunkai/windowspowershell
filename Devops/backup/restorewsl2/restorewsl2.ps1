<#
.SYNOPSIS
    restorewsl2 - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
docker run -it -v /f/backup/linux/wsl:/f/ michadockermisha/backup:wsl sh -c "apk add rsync &&  rsync -av /home/ubuntu.tar /f && exit"
