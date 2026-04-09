<#
.SYNOPSIS
    restorewsl2
#>
docker run -it -v /f/backup/linux/wsl:/f/ michadockermisha/backup:wsl sh -c "apk add rsync &&  rsync -av /home/ubuntu.tar /f && exit"
