<#
.SYNOPSIS
    dfixer
#>
docker context use default ; docker system prune -af --volumes ; wsl --shutdown ; Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue ; net stop com.docker.service ; Start-Sleep -Seconds 3 ; net start com.docker.service ; Start-Sleep -Seconds 5 ; Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" ; Start-Sleep -Seconds 10 ; docker context use default ; docker ps
