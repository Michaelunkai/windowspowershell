<#
.SYNOPSIS
    RestoreLinux
#>
docker run -it -v /c/backup/linux/wsl:/f/ michadockermisha/backup:wsl sh -c "apk add rsync &&  rsync -av /home/* /f "
