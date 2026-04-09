<#
.SYNOPSIS
    RestoreLinux - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
docker run -it -v /c/backup/linux/wsl:/f/ michadockermisha/backup:wsl sh -c "apk add rsync &&  rsync -av /home/* /f "
